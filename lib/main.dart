import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ui/kjr_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(KjrApp(controller: MonitorController()));
}
