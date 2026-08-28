import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/providers/authProvider.dart';
import 'presentation/providers/measurementProvider.dart';
import 'presentation/providers/notificationProvider.dart';
import 'presentation/providers/faqProvider.dart';
import 'presentation/providers/profileProvider.dart';
import 'presentation/providers/predictionProvider.dart';
import 'presentation/pages/loginPage.dart';
import 'presentation/pages/homePage.dart';

import 'package:google_fonts/google_fonts.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class GlucoBandApp extends StatelessWidget {
  const GlucoBandApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..checkLoginStatus()),
        ChangeNotifierProvider(create: (_) => MeasurementProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => FaqProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PredictionProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'GlucoBand',
        theme: ThemeData(
          primaryColor: const Color(0xFF613EEA),
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF613EEA)),
          textTheme: GoogleFonts.plusJakartaSansTextTheme(
            Theme.of(context).textTheme,
          ),
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
            if (auth.isLoggedIn) {
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
