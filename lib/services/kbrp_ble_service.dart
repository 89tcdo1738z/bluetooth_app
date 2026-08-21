import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:universal_ble/universal_ble.dart';

import '../protocol/kbrp.dart';

enum ConnectionPhase {
  disconnected,
  scanning,
  connecting,
  securing,
  discovering,
  checkingProtocol,
  subscribing,
  synchronizing,
  ready,
  reconnecting,
  error;

  String get label => switch (this) {
    disconnected => '未连接',
    scanning => '正在扫描',
    connecting => '正在连接',
    securing => '正在安全配对',
    discovering => '正在发现服务',
    checkingProtocol => '正在检查协议',
    subscribing => '正在订阅数据',
    synchronizing => '正在同步',
    ready => '数据已同步',
    reconnecting => '正在重连',
    error => '连接失败',
  };
}

final class CompatibleDevice {
  const CompatibleDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.paired,
  });

  final String id;
  final String name;
  final int? rssi;
  final bool paired;
}

final class DeviceIdentity {
  const DeviceIdentity({this.manufacturer, this.model, this.firmware});
  final String? manufacturer;
  final String? model;
  final String? firmware;
}

final class KbrpBleService extends ChangeNotifier {
  KbrpBleService() {
    UniversalBle.queueType = QueueType.perDevice;
    _scanSubscription = UniversalBle.scanStream.listen(_onScanResult);
    _availabilitySubscription = UniversalBle.availabilityStream.listen((_) {
      notifyListeners();
    });
  }

  final _assembler = KbrpAssembler();
  final _messages = StreamController<KbrpMessage>.broadcast();
  final Map<String, CompatibleDevice> _devices = {};
  final List<StreamSubscription<Uint8List>> _valueSubscriptions = [];
  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<AvailabilityState>? _availabilitySubscription;
  StreamSubscription<bool>? _connectionSubscription;
  Completer<DeviceStatus>? _statusSnapshot;
  Completer<AlarmStatus>? _alarmSnapshot;
  Timer? _reconnectTimer;
  BleDevice? _selectedBleDevice;
  bool _manualDisconnect = false;
  int _reconnectAttempt = 0;

  ConnectionPhase phase = ConnectionPhase.disconnected;
  String? errorMessage;
  CompatibleDevice? selectedDevice;
  DeviceIdentity identity = const DeviceIdentity();
  int? negotiatedMtu;

  Stream<KbrpMessage> get messages => _messages.stream;
  List<CompatibleDevice> get devices {
    final result = _devices.values.toList();
    result.sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    return result;
  }

  bool get isBusy => switch (phase) {
    ConnectionPhase.connecting ||
    ConnectionPhase.securing ||
    ConnectionPhase.discovering ||
    ConnectionPhase.checkingProtocol ||
    ConnectionPhase.subscribing ||
    ConnectionPhase.synchronizing ||
    ConnectionPhase.reconnecting => true,
    _ => false,
  };

  Future<void> startScan() async {
    errorMessage = null;
    try {
      await UniversalBle.requestPermissions();
      final availability = await UniversalBle.getBluetoothAvailabilityState();
      if (availability != AvailabilityState.poweredOn) {
        throw StateError('请先打开蓝牙');
      }
      _devices.clear();
      phase = ConnectionPhase.scanning;
      notifyListeners();
      await UniversalBle.startScan(
        scanFilter: ScanFilter(withServices: const [KbrpUuid.service]),
        platformConfig: PlatformConfig(
          android: AndroidOptions(
            legacy: true,
            scanMode: AndroidScanMode.lowLatency,
            callbackType: const [AndroidScanCallbackType.allMatches],
            requestLocationPermission: false,
          ),
        ),
      );
    } catch (error) {
      _setError(_friendlyError(error));
    }
  }

  Future<void> stopScan() async {
    try {
      if (await UniversalBle.isScanning()) await UniversalBle.stopScan();
    } catch (_) {
      // A powered-off adapter can reject stopScan; local state still must reset.
    }
    if (phase == ConnectionPhase.scanning) {
      phase = ConnectionPhase.disconnected;
      notifyListeners();
    }
  }

  void _onScanResult(BleDevice device) {
    final advertisesService = device.services.any(
      (uuid) => BleUuidParser.compareStrings(uuid, KbrpUuid.service),
    );
    if (!advertisesService) return;
    final name = device.name?.isNotEmpty == true ? device.name! : '蓝牙设备';
    _devices[device.deviceId] = CompatibleDevice(
      id: device.deviceId,
      name: name,
      rssi: device.rssi,
      paired: device.paired ?? false,
    );
    notifyListeners();
  }

