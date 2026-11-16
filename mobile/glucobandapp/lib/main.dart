import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'presentation/providers/authProvider.dart';
import 'services/localNotificationService.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await LocalNotificationService.initialize();
  final authProvider = AuthProvider();
  await authProvider.checkLoginStatus();

  runApp(GlucoBandApp(authProvider: authProvider));
}
