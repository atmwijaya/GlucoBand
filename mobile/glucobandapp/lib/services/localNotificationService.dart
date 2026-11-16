import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _prefPermissionPrompted = 'notif_permission_prompted';
  static const String _channelId = 'glucoband_glucose_alert';
  static const String _channelName = 'Peringatan Kadar Gula GlucoBand';
  static const String _channelDesc =
      'Notifikasi peringatan dini jika estimasi gula darah berada di luar batas normal';

  /// Inisialisasi local notifications plugin dan channel Android
  static Future<void> initialize() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[LocalNotif] Tapped notification payload: ${response.payload}');
      },
    );

    // Buat Notification Channel dengan prioritas tinggi di Android
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  /// Meminta izin notifikasi langsung ke OS (Android 13+ & iOS)
  static Future<bool> requestPermission() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefPermissionPrompted, true);

    bool granted = false;

    // Android 13+ (API 33+)
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final androidGranted =
          await androidPlugin.requestNotificationsPermission();
      granted = androidGranted ?? false;
    }

    // iOS
    final iosPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final iosGranted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      granted = iosGranted ?? false;
    }

    return granted;
  }

  /// Menampilkan dialog edukasi izin notifikasi yang ramah dan menarik kepada pengguna
  static Future<void> checkAndPromptPermission(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool(_prefPermissionPrompted) ?? false;
    if (hasPrompted) return;

    if (!context.mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        titlePadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFF613EEA).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF613EEA),
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Aktifkan Notifikasi Peringatan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'GlucoBand dapat mengirim peringatan otomatis ke handphone Anda jika estimasi kadar gula darah terdeteksi terlalu rendah (hipoglikemia) atau terlalu tinggi (hiperglikemia).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      await prefs.setBool(_prefPermissionPrompted, true);
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Nanti Saja',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      await requestPermission();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF613EEA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Izinkan',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Menampilkan push notification lokal jika kadar gula darah berada di luar batas normal
  static Future<void> showGlucoseNotification({
    required double glucose,
    required String status,
    String? message,
  }) async {
    final statusLower = status.toLowerCase();
    final bool isLow = statusLower.contains('hipo') || glucose < 70;
    final bool isHigh = statusLower.contains('hiper') || glucose > 200;
    final bool isWarning = statusLower.contains('waspada') || (glucose >= 140 && glucose <= 200);

    // Notifikasi hanya dimunculkan jika kondisi abnormal
    if (!isLow && !isHigh && !isWarning) return;

    String title;
    String body;
    int notificationId = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (isLow) {
      title = '🚨 Peringatan: Gula Darah Rendah (${glucose.toStringAsFixed(1)} mg/dL)';
      body = message ??
          'Status Hipoglikemia terdeteksi. Segera konsumsi sumber gula cepat (teh manis/permen) dan istirahat.';
    } else if (isHigh) {
      title = '⚠️ Peringatan: Gula Darah Tinggi (${glucose.toStringAsFixed(1)} mg/dL)';
      body = message ??
          'Status Hiperglikemia terdeteksi. Minum air putih yang cukup dan hindari asupan tinggi karbohidrat/gula.';
    } else {
      title = '⚠️ Perhatian: Gula Darah Waspada (${glucose.toStringAsFixed(1)} mg/dL)';
      body = message ??
          'Kadar gula darah di atas rentang normal. Batasi konsumsi manis dan pantau kondisi Anda.';
    }

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      styleInformation: BigTextStyleInformation(body),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: notificationId,
        title: title,
        body: body,
        notificationDetails: platformDetails,
        payload: 'glucose_${glucose.toStringAsFixed(1)}',
      );
    } catch (e) {
      debugPrint('[LocalNotif] Error showing notification: $e');
    }
  }
}
