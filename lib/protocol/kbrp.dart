import 'dart:typed_data';

abstract final class KbrpUuid {
  static const service = '7a3c0000-6e4f-4b2d-9a10-52d8c1f0a201';
  static const protocolInfo = '7a3c0001-6e4f-4b2d-9a10-52d8c1f0a201';
  static const deviceStatus = '7a3c0002-6e4f-4b2d-9a10-52d8c1f0a201';
  static const realtimeStream = '7a3c0003-6e4f-4b2d-9a10-52d8c1f0a201';
  static const alarmStatus = '7a3c0004-6e4f-4b2d-9a10-52d8c1f0a201';
  static const latestReport = '7a3c0005-6e4f-4b2d-9a10-52d8c1f0a201';

  static const deviceInfoService = '0000180a-0000-1000-8000-00805f9b34fb';
  static const manufacturerName = '00002a29-0000-1000-8000-00805f9b34fb';
  static const modelNumber = '00002a24-0000-1000-8000-00805f9b34fb';
  static const firmwareRevision = '00002a26-0000-1000-8000-00805f9b34fb';
}

enum KbrpMessageType {
  protocolInfo(0x01),
  deviceStatus(0x02),
  realtimeMetrics(0x03),
  waveformBatch(0x04),
  alarmStatus(0x05),
  latestReport(0x06);

  const KbrpMessageType(this.value);
  final int value;

  static KbrpMessageType? fromValue(int value) {
    for (final type in values) {
      if (type.value == value) return type;
    }
    return null;
  }
}

enum RunState {
  starting,
  standby,
  preheating,
  therapy,
  fault,
  shuttingDown,
  unknown;

  static RunState fromValue(int value) => switch (value) {
    0 => starting,
    1 => standby,
    2 => preheating,
    3 => therapy,
    4 => fault,
    5 => shuttingDown,
    _ => unknown,
  };

  String get label => switch (this) {
    starting => '启动中',
    standby => '待机',
    preheating => '预加热',
    therapy => '治疗中',
    fault => '设备故障',
    shuttingDown => '正在停止',
    unknown => '未知状态',
  };
}

enum VentilationMode {
  unknown,
  cpap,
  apap,
  autoB,
  s,
  st;

  static VentilationMode fromValue(int value) => switch (value) {
    1 => cpap,
    2 => apap,
    3 => autoB,
    4 => s,
    5 => st,
    _ => unknown,
  };

  String get label => switch (this) {
    unknown => '未知模式',
    cpap => 'CPAP',
    apap => 'APAP',
    autoB => 'AUTO-B / VAuto',
    s => 'S',
    st => 'ST',
  };
}

sealed class KbrpMessage {
  const KbrpMessage({required this.sequence});
  final int sequence;
}

final class ProtocolInfo extends KbrpMessage {
  const ProtocolInfo({
    required super.sequence,
    required this.protocolMinor,
    required this.minClientMinor,
    required this.protocolFlags,
    required this.capabilityFlags,
    required this.bootId,
    required this.maxBodyLength,
    required this.preferredMtu,
    required this.defaultSamplePeriodMs,
    required this.defaultSamplesPerBatch,
    required this.maxConnections,
    required this.shortDeviceId,
  });

  final int protocolMinor;
  final int minClientMinor;
  final int protocolFlags;
  final int capabilityFlags;
  final int bootId;
  final int maxBodyLength;
  final int preferredMtu;
  final int defaultSamplePeriodMs;
  final int defaultSamplesPerBatch;
  final int maxConnections;
  final String shortDeviceId;

  bool supports(int capabilityBit) =>
      capabilityFlags & (1 << capabilityBit) != 0;
}

final class DeviceStatus extends KbrpMessage {
  const DeviceStatus({
    required super.sequence,
    required this.runState,
    required this.ventilationMode,
    required this.statusFlags,
    required this.uptimeMs,
    required this.epochTimeS,
    required this.therapyElapsedS,
    required this.pressureSetting1X10,
    required this.pressureSetting2X10,
  });

