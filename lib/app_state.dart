import 'dart:async';

import 'package:flutter/foundation.dart';

import 'protocol/kbrp.dart';
import 'services/kbrp_ble_service.dart';

final class ChartPoint {
  const ChartPoint({required this.timeMs, required this.value});
  final int timeMs;
  final double value;
}

final class MonitorController extends ChangeNotifier {
  MonitorController({KbrpBleService? bleService})
    : ble = bleService ?? KbrpBleService() {
    _bleListener = () => notifyListeners();
    ble.addListener(_bleListener);
    _messageSubscription = ble.messages.listen(_onMessage);
    _freshnessTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => notifyListeners(),
    );
  }

  final KbrpBleService ble;
  late final VoidCallback _bleListener;
  late final StreamSubscription<KbrpMessage> _messageSubscription;
  late final Timer _freshnessTimer;

  ProtocolInfo? protocolInfo;
  DeviceStatus? deviceStatus;
  RealtimeMetrics? metrics;
  AlarmStatus? alarmStatus;
  LatestReport? latestReport;
  DateTime? _metricsReceivedAt;
  DateTime? _waveformReceivedAt;
  final List<ChartPoint> pressureWaveform = [];
  final List<ChartPoint> flowWaveform = [];

  bool get connected => ble.phase == ConnectionPhase.ready;
  bool get metricsFresh =>
      connected &&
      _metricsReceivedAt != null &&
      DateTime.now().difference(_metricsReceivedAt!) <
          const Duration(seconds: 3);
  bool get waveformFresh =>
      connected &&
      _waveformReceivedAt != null &&
      DateTime.now().difference(_waveformReceivedAt!) <
          const Duration(seconds: 1);

  void _onMessage(KbrpMessage message) {
    switch (message) {
      case ProtocolInfo():
        if (protocolInfo?.bootId != null &&
            protocolInfo!.bootId != message.bootId) {
          _clearRealtime();
          deviceStatus = null;
          alarmStatus = null;
        }
        protocolInfo = message;
      case DeviceStatus():
        deviceStatus = message;
      case RealtimeMetrics():
        metrics = message;
        _metricsReceivedAt = DateTime.now();
      case WaveformBatch():
        for (var index = 0; index < message.samples.length; index++) {
          final time =
              message.firstSampleUptimeMs + index * message.samplePeriodMs;
          pressureWaveform.add(
            ChartPoint(
              timeMs: time,
              value: message.samples[index].pressureX10 / 10,
            ),
          );
          flowWaveform.add(
            ChartPoint(
              timeMs: time,
              value: message.samples[index].flowX10 / 10,
            ),
          );
        }
        _trimWaveform();
        _waveformReceivedAt = DateTime.now();
      case AlarmStatus():
        alarmStatus = message;
      case LatestReport():
        if (message.hasReport) latestReport = message;
    }
    notifyListeners();
  }

  void _trimWaveform() {
    const maxPoints = 300;
    if (pressureWaveform.length > maxPoints) {
      pressureWaveform.removeRange(0, pressureWaveform.length - maxPoints);
    }
    if (flowWaveform.length > maxPoints) {
      flowWaveform.removeRange(0, flowWaveform.length - maxPoints);
    }
  }

  void _clearRealtime() {
    metrics = null;
    _metricsReceivedAt = null;
    _waveformReceivedAt = null;
    pressureWaveform.clear();
    flowWaveform.clear();
  }

  Future<void> disconnect() async {
    await ble.disconnect();
    deviceStatus = null;
    alarmStatus = null;
    _clearRealtime();
    notifyListeners();
  }

  @override
  void dispose() {
    _freshnessTimer.cancel();
    unawaited(_messageSubscription.cancel());
    ble.removeListener(_bleListener);
    ble.dispose();
    super.dispose();
  }
}
