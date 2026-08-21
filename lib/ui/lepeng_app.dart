import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../protocol/kbrp.dart';
import '../services/kbrp_ble_service.dart';

const _ink = Color(0xff172522);
const _muted = Color(0xff60706c);
const _teal = Color(0xff087f72);
const _green = Color(0xff25814c);
const _blue = Color(0xff3677a8);
const _surface = Color(0xfff5f7f6);
const _line = Color(0xffdce4e1);
const _danger = Color(0xffb4232f);

final class LepengApp extends StatefulWidget {
  const LepengApp({super.key, required this.controller});
  final MonitorController controller;

  @override
  State<LepengApp> createState() => _LepengAppState();
}

final class _LepengAppState extends State<LepengApp> {
  @override
  void dispose() {
    widget.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '乐鹏蓝牙测试',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _teal,
          brightness: Brightness.light,
          surface: Colors.white,
          error: _danger,
        ),
        scaffoldBackgroundColor: _surface,
        fontFamilyFallback: const [
          'Microsoft YaHei',
          'PingFang SC',
          'Noto Sans CJK SC',
        ],
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: _ink,
          elevation: 0,
          scrolledUnderElevation: 0,
          shape: Border(bottom: BorderSide(color: _line)),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(6)),
            side: BorderSide(color: _line),
          ),
        ),
      ),
      home: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final phase = widget.controller.ble.phase;
          final hasActiveDevice =
              widget.controller.ble.selectedDevice != null &&
              phase != ConnectionPhase.disconnected &&
              phase != ConnectionPhase.error;
          return hasActiveDevice
              ? _MonitorShell(controller: widget.controller)
              : _DevicePage(controller: widget.controller);
        },
      ),
    );
  }
}

final class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.air_rounded, color: _teal, size: 28),
        SizedBox(width: 10),
        Text(
          '乐鹏蓝牙测试',
          style: TextStyle(
            color: _ink,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class _DevicePage extends StatelessWidget {
  const _DevicePage({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final ble = controller.ble;
    return Scaffold(
      appBar: AppBar(
        title: const _Brand(),
        actions: [
          Tooltip(
            message: ble.phase == ConnectionPhase.scanning ? '停止扫描' : '扫描设备',
            child: IconButton(
              onPressed: ble.isBusy
                  ? null
                  : ble.phase == ConnectionPhase.scanning
                  ? ble.stopScan
                  : ble.startScan,
              icon: Icon(
                ble.phase == ConnectionPhase.scanning
                    ? Icons.stop_circle_outlined
                    : Icons.refresh_rounded,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '附近设备',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: _ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            ble.phase.label,
                            style: const TextStyle(color: _muted),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: ble.isBusy
                          ? null
                          : ble.phase == ConnectionPhase.scanning
                          ? ble.stopScan
                          : ble.startScan,
                      icon: ble.phase == ConnectionPhase.scanning
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.bluetooth_searching_rounded),
                      label: Text(
                        ble.phase == ConnectionPhase.scanning ? '停止' : '扫描',
                      ),
                    ),
                  ],
                ),
                if (ble.errorMessage != null) ...[
                  const SizedBox(height: 18),
                  _ErrorBanner(message: ble.errorMessage!),
                ],
                const SizedBox(height: 22),
                Expanded(
                  child: ble.devices.isEmpty
                      ? _EmptyDevices(
                          scanning: ble.phase == ConnectionPhase.scanning,
                        )
                      : ListView.separated(
                          itemCount: ble.devices.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final device = ble.devices[index];
                            return _DeviceTile(
                              device: device,
                              onConnect: ble.isBusy
                                  ? null
                                  : () => ble.connect(device),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _EmptyDevices extends StatelessWidget {
  const _EmptyDevices({required this.scanning});
  final bool scanning;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            scanning ? Icons.radar_rounded : Icons.bluetooth_disabled_rounded,
            size: 54,
            color: _muted,
          ),
          const SizedBox(height: 14),
          Text(
            scanning ? '正在查找兼容设备' : '尚未发现设备',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text(
            '请在设备本机开启数据传输并进入配对模式',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted),
          ),
        ],
      ),
    );
  }
}

final class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onConnect});
  final CompatibleDevice device;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xffe6f3f0),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.medical_services_outlined, color: _teal),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_signalLabel(device.rssi)}${device.paired ? '  ·  已配对' : ''}',
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                ],
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: onConnect,
              icon: const Icon(Icons.link_rounded),
              label: const Text('连接'),
            ),
          ],
        ),
      ),
    );
  }

  static String _signalLabel(int? rssi) {
    if (rssi == null) return '信号未知';
    if (rssi >= -60) return '信号良好  $rssi dBm';
    if (rssi >= -75) return '信号一般  $rssi dBm';
    return '信号较弱  $rssi dBm';
  }
}

