import 'package:flutter_test/flutter_test.dart';
import 'package:kjr_monitor/app_state.dart';
import 'package:kjr_monitor/ui/kjr_app.dart';

void main() {
  testWidgets('设备扫描首页可正常渲染', (tester) async {
    await tester.pumpWidget(KjrApp(controller: MonitorController()));

    expect(find.text('KJR 呼吸监测'), findsOneWidget);
    expect(find.text('附近设备'), findsOneWidget);
    expect(find.text('扫描'), findsOneWidget);
  });
}