  final RunState runState;
  final VentilationMode ventilationMode;
  final int statusFlags;
  final int uptimeMs;
  final int epochTimeS;
  final int therapyElapsedS;
  final int? pressureSetting1X10;
  final int? pressureSetting2X10;

  bool get therapyActive => statusFlags & 0x01 != 0;
  bool get sourceDataValid => statusFlags & 0x04 != 0;
  bool get latestReportAvailable => statusFlags & 0x80 != 0;
}

final class RealtimeMetrics extends KbrpMessage {
  const RealtimeMetrics({
    required super.sequence,
    required this.validMask,
    required this.sampleUptimeMs,
    required this.pressureX10,
    required this.flowX10,
    required this.leakageX10,
    required this.tidalVolumeMl,
    required this.minuteVentilationX10,
    required this.respiratoryRateX10,
    required this.spo2X10,
    required this.pulseRateX10,
    required this.inspiratoryTimeMs,
    required this.expiratoryTimeMs,
  });

  final int validMask;
  final int sampleUptimeMs;
  final int? pressureX10;
  final int? flowX10;
  final int? leakageX10;
  final int? tidalVolumeMl;
  final int? minuteVentilationX10;
  final int? respiratoryRateX10;
  final int? spo2X10;
  final int? pulseRateX10;
  final int? inspiratoryTimeMs;
  final int? expiratoryTimeMs;
}

final class WaveformSample {
  const WaveformSample({required this.pressureX10, required this.flowX10});
  final int pressureX10;
  final int flowX10;
}

final class WaveformBatch extends KbrpMessage {
  const WaveformBatch({
    required super.sequence,
    required this.samplePeriodMs,
    required this.firstSampleUptimeMs,
    required this.samples,
  });

  final int samplePeriodMs;
  final int firstSampleUptimeMs;
  final List<WaveformSample> samples;
}

enum AlarmLevel { prompt, warning, critical }

final class ActiveAlarm {
  const ActiveAlarm({
    required this.bit,
    required this.name,
    required this.level,
  });
  final int bit;
  final String name;
  final AlarmLevel level;
}

final class AlarmStatus extends KbrpMessage {
  const AlarmStatus({
    required super.sequence,
    required this.alarmFlags,
    required this.turbineCode,
    required this.storageFault,
    required this.eventUptimeMs,
    required this.eventEpochS,
    required this.activeMask,
    required this.changedMask,
    required this.promptMask,
    required this.warningMask,
    required this.criticalMask,
  });

  final int alarmFlags;
  final int turbineCode;
  final int storageFault;
  final int eventUptimeMs;
  final int eventEpochS;
  final int activeMask;
  final int changedMask;
  final int promptMask;
  final int warningMask;
  final int criticalMask;

  bool get isSnapshot => alarmFlags & 0x02 != 0;
  bool get sourceValid => alarmFlags & 0x04 != 0;

  List<ActiveAlarm> get activeAlarms {
    const names = <String>[
      '系统泄漏',
      '管路堵塞',
      '管路脱落',
      '压力过高',
      '压力过低',
      '呼吸频率过高',
      '呼吸频率过低',
      '潮气量过低',
      '分钟通气量过低',
      '窒息',
      '加热盘故障',
      '压力传感器故障',
      '流量传感器故障',
      '电源故障',
      '水位低',
      '水箱未安装',
      '涡轮故障',
      '存储空间不足',
      '存储写入故障',
    ];
    return [
      for (var bit = 0; bit < names.length; bit++)
        if (activeMask & (1 << bit) != 0)
          ActiveAlarm(
            bit: bit,
            name: names[bit],
            level: criticalMask & (1 << bit) != 0
                ? AlarmLevel.critical
                : warningMask & (1 << bit) != 0
                ? AlarmLevel.warning
                : AlarmLevel.prompt,
          ),
    ];
  }
}

final class LatestReport extends KbrpMessage {
  const LatestReport({
    required super.sequence,
    required this.reportFlags,
    required this.ventilationMode,
    required this.endReason,
    required this.validMask,
    required this.reportId,
    required this.startEpochS,
    required this.endEpochS,
    required this.durationS,
    required this.values,
    required this.maskFit,
    required this.humidifier,
  });