  Future<void> connect(CompatibleDevice device) async {
    final bleDevice = BleDevice(deviceId: device.id, name: device.name);
    _selectedBleDevice = bleDevice;
    selectedDevice = device;
    _manualDisconnect = false;
    _reconnectTimer?.cancel();
    await _connect(bleDevice, reconnecting: false);
  }

  Future<void> _connect(BleDevice device, {required bool reconnecting}) async {
    errorMessage = null;
    _assembler.reset();
    await _clearValueSubscriptions();
    try {
      await stopScan();
      phase = reconnecting
          ? ConnectionPhase.reconnecting
          : ConnectionPhase.connecting;
      notifyListeners();

      await _connectionSubscription?.cancel();
      _connectionSubscription = UniversalBle.connectionStream(device.deviceId)
          .listen(_onConnectionChanged);
      await UniversalBle.connect(
        device.deviceId,
        timeout: const Duration(seconds: 30),
      );

      phase = ConnectionPhase.discovering;
      notifyListeners();
      final services = await UniversalBle.discoverServices(
        device.deviceId,
        withDescriptors: true,
      );
      _validateGatt(services);

      phase = ConnectionPhase.securing;
      notifyListeners();
      await UniversalBle.pair(
        device.deviceId,
        pairingCommand: BleCommand(
          service: KbrpUuid.service,
          characteristic: KbrpUuid.protocolInfo,
        ),
        timeout: const Duration(seconds: 60),
      );

      try {
        negotiatedMtu = await UniversalBle.requestMtu(device.deviceId, 247);
      } catch (_) {
        negotiatedMtu = null;
      }

      phase = ConnectionPhase.checkingProtocol;
      notifyListeners();
      final protocolBytes = await UniversalBle.read(
        device.deviceId,
        KbrpUuid.service,
        KbrpUuid.protocolInfo,
      );
      final protocol = _decode(protocolBytes);
      if (protocol is! ProtocolInfo) {
        throw const KbrpProtocolException('未收到 Protocol Info');
      }
      if (protocol.minClientMinor > 0) {
        throw KbrpProtocolException(
          '应用协议次版本过低，设备要求 ${protocol.minClientMinor}',
        );
      }
      _messages.add(protocol);
      identity = await _readIdentity(device.deviceId);

      phase = ConnectionPhase.subscribing;
      notifyListeners();
      _statusSnapshot = Completer<DeviceStatus>();
      _alarmSnapshot = Completer<AlarmStatus>();
      _listenTo(device.deviceId, KbrpUuid.deviceStatus);
      _listenTo(device.deviceId, KbrpUuid.alarmStatus);
      _listenTo(device.deviceId, KbrpUuid.realtimeStream);
      _listenTo(device.deviceId, KbrpUuid.latestReport);
      await UniversalBle.subscribeNotifications(
        device.deviceId,
        KbrpUuid.service,
        KbrpUuid.deviceStatus,
      );
      await UniversalBle.subscribeIndications(
        device.deviceId,
        KbrpUuid.service,
        KbrpUuid.alarmStatus,
      );

      phase = ConnectionPhase.synchronizing;
      notifyListeners();
      DeviceStatus status;
      AlarmStatus alarm;
      try {
        final snapshots = await Future.wait<KbrpMessage>([
          _statusSnapshot!.future,
          _alarmSnapshot!.future,
        ]).timeout(const Duration(seconds: 3));
        status = snapshots[0] as DeviceStatus;
        alarm = snapshots[1] as AlarmStatus;
      } on TimeoutException {
        // Drop a partial Notify/Indicate before falling back to Long Read.
        _assembler.reset();
        final statusMessage = _decode(
          await UniversalBle.read(
            device.deviceId,
            KbrpUuid.service,
            KbrpUuid.deviceStatus,
          ),
        );
        final alarmMessage = _decode(
          await UniversalBle.read(
            device.deviceId,
            KbrpUuid.service,
            KbrpUuid.alarmStatus,
          ),
        );
        if (statusMessage is! DeviceStatus || alarmMessage is! AlarmStatus) {
          throw const KbrpProtocolException('初始状态快照不完整');
        }
        status = statusMessage;
        alarm = alarmMessage;
        _publish(status);
        _publish(alarm);
      }
      _statusSnapshot = null;
      _alarmSnapshot = null;

      await UniversalBle.subscribeNotifications(
        device.deviceId,
        KbrpUuid.service,
        KbrpUuid.realtimeStream,
      );
      await UniversalBle.subscribeIndications(
        device.deviceId,
        KbrpUuid.service,
        KbrpUuid.latestReport,
      );
      if (status.latestReportAvailable) {
        final report = _decode(
          await UniversalBle.read(
            device.deviceId,
            KbrpUuid.service,
            KbrpUuid.latestReport,
          ),
        );
        if (report != null) _messages.add(report);
      }

      _reconnectAttempt = 0;
      phase = ConnectionPhase.ready;
      notifyListeners();
    } catch (error) {
      _setError(_friendlyError(error));
      if (reconnecting) _scheduleReconnect();
    }
  }

