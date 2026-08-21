import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/lepeng_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(LepengApp(controller: MonitorController()));
}