  final int reportFlags;
  final VentilationMode ventilationMode;
  final int endReason;
  final int validMask;
  final String reportId;
  final int startEpochS;
  final int endEpochS;
  final int durationS;
  final Map<String, int> values;
  final int maskFit;
  final int humidifier;

  bool get hasReport => reportFlags & 0x01 != 0;
  bool isValid(int bit) => validMask & (1 << bit) != 0;
}

final class KbrpProtocolException implements Exception {
  const KbrpProtocolException(this.message);
  final String message;
  @override
  String toString() => 'KBRP: $message';
}

final class _TransportFragment {
  const _TransportFragment({
    required this.major,
    required this.type,
    required this.sequence,
    required this.index,
    required this.count,
    required this.totalLength,
    required this.data,
  });

  final int major;
  final KbrpMessageType type;
  final int sequence;
  final int index;
  final int count;
  final int totalLength;
  final Uint8List data;

  factory _TransportFragment.parse(Uint8List value) {
    if (value.length < 8) {
      throw const KbrpProtocolException('传输分片少于 8 字节');
    }
    final data = ByteData.sublistView(value);
    final major = data.getUint8(0);
    if (major != 1) {
      throw KbrpProtocolException('不支持的主版本 $major');
    }
    final type = KbrpMessageType.fromValue(data.getUint8(1));
    if (type == null) {
      throw const KbrpProtocolException('未知消息类型');
    }
    final count = data.getUint8(5);
    final index = data.getUint8(4);
    final totalLength = data.getUint16(6, Endian.little);
    if (count == 0 || index >= count) {
      throw const KbrpProtocolException('非法的分片索引');
    }
    if (totalLength < 2 || totalLength > 504) {
      throw KbrpProtocolException('非法消息长度 $totalLength');
    }
    return _TransportFragment(
      major: major,
      type: type,
      sequence: data.getUint16(2, Endian.little),
      index: index,
      count: count,
      totalLength: totalLength,
      data: Uint8List.sublistView(value, 8),
    );
  }
}

final class _PendingMessage {
  _PendingMessage(this.first);
  final _TransportFragment first;
  final createdAt = DateTime.now();
  final Map<int, Uint8List> fragments = {};
}

final class KbrpAssembler {
  final Map<KbrpMessageType, _PendingMessage> _pending = {};
  int maxBodyLength = 504;

  void reset() => _pending.clear();

  KbrpMessage? add(Uint8List value) {
    final fragment = _TransportFragment.parse(value);
    if (fragment.totalLength > maxBodyLength) {
      throw KbrpProtocolException('消息长度 ${fragment.totalLength} 超过设备限制');
    }
    _evictExpired();
    var pending = _pending[fragment.type];
    if (pending == null || pending.first.sequence != fragment.sequence) {
      pending = _PendingMessage(fragment);
      _pending[fragment.type] = pending;
    } else if (pending.first.count != fragment.count ||
        pending.first.totalLength != fragment.totalLength ||
        pending.first.major != fragment.major) {
      _pending.remove(fragment.type);
      throw const KbrpProtocolException('分片公共头不一致');
    }
    pending.fragments[fragment.index] = fragment.data;
    if (pending.fragments.length != fragment.count) return null;

    final builder = BytesBuilder(copy: false);
    for (var index = 0; index < fragment.count; index++) {
      final bytes = pending.fragments[index];
      if (bytes == null) return null;
      builder.add(bytes);
    }
    _pending.remove(fragment.type);
    final body = builder.takeBytes();
    if (body.length != fragment.totalLength) {
      throw KbrpProtocolException('重组长度 ${body.length} 与声明不一致');
    }
    final payload = Uint8List.sublistView(body, 0, body.length - 2);
    final expected = ByteData.sublistView(body)
        .getUint16(body.length - 2, Endian.little);
    final crcInput = Uint8List.fromList([
      fragment.major,
      fragment.type.value,
      fragment.sequence & 0xff,
      fragment.sequence >> 8,
      ...payload,
    ]);
    final actual = KbrpCodec.crc16(crcInput);
    if (actual != expected) {
      throw KbrpProtocolException(
        'CRC 校验失败: ${actual.toRadixString(16)} != ${expected.toRadixString(16)}',
      );
    }
    final message = KbrpCodec.decode(fragment.type, fragment.sequence, payload);
    if (message case ProtocolInfo(:final maxBodyLength)) {
      this.maxBodyLength = maxBodyLength.clamp(2, 504);
    }
    return message;
  }