  void _validateGatt(List<BleService> services) {
    BleService? service;
    for (final candidate in services) {
      if (BleUuidParser.compareStrings(candidate.uuid, KbrpUuid.service)) {
        service = candidate;
        break;
      }
    }
    if (service == null) {
      throw const KbrpProtocolException('设备未提供兼容的只读服务');
    }
    final required = {
      KbrpUuid.protocolInfo,
      KbrpUuid.deviceStatus,
      KbrpUuid.realtimeStream,
      KbrpUuid.alarmStatus,
      KbrpUuid.latestReport,
    };
    for (final characteristic in service.characteristics) {
      required.removeWhere(
        (uuid) => BleUuidParser.compareStrings(characteristic.uuid, uuid),
      );
    }
    if (required.isNotEmpty) {
      throw const KbrpProtocolException('设备 GATT 特征不完整');
    }
  }

  void _listenTo(String deviceId, String characteristic) {
    _valueSubscriptions.add(
      UniversalBle.characteristicValueStream(deviceId, characteristic).listen(
        (value) {
          try {
            final message = _decode(value);
            if (message != null) _publish(message);
          } catch (error) {
            errorMessage = _friendlyError(error);
            notifyListeners();
          }
        },
        onError: (Object error) {
          errorMessage = _friendlyError(error);
          notifyListeners();
        },
      ),
    );
  }

  KbrpMessage? _decode(Uint8List value) => _assembler.add(value);

  void _publish(KbrpMessage message) {
    if (message is DeviceStatus && _statusSnapshot?.isCompleted == false) {
      _statusSnapshot!.complete(message);
    }
    if (message is AlarmStatus && _alarmSnapshot?.isCompleted == false) {
      _alarmSnapshot!.complete(message);
    }
    _messages.add(message);
  }

  Future<DeviceIdentity> _readIdentity(String deviceId) async {
    Future<String?> read(String characteristic) async {
      try {
        final bytes = await UniversalBle.read(
          deviceId,
          KbrpUuid.deviceInfoService,
          characteristic,
        );
        return String.fromCharCodes(bytes).trim();
      } catch (_) {
        return null;
      }
    }

    return DeviceIdentity(
      manufacturer: await read(KbrpUuid.manufacturerName),
      model: await read(KbrpUuid.modelNumber),
      firmware: await read(KbrpUuid.firmwareRevision),
    );
  }

  void _onConnectionChanged(bool connected) {
    if (connected || _manualDisconnect) return;
    _assembler.reset();
    unawaited(_clearValueSubscriptions());
    phase = ConnectionPhase.disconnected;
    notifyListeners();
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    final device = _selectedBleDevice;
    if (_manualDisconnect || device == null || _reconnectAttempt >= 5) return;
    _reconnectTimer?.cancel();
    final delay = Duration(seconds: 1 << _reconnectAttempt);
    _reconnectAttempt++;
    phase = ConnectionPhase.reconnecting;
    notifyListeners();
    _reconnectTimer = Timer(
      delay,
      () => unawaited(_connect(device, reconnecting: true)),
    );
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    final deviceId = selectedDevice?.id;
    await _clearValueSubscriptions();
    if (deviceId != null) await UniversalBle.disconnect(deviceId);
    selectedDevice = null;
    _selectedBleDevice = null;
    identity = const DeviceIdentity();
    negotiatedMtu = null;
    phase = ConnectionPhase.disconnected;
    notifyListeners();
  }

  Future<void> _clearValueSubscriptions() async {
    for (final subscription in _valueSubscriptions) {
      await subscription.cancel();
    }
    _valueSubscriptions.clear();
  }

  void _setError(String message) {
    errorMessage = message;
    phase = ConnectionPhase.error;
    notifyListeners();
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.toLowerCase().contains('permission')) {
      return '蓝牙权限未授予，请在系统设置中允许附近设备权限';
    }
    if (text.toLowerCase().contains('timeout')) {
      return '连接超时，请确认设备仍在配对模式且位于附近';
    }
    return text.replaceFirst(RegExp(r'^(Exception|Bad state):\s*'), '');
  }

  @override
  void dispose() {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    unawaited(_scanSubscription?.cancel());
    unawaited(_availabilitySubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(_clearValueSubscriptions());
    unawaited(_messages.close());
    super.dispose();
  }
}
