import 'package:flutter_test/flutter_test.dart';
import 'package:lepeng_bluetooth_test/app_state.dart';
import 'package:lepeng_bluetooth_test/ui/lepeng_app.dart';

void main() {
  testWidgets('设备扫描首页可正常渲染', (tester) async {
    await tester.pumpWidget(LepengApp(controller: MonitorController()));

    expect(find.text('乐鹏蓝牙测试'), findsOneWidget);
    expect(find.text('附近设备'), findsOneWidget);
    expect(find.text('扫描'), findsOneWidget);
  });
}