  void _evictExpired() {
    final now = DateTime.now();
    _pending.removeWhere((type, pending) {
      final timeout = switch (type) {
        KbrpMessageType.realtimeMetrics ||
        KbrpMessageType.waveformBatch => const Duration(milliseconds: 500),
        KbrpMessageType.latestReport => const Duration(seconds: 5),
        _ => const Duration(seconds: 2),
      };
      return now.difference(pending.createdAt) > timeout;
    });
  }
}

abstract final class KbrpCodec {
  static int crc16(List<int> bytes) {
    var crc = 0xffff;
    for (final byte in bytes) {
      crc ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        crc = crc & 0x8000 != 0 ? (crc << 1) ^ 0x1021 : crc << 1;
        crc &= 0xffff;
      }
    }
    return crc;
  }

  static KbrpMessage decode(
    KbrpMessageType type,
    int sequence,
    Uint8List payload,
  ) {
    return switch (type) {
      KbrpMessageType.protocolInfo => _protocolInfo(sequence, payload),
      KbrpMessageType.deviceStatus => _deviceStatus(sequence, payload),
      KbrpMessageType.realtimeMetrics => _metrics(sequence, payload),
      KbrpMessageType.waveformBatch => _waveform(sequence, payload),
      KbrpMessageType.alarmStatus => _alarm(sequence, payload),
      KbrpMessageType.latestReport => _report(sequence, payload),
    };
  }

  static ByteData _checked(Uint8List payload, int minimum, String name) {
    if (payload.length < minimum) {
      throw KbrpProtocolException(
        '$name Payload 长度 ${payload.length} 小于 $minimum',
      );
    }
    if (payload[0] != 1) {
      throw KbrpProtocolException('$name Schema ${payload[0]} 不支持');
    }
    return ByteData.sublistView(payload);
  }

  static ProtocolInfo _protocolInfo(int sequence, Uint8List payload) {
    final data = _checked(payload, 24, 'Protocol Info');
    return ProtocolInfo(
      sequence: sequence,
      protocolMinor: data.getUint8(1),
      minClientMinor: data.getUint8(2),
      protocolFlags: data.getUint8(3),
      capabilityFlags: data.getUint32(4, Endian.little),
      bootId: data.getUint32(8, Endian.little),
      maxBodyLength: data.getUint16(12, Endian.little),
      preferredMtu: data.getUint16(14, Endian.little),
      defaultSamplePeriodMs: data.getUint16(16, Endian.little),
      defaultSamplesPerBatch: data.getUint8(18),
      maxConnections: data.getUint8(19),
      shortDeviceId: String.fromCharCodes(payload.sublist(20, 24)),
    );
  }

  static DeviceStatus _deviceStatus(int sequence, Uint8List payload) {
    final data = _checked(payload, 20, 'Device Status');
    int? pressure(int offset) {
      final value = data.getUint16(offset, Endian.little);
      return value == 0xffff ? null : value;
    }

    return DeviceStatus(
      sequence: sequence,
      runState: RunState.fromValue(data.getUint8(1)),
      ventilationMode: VentilationMode.fromValue(data.getUint8(2)),
      statusFlags: data.getUint8(3),
      uptimeMs: data.getUint32(4, Endian.little),
      epochTimeS: data.getUint32(8, Endian.little),
      therapyElapsedS: data.getUint32(12, Endian.little),
      pressureSetting1X10: pressure(16),
      pressureSetting2X10: pressure(18),
    );
  }

  static RealtimeMetrics _metrics(int sequence, Uint8List payload) {
    final data = _checked(payload, 28, 'Realtime Metrics');
    final validMask = data.getUint16(2, Endian.little);
    int? unsigned(int bit, int offset) => validMask & (1 << bit) == 0
        ? null
        : data.getUint16(offset, Endian.little);
    int? signed(int bit, int offset) => validMask & (1 << bit) == 0
        ? null
        : data.getInt16(offset, Endian.little);
    return RealtimeMetrics(
      sequence: sequence,
      validMask: validMask,
      sampleUptimeMs: data.getUint32(4, Endian.little),
      pressureX10: unsigned(0, 8),
      flowX10: signed(1, 10),
      leakageX10: unsigned(2, 12),
      tidalVolumeMl: unsigned(3, 14),
      minuteVentilationX10: unsigned(4, 16),
      respiratoryRateX10: unsigned(5, 18),
      spo2X10: unsigned(6, 20),
      pulseRateX10: unsigned(7, 22),
      inspiratoryTimeMs: unsigned(8, 24),
      expiratoryTimeMs: unsigned(9, 26),
    );
  }

  static WaveformBatch _waveform(int sequence, Uint8List payload) {
    final data = _checked(payload, 12, 'Waveform Batch');
    final count = data.getUint8(1);
    if (count < 1 || count > 10 || payload.length != 8 + count * 4) {
      throw const KbrpProtocolException('波形点数或长度非法');
    }
    return WaveformBatch(
      sequence: sequence,
      samplePeriodMs: data.getUint16(2, Endian.little),
      firstSampleUptimeMs: data.getUint32(4, Endian.little),
      samples: [
        for (var index = 0; index < count; index++)
          WaveformSample(
            pressureX10: data.getUint16(8 + index * 4, Endian.little),
            flowX10: data.getInt16(10 + index * 4, Endian.little),
          ),
      ],
    );
  }

  static AlarmStatus _alarm(int sequence, Uint8List payload) {
    final data = _checked(payload, 32, 'Alarm Status');
    return AlarmStatus(
      sequence: sequence,
      alarmFlags: data.getUint8(1),
      turbineCode: data.getUint8(2),
      storageFault: data.getUint8(3),
      eventUptimeMs: data.getUint32(4, Endian.little),
      eventEpochS: data.getUint32(8, Endian.little),
      activeMask: data.getUint32(12, Endian.little),
      changedMask: data.getUint32(16, Endian.little),
      promptMask: data.getUint32(20, Endian.little),
      warningMask: data.getUint32(24, Endian.little),
      criticalMask: data.getUint32(28, Endian.little),
    );
  }

  static LatestReport _report(int sequence, Uint8List payload) {
    final data = _checked(payload, 68, 'Latest Report');
    const names = <String>[
      'ahiX10',
      'hiX10',
      'caiX10',
      'oaiX10',
      'odiX10',
      'inhaleP95X10',
      'exhaleP95X10',
      'averagePressureX10',
      'averageLeakageX10',
      'averageSpo2X10',
      'minimumSpo2X10',
      'averagePulseRateX10',
      'respiratoryRateX10',
      'minuteVentilationX10',
      'spontTriggerX10',
      'spontCycleX10',
      'tidalVolumeMl',
      'inspiratoryTimeMs',
      'expiratoryTimeMs',
    ];
    final reportIdBytes = payload.sublist(8, 16).reversed;
    final reportId = reportIdBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return LatestReport(
      sequence: sequence,
      reportFlags: data.getUint8(1),
      ventilationMode: VentilationMode.fromValue(data.getUint8(2)),
      endReason: data.getUint8(3),
      validMask: data.getUint32(4, Endian.little),
      reportId: reportId,
      startEpochS: data.getUint32(16, Endian.little),
      endEpochS: data.getUint32(20, Endian.little),
      durationS: data.getUint32(24, Endian.little),
      values: {
        for (var index = 0; index < names.length; index++)
          names[index]: data.getUint16(28 + index * 2, Endian.little),
      },
      maskFit: data.getUint8(66),
      humidifier: data.getUint8(67),
    );
  }
}