final class _MonitorShell extends StatefulWidget {
  const _MonitorShell({required this.controller});
  final MonitorController controller;

  @override
  State<_MonitorShell> createState() => _MonitorShellState();
}

final class _MonitorShellState extends State<_MonitorShell> {
  int index = 0;

  static const destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: '概览'),
    NavigationDestination(
      icon: Icon(Icons.monitor_heart_outlined),
      label: '实时',
    ),
    NavigationDestination(icon: Icon(Icons.warning_amber_rounded), label: '报警'),
    NavigationDestination(icon: Icon(Icons.assignment_outlined), label: '报告'),
  ];

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final phase = controller.ble.phase;
    final pages = [
      _OverviewPage(controller: controller),
      _RealtimePage(controller: controller),
      _AlarmPage(controller: controller),
      _ReportPage(controller: controller),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        return Scaffold(
          appBar: AppBar(
            title: const _Brand(),
            actions: [
              _ConnectionBadge(phase: phase),
              const SizedBox(width: 8),
              Tooltip(
                message: '断开连接',
                child: IconButton(
                  onPressed: controller.disconnect,
                  icon: const Icon(Icons.link_off_rounded),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              if (desktop)
                NavigationRail(
                  selectedIndex: index,
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  labelType: NavigationRailLabelType.all,
                  backgroundColor: Colors.white,
                  groupAlignment: -0.75,
                  destinations: [
                    for (final destination in destinations)
                      NavigationRailDestination(
                        icon: destination.icon,
                        label: Text(destination.label),
                      ),
                  ],
                ),
              if (desktop) const VerticalDivider(width: 1),
              Expanded(child: pages[index]),
            ],
          ),
          bottomNavigationBar: desktop
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (value) =>
                      setState(() => index = value),
                  destinations: destinations,
                ),
        );
      },
    );
  }
}

final class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.phase});
  final ConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final ready = phase == ConnectionPhase.ready;
    return Semantics(
      label: phase.label,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ready ? _green : const Color(0xffc58b16),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Text(
            phase.label,
            style: const TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      ),
    );
  }
}

