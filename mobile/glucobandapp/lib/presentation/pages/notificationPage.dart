import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notificationProvider.dart';
import '../providers/authProvider.dart';
import '../../data/models/notificationModel.dart';
import 'measurementHistoryPage.dart';

class NotificationListPage extends StatefulWidget {
  const NotificationListPage({super.key});

  @override
  State<NotificationListPage> createState() => _NotificationListPageState();
}

class _NotificationListPageState extends State<NotificationListPage> {
  Future<void> _onRefresh() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token != null) {
      // markAsRead: false agar notifikasi unread tetap mempertahankan status unread
      // dan hanya berubah menjadi read ketika di-inspect / diklik oleh pengguna
      await Provider.of<NotificationProvider>(context, listen: false)
          .fetchNotifications(token, markAsRead: false);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRefresh());
  }

  /// Membuka lembar inspeksi detail notifikasi
  void _showNotificationDetail(BuildContext context, NotificationItem notif) {
    final isAlert = notif.type == 'alert';
    final isSubTypeHypo = notif.subtype == 'hipoglikemia';
    final isSubTypeHyper = notif.subtype == 'hiperglikemia';

    Color accentColor = const Color(0xFF613EEA);
    IconData accentIcon = Icons.medical_services_outlined;
    Color accentBg = const Color(0xFFEFF6FF);
    String headerTitle = 'Rekomendasi Medis';

    if (isAlert) {
      if (isSubTypeHypo) {
        accentColor = const Color(0xFFF59E0B);
        accentIcon = Icons.warning_amber_rounded;
        accentBg = const Color(0xFFFFFBEB);
        headerTitle = 'Peringatan Hipoglikemia';
      } else if (isSubTypeHyper) {
        accentColor = const Color(0xFFEF4444);
        accentIcon = Icons.warning_rounded;
        accentBg = const Color(0xFFFEF2F2);
        headerTitle = 'Peringatan Hiperglikemia';
      } else {
        accentColor = const Color(0xFF613EEA);
        accentIcon = Icons.health_and_safety_outlined;
        accentBg = const Color(0xFFF5F3FF);
        headerTitle = 'Peringatan Glukosa';
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Indicator Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header Status & Kategori
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(accentIcon, color: accentColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headerTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 11, color: Color(0xFF16A34A)),
                                  SizedBox(width: 4),
                                  Text(
                                    'Sudah Dibaca',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF16A34A),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (notif.formattedCreatedAt != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  notif.formattedCreatedAt!,
                                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Card Kadar Glukosa (Jika Notifikasi Pengukuran)
              if (notif.glucoseValue != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kadar Glukosa Terukur',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                notif.glucoseValue!.toStringAsFixed(0),
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: accentColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'mg/dL',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isSubTypeHyper
                              ? 'Tinggi'
                              : (isSubTypeHypo ? 'Rendah' : 'Peringatan'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Konten Pesan Notifikasi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Rincian Pesan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notif.message,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Petunjuk / Rekomendasi Medis Sesuai Kasus
              if (isSubTypeHyper)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rekomendasi Tindakan:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFBE123C),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Perbanyak minum air putih untuk rehidrasi.\n• Batasi konsumsi karbohidrat dan gula sederhana.\n• Pantau kembali kadar gula dalam 1-2 jam ke depan.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF9F1239), height: 1.4),
                      ),
                    ],
                  ),
                )
              else if (isSubTypeHypo)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rekomendasi Tindakan Cepat (Aturan 15):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB45309),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '• Konsumsi segera 15 gram gula cepat serap (seperti 1/2 gelas jus/teh manis atau 1 sdm madu).\n• Istirahat selama 15 menit, lalu lakukan pengukuran ulang.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Tombol Tindakan
              Row(
                children: [
                  if (isAlert) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(bottomCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const MeasurementHistoryPage(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text(
                          'Lihat Riwayat',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF613EEA),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(bottomCtx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Tutup',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Notifikasi',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, provider, _) {
              if (provider.unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                onPressed: () {
                  if (token != null) {
                    provider.markAllAsRead(token);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Semua notifikasi telah ditandai dibaca'),
                        behavior: SnackBarBehavior.floating,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF613EEA)),
                label: const Text(
                  'Tandai Dibaca',
                  style: TextStyle(
                    color: Color(0xFF613EEA),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF613EEA),
        child: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.notifications.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_off_outlined, size: 48, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tidak ada notifikasi',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Anda belum memiliki riwayat notifikasi',
                      style: TextStyle(color: Colors.grey[400], fontSize: 13),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              itemCount: provider.notifications.length,
              itemBuilder: (context, index) {
                final notif = provider.notifications[index];
                final isAlert = notif.type == 'alert';
                final isSubTypeHypo = notif.subtype == 'hipoglikemia';
                final isSubTypeHyper = notif.subtype == 'hiperglikemia';

                Color accentColor = const Color(0xFF613EEA);
                IconData accentIcon = Icons.medical_services_outlined;
                Color accentBg = const Color(0xFFEFF6FF);

                if (isAlert) {
                  if (isSubTypeHypo) {
                    accentColor = const Color(0xFFF59E0B);
                    accentIcon = Icons.warning_amber_rounded;
                    accentBg = const Color(0xFFFFFBEB);
                  } else if (isSubTypeHyper) {
                    accentColor = const Color(0xFFEF4444);
                    accentIcon = Icons.warning_rounded;
                    accentBg = const Color(0xFFFEF2F2);
                  }
                }

                final bool isUnread = !notif.isRead;

                return TweenAnimationBuilder<Color?>(
                  tween: ColorTween(
                    begin: notif.isNew ? const Color(0xFFE0E7FF) : Colors.white,
                    end: Colors.white,
                  ),
                  duration: const Duration(seconds: 3),
                  onEnd: () => notif.isNew = false,
                  builder: (context, color, child) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isUnread ? Colors.white : const Color(0xFFFAFAFA),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isUnread
                              ? accentColor.withValues(alpha: 0.3)
                              : const Color(0xFFE2E8F0),
                          width: isUnread ? 1.5 : 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isUnread ? 0.05 : 0.02),
                            blurRadius: isUnread ? 10 : 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: InkWell(
                        onTap: () {
                          // 1. Tandai sebagai read secara instan dan sinkronkan ke server
                          if (token != null) {
                            provider.markAsRead(notif, token);
                          }
                          // 2. Buka dialog inspeksi rincian notifikasi
                          _showNotificationDetail(context, notif);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Ikon Kategori
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: accentBg,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(accentIcon, color: accentColor, size: 22),
                              ),
                              const SizedBox(width: 14),

                              // Teks & Status
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            notif.message,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isUnread
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: isUnread
                                                  ? const Color(0xFF0F172A)
                                                  : const Color(0xFF475569),
                                              height: 1.4,
                                            ),
                                          ),
                                        ),

                                        // Indikator Titik Merah & Tag BARU jika UNREAD
                                        if (isUnread) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            width: 10,
                                            height: 10,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFEF4444), // Titik merah unread
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        if (isUnread) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'Belum Dibaca',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFFDC2626),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          notif.formattedCreatedAt ?? '',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
