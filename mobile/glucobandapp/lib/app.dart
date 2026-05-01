// app.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/authProvider.dart';
import 'presentation/providers/measurementProvider.dart';
import 'presentation/providers/notificationProvider.dart';
import 'presentation/providers/faqProvider.dart';
import 'presentation/providers/profileProvider.dart';
import 'presentation/pages/loginPage.dart';
import 'presentation/pages/homePage.dart';

class GlucoBandApp extends StatelessWidget {
  const GlucoBandApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLoginStatus()),
        ChangeNotifierProvider(create: (_) => MeasurementProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => FaqProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
      ],
      child: MaterialApp(
        title: 'GlucoBand',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            if (auth.isLoggedIn) {
              // Hubungkan WebSocket saat aplikasi terbuka dengan sesi yang sudah ada
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
                notifProvider.connectSocket(auth.token!);
              });
              return const HomePage();
            }
            return const LoginPage();
          },
        ),
      ),
    );
  }
}