import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profileProvider.dart';
import '../providers/authProvider.dart';
import '../providers/measurementProvider.dart';
import '../providers/notificationProvider.dart';
import '../../services/localNotificationService.dart';

class MeasurementResultPage extends StatefulWidget {
  final double glucose;
  final int heartRate;
  final double temperature;

  const MeasurementResultPage({
    super.key,
    required this.glucose,
    required this.heartRate,
    required this.temperature,
  });

  @override
  State<MeasurementResultPage> createState() => _MeasurementResultPageState();
}

class _MeasurementResultPageState extends State<MeasurementResultPage> {
  bool _isSaving = false;

  Future<void> _handleSave() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final profile = Provider.of<ProfileProvider>(context, listen: false);
      final measProvider = Provider.of<MeasurementProvider>(context, listen: false);

      // Ambil ID pasien yang sah dari sesi aktif akun
      final patientId = auth.user?.id != null && auth.user!.id > 0
          ? auth.user!.id
          : (profile.profileData?['id'] ?? 1);

      final isSuccess = await measProvider.saveMeasurement(
        patientId: patientId,
        glucose: widget.glucose,
        heartRate: widget.heartRate,
        temperature: widget.temperature,
      );

      if (!mounted) return;

      if (isSuccess) {
        // Jika kadar gula di luar rentang normal, munculkan notifikasi peringatan di HP & perbarui lonceng beranda
        String statusCalc = 'Normal';
        if (widget.glucose < 70) {
          statusCalc = 'Hipoglikemia';
        } else if (widget.glucose > 200) {
          statusCalc = 'Hiperglikemia';
        } else if (widget.glucose >= 140) {
          statusCalc = 'Waspada';
        }

        if (statusCalc != 'Normal') {
          LocalNotificationService.showGlucoseNotification(
            glucose: widget.glucose,
            status: statusCalc,
          );
        }

        if (auth.token != null) {
          Provider.of<NotificationProvider>(context, listen: false)
              .fetchNotifications(auth.token!);
        }

        // Tampilkan pop up hasil pengukuran telah tersimpan
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Pengukuran Tersimpan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Hasil pengukuran Anda berhasil disimpan.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF613EEA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );

        // Kembali ke halaman measurementPage
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        // Fallback: simpan di state lokal sementara
        measProvider.updateGlucose(widget.glucose);

        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.info_rounded, color: Color(0xFFF59E0B), size: 40),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tersimpan di Lokal',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Data pengukuran tersimpan di riwayat lokal perangkat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogCtx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF613EEA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );

        if (!mounted) return;
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat menyimpan: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.glucose > 200
        ? 'Hiperglikemia'
        : widget.glucose < 70
        ? 'Hipoglikemia'
        : 'Normal';

    final statusColor = widget.glucose > 200
        ? const Color(0xFFEF4444)
        : widget.glucose < 70
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Hasil Pengukuran'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Kartu hasil utama
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    statusColor,
                    statusColor.withValues(alpha: 0.7),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.monitor_heart,
                    color: Colors.white,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${widget.glucose.toInt()} mg/dL',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Kartu data tambahan
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    Icons.favorite,
                    const Color(0xFFEF4444),
                    '${widget.heartRate}',
                    'BPM (${widget.heartRate >= 60 && widget.heartRate <= 100 ? "Normal" : (widget.heartRate < 60 ? "Rendah" : "Tinggi")})',
                    'Detak Jantung (OLED)',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildInfoCard(
                    Icons.thermostat,
                    const Color(0xFFF59E0B),
                    '${widget.temperature.toStringAsFixed(1)}°C',
                    'Suhu Kulit',
                    'Inframerah MLX',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Kartu detail sensor & model
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Detail Pengukuran Terintegrasi',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Icons.favorite,
                    'Detak Jantung',
                    '${widget.heartRate} BPM',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.thermostat,
                    'Suhu Kulit',
                    '${widget.temperature.toStringAsFixed(1)} °C',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.wifi,
                    'Spektrometer NIR',
                    '6 Saluran Spektral',
                  ),
                  const Divider(height: 16),
                  _buildDetailRow(
                    Icons.psychology,
                    'Model Estimasi Glukosa',
                    'XGBoost Regressor v1.0 Non-Invasif',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Tombol-tombol aksi
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _handleSave,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Data',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF613EEA),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      disabledBackgroundColor: const Color(0xFF613EEA).withValues(alpha: 0.6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context, true);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text(
                      'Ukur Lagi',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF613EEA),
                      side: const BorderSide(
                        color: Color(0xFF613EEA),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    Color color,
    String value,
    String unit,
    String label,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String detail) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: const Color(0xFF613EEA)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              Text(
                detail,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
