import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/authProvider.dart';
import 'presentation/providers/measurementProvider.dart';
import 'presentation/providers/notificationProvider.dart';
import 'presentation/providers/faqProvider.dart';
import 'presentation/providers/profileProvider.dart';
import 'presentation/providers/predictionProvider.dart';
import 'presentation/providers/articleProvider.dart';
import 'presentation/providers/settingsProvider.dart';
import 'presentation/pages/loginPage.dart';
import 'presentation/pages/homePage.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class GlucoBandApp extends StatelessWidget {
  final AuthProvider? authProvider;

  const GlucoBandApp({super.key, this.authProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        if (authProvider != null)
          ChangeNotifierProvider.value(value: authProvider!)
        else
          ChangeNotifierProvider(
            create: (_) => AuthProvider()..checkLoginStatus(),
          ),
        ChangeNotifierProvider(create: (_) => MeasurementProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => FaqProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PredictionProvider()),
        ChangeNotifierProvider(create: (_) => ArticleProvider()),
        ChangeNotifierProvider(
          create: (_) => SettingsProvider()..fetchEmergencyContact(),
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'GlucoBand',
        theme: ThemeData(
          primaryColor: const Color(0xFF613EEA),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF613EEA)),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF1E293B),
            elevation: 0,
            centerTitle: true,
          ),
          scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        ),
        home: Consumer<AuthProvider>(
          builder: (context, auth, _) {
            // Karena status login sudah di-check di main() sebelum runApp,
            // Frame pertama Flutter langsung me-render HomePage tanpa perantara layar login/splash!
            if (auth.isLoggedIn) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final notifProvider = Provider.of<NotificationProvider>(
                  context,
                  listen: false,
                );
                if (auth.token != null) {
                  notifProvider.connectSocket(auth.token!);
                }
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
