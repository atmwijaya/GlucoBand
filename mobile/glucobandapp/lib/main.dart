import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'app.dart';
import 'presentation/providers/authProvider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Inisialisasi status autentikasi JWT di awal sebelum UI Flutter digambar
  final authProvider = AuthProvider();
  await authProvider.checkLoginStatus();

  runApp(GlucoBandApp(authProvider: authProvider));
}
