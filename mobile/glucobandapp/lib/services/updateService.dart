import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/apiConstant.dart';
import '../core/constants/appConstant.dart';
import '../data/models/appVersionModel.dart';

class UpdateService {
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 8),
  ));

  // Flag agar pengecekan otomatis saat start aplikasi hanya memunculkan dialog sekali per sesi
  static bool _hasPromptedThisSession = false;

  /// Mengambil data versi terbaru dari server backend
  static Future<AppVersionModel?> fetchLatestVersion() async {
    try {
      final response = await _dio.get(ApiConstants.appVersion);
      if (response.statusCode == 200 && response.data != null) {
        return AppVersionModel.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('[UpdateService] Gagal memeriksa versi aplikasi: $e');
    }
    return null;
  }

  /// Pengecekan versi aplikasi dan menampilkan dialog jika tersedia update baru
  static Future<void> checkForUpdate(BuildContext context, {bool isManual = false}) async {
    if (!isManual && _hasPromptedThisSession) {
      return;
    }

    if (isManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              SizedBox(width: 12),
              Text('Memeriksa versi terbaru...'),
            ],
          ),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF613EEA),
        ),
      );
    }

    final updateInfo = await fetchLatestVersion();

    if (!context.mounted) return;

    if (updateInfo == null) {
      if (isManual) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat terhubung ke server pembaruan.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final hasNewVersion = updateInfo.hasUpdate(
      AppConstants.currentBuildNumber,
      AppConstants.currentVersion,
    );

    if (hasNewVersion) {
      _hasPromptedThisSession = true;
      if (context.mounted) {
        showUpdateDialog(context, updateInfo);
      }
    } else if (isManual) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Aplikasi GlucoBand Anda sudah versi terbaru (v${AppConstants.currentVersion}).',
          ),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    }
  }

  /// Menampilkan dialog pembaruan aplikasi
  static void showUpdateDialog(BuildContext context, AppVersionModel updateInfo) {
    showDialog(
      context: context,
      barrierDismissible: !updateInfo.forceUpdate,
      builder: (dialogContext) {
        return PopScope(
          canPop: !updateInfo.forceUpdate,
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            elevation: 10,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon Header
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF613EEA).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: Color(0xFF613EEA),
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Title
                  const Text(
                    'Pembaruan Tersedia!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Version Tag
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'v${AppConstants.currentVersion} ➔ v${updateInfo.latestVersion}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF613EEA),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Changelog Title & Content
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Apa yang baru:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 140),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        updateInfo.changelog,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                  ),

                  if (updateInfo.forceUpdate) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 20, color: Colors.amber.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pembaruan ini wajib dilakukan untuk melanjutkan pemantauan kesehatan Anda.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // Update Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(updateInfo.downloadUrl);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (e) {
                          if (dialogContext.mounted) {
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text('Gagal membuka link unduhan: $e'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF613EEA),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Perbarui Sekarang',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  // Cancel / Later Button (Hanya jika bukan force update)
                  if (!updateInfo.forceUpdate) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                        ),
                        child: const Text(
                          'Nanti Saja',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