final class _PageFrame extends StatelessWidget {
  const _PageFrame({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(color: _ink, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(color: _muted)),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

final class _OverviewPage extends StatelessWidget {
  const _OverviewPage({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.deviceStatus;
    final metrics = controller.metrics;
    final identity = controller.ble.identity;
    return _PageFrame(
      title: '设备概览',
      subtitle:
          '${identity.model ?? controller.ble.selectedDevice?.name ?? '蓝牙设备'}  ·  '
          '固件 ${identity.firmware ?? '--'}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: status?.runState == RunState.fault
                  ? const Color(0xffffedef)
                  : const Color(0xffeaf5f0),
              border: Border.all(
                color: status?.runState == RunState.fault
                    ? const Color(0xffefb8bd)
                    : const Color(0xffb9dacb),
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Wrap(
              spacing: 34,
              runSpacing: 14,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _LabeledValue(
                  label: '运行状态',
                  value: status?.runState.label ?? '正在同步',
                  valueColor: status?.runState == RunState.fault
                      ? _danger
                      : _green,
                ),
                _LabeledValue(
                  label: '通气模式',
                  value: status?.ventilationMode.label ?? '--',
                ),
                _LabeledValue(
                  label: '本次治疗',
                  value: _duration(status?.therapyElapsedS),
                ),
                _LabeledValue(
                  label: 'MTU',
                  value: controller.ble.negotiatedMtu?.toString() ?? '系统协商',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _MetricGrid(
            children: [
              _MetricCard(
                icon: Icons.speed_rounded,
                label: '当前压力',
                value: _x10(metrics?.pressureX10, controller.metricsFresh),
                unit: 'cmH₂O',
              ),
              _MetricCard(
                icon: Icons.air_rounded,
                label: '潮气量',
                value: _raw(metrics?.tidalVolumeMl, controller.metricsFresh),
                unit: 'ml',
              ),
              _MetricCard(
                icon: Icons.water_drop_outlined,
                label: '漏气量',
                value: _x10(metrics?.leakageX10, controller.metricsFresh),
                unit: 'L/min',
              ),
              _MetricCard(
                icon: Icons.monitor_heart_outlined,
                label: '呼吸频率',
                value: _x10(
                  metrics?.respiratoryRateX10,
                  controller.metricsFresh,
                ),
                unit: '次/min',
              ),
              _MetricCard(
                icon: Icons.bloodtype_outlined,
                label: 'SpO₂',
                value: _x10(metrics?.spo2X10, controller.metricsFresh),
                unit: '%',
              ),
              _MetricCard(
                icon: Icons.favorite_border_rounded,
                label: '脉率',
                value: _x10(metrics?.pulseRateX10, controller.metricsFresh),
                unit: 'bpm',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Wrap(
                spacing: 40,
                runSpacing: 16,
                children: [
                  _DetailValue(
                    label: '设定压力 1',
                    value: _pressure(status?.pressureSetting1X10),
                  ),
                  _DetailValue(
                    label: '设定压力 2',
                    value: _pressure(status?.pressureSetting2X10),
                  ),
                  _DetailValue(
                    label: '设备标识',
                    value: controller.protocolInfo?.shortDeviceId ?? '--',
                  ),
                  _DetailValue(
                    label: '协议',
                    value: controller.protocolInfo == null
                        ? '--'
                        : 'KBRP 1.${controller.protocolInfo!.protocolMinor}',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _RealtimePage extends StatelessWidget {
  const _RealtimePage({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: '实时波形',
      subtitle: controller.waveformFresh ? '实时数据' : '波形已中断',
      child: Column(
        children: [
          _ChartPanel(
            title: '压力',
            unit: 'cmH₂O',
            color: _green,
            points: controller.pressureWaveform,
            fresh: controller.waveformFresh,
          ),
          const SizedBox(height: 14),
          _ChartPanel(
            title: '流量',
            unit: 'L/min',
            color: _blue,
            points: controller.flowWaveform,
            fresh: controller.waveformFresh,
          ),
          const SizedBox(height: 14),
          _MetricGrid(
            children: [
              _MetricCard(
                icon: Icons.compress_rounded,
                label: '分钟通气量',
                value: _x10(
                  controller.metrics?.minuteVentilationX10,
                  controller.metricsFresh,
                ),
                unit: 'L/min',
              ),
              _MetricCard(
                icon: Icons.login_rounded,
                label: '吸气时间',
                value: _milliseconds(
                  controller.metrics?.inspiratoryTimeMs,
                  controller.metricsFresh,
                ),
                unit: 's',
              ),
              _MetricCard(
                icon: Icons.logout_rounded,
                label: '呼气时间',
                value: _milliseconds(
                  controller.metrics?.expiratoryTimeMs,
                  controller.metricsFresh,
                ),
                unit: 's',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.unit,
    required this.color,
    required this.points,
    required this.fresh,
  });
  final String title;
  final String unit;
  final Color color;
  final List<ChartPoint> points;
  final bool fresh;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: _ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(unit, style: const TextStyle(color: _muted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 190,
              child: points.length < 2
                  ? const Center(
                      child: Text('等待波形数据', style: TextStyle(color: _muted)),
                    )
                  : Opacity(
                      opacity: fresh ? 1 : 0.4,
                      child: CustomPaint(
                        painter: _WaveformPainter(points: points, color: color),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({required this.points, required this.color});
  final List<ChartPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = _line
      ..strokeWidth = 1;
    for (var row = 0; row <= 4; row++) {
      final y = size.height * row / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var column = 0; column <= 6; column++) {
      final x = size.width * column / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    var minimum = points.first.value;
    var maximum = points.first.value;
    for (final point in points) {
      minimum = math.min(minimum, point.value);
      maximum = math.max(maximum, point.value);
    }
    if ((maximum - minimum).abs() < 0.1) {
      minimum -= 1;
      maximum += 1;
    }
    final range = maximum - minimum;
    final path = Path();
    for (var index = 0; index < points.length; index++) {
      final x = size.width * index / (points.length - 1);
      final y =
          size.height - ((points[index].value - minimum) / range * size.height);
      if (index == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WaveformPainter oldDelegate) => true;
}

final class _AlarmPage extends StatelessWidget {
  const _AlarmPage({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.alarmStatus;
    final alarms = status?.activeAlarms ?? const <ActiveAlarm>[];
    return _PageFrame(
      title: '当前报警',
      subtitle: controller.connected ? '设备当前完整报警快照' : '已离线，缓存不代表当前状态',
      child: alarms.isEmpty
          ? Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 52,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Icon(
                      controller.connected
                          ? Icons.check_circle_outline_rounded
                          : Icons.cloud_off_outlined,
                      color: controller.connected ? _green : _muted,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      controller.connected ? '当前无活动报警' : '报警状态不可用',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                for (final alarm in alarms) ...[
                  _AlarmTile(
                    alarm: alarm,
                    changed: status!.changedMask & (1 << alarm.bit) != 0,
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

final class _AlarmTile extends StatelessWidget {
  const _AlarmTile({required this.alarm, required this.changed});
  final ActiveAlarm alarm;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (alarm.level) {
      AlarmLevel.critical => (_danger, '严重'),
      AlarmLevel.warning => (const Color(0xffa46400), '警告'),
      AlarmLevel.prompt => (_blue, '提示'),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                alarm.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _ink,
                ),
              ),
            ),
            if (changed)
              const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Text(
                  '刚刚变化',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ReportPage extends StatelessWidget {
  const _ReportPage({required this.controller});
  final MonitorController controller;

  @override
  Widget build(BuildContext context) {
    final report = controller.latestReport;
    return _PageFrame(
      title: '最近治疗报告',
      subtitle: report == null
          ? '设备尚未提供有效报告'
          : '${_dateTime(report.endEpochS)}  ·  ${report.ventilationMode.label}',
      child: report == null
          ? const Card(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 52, horizontal: 20),
                child: Column(
                  children: [
                    Icon(Icons.assignment_outlined, size: 48, color: _muted),
                    SizedBox(height: 12),
                    Text('暂无最近报告'),
                  ],
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Wrap(
                      spacing: 48,
                      runSpacing: 18,
                      children: [
                        _LabeledValue(
                          label: '治疗时长',
                          value: _duration(report.durationS),
                        ),
                        _LabeledValue(
                          label: 'AHI',
                          value: report.isValid(2)
                              ? _reportX10(report, 'ahiX10')
                              : '--',
                        ),
                        _LabeledValue(
                          label: '平均压力',
                          value: report.isValid(8)
                              ? '${_reportX10(report, 'averagePressureX10')} cmH₂O'
                              : '--',
                        ),
                        _LabeledValue(
                          label: '平均漏气',
                          value: report.isValid(9)
                              ? '${_reportX10(report, 'averageLeakageX10')} L/min'
                              : '--',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _MetricGrid(
                  children: [
                    _ReportMetric(
                      label: 'HI',
                      value: report.isValid(3)
                          ? _reportX10(report, 'hiX10')
                          : '--',
                    ),
                    _ReportMetric(
                      label: 'CAI',
                      value: report.isValid(4)
                          ? _reportX10(report, 'caiX10')
                          : '--',
                    ),
                    _ReportMetric(
                      label: 'OAI',
                      value: report.isValid(5)
                          ? _reportX10(report, 'oaiX10')
                          : '--',
                    ),
                    _ReportMetric(
                      label: 'ODI',
                      value: report.isValid(6)
                          ? _reportX10(report, 'odiX10')
                          : '--',
                    ),
                    _ReportMetric(
                      label: '平均 SpO₂',
                      value: report.isValid(10)
                          ? '${_reportX10(report, 'averageSpo2X10')}%'
                          : '--',
                    ),
                    _ReportMetric(
                      label: '平均脉率',
                      value: report.isValid(11)
                          ? '${_reportX10(report, 'averagePulseRateX10')} bpm'
                          : '--',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  '报告 ID  ${report.reportId}',
                  style: const TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
    );
  }
}

final class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 920
            ? 3
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
  });
  final IconData icon;
  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          children: [
            Icon(icon, color: _teal, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(color: _muted, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _ink,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (unit.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            unit,
                            style: const TextStyle(color: _muted, fontSize: 12),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ReportMetric extends StatelessWidget {
  const _ReportMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: _LabeledValue(label: label, value: value),
      ),
    );
  }
}

final class _LabeledValue extends StatelessWidget {
  const _LabeledValue({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? _ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

final class _DetailValue extends StatelessWidget {
  const _DetailValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: _LabeledValue(label: label, value: value),
    );
  }
}

final class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xffffedef),
        border: Border.all(color: const Color(0xffefb8bd)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: _danger)),
          ),
        ],
      ),
    );
  }
}

String _x10(int? value, bool fresh) =>
    value == null || !fresh ? '--' : (value / 10).toStringAsFixed(1);
String _raw(int? value, bool fresh) =>
    value == null || !fresh ? '--' : '$value';
String _milliseconds(int? value, bool fresh) =>
    value == null || !fresh ? '--' : (value / 1000).toStringAsFixed(2);
String _pressure(int? value) =>
    value == null ? '--' : '${(value / 10).toStringAsFixed(1)} cmH₂O';
String _duration(int? seconds) {
  if (seconds == null) return '--';
  final hours = seconds ~/ 3600;
  final minutes = seconds % 3600 ~/ 60;
  return hours > 0 ? '$hours 小时 $minutes 分' : '$minutes 分钟';
}

String _dateTime(int epochSeconds) {
  if (epochSeconds == 0) return '时间未校准';
  final date = DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000)
      .toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)} '
      '${two(date.hour)}:${two(date.minute)}';
}

String _reportX10(LatestReport report, String key) =>
    ((report.values[key] ?? 0) / 10).toStringAsFixed(1);
