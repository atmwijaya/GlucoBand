import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/authProvider.dart';
import '../../services/systemSettingsService.dart';
import '../../services/backgroundMonitoringService.dart';
import '../../services/espService.dart';
import '../widgets/deviceConfigDialog.dart';
import '../../core/constants/appConstant.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _isBackgroundServiceRunning = false;
  bool _isNotificationsEnabled = true;
  bool _isBatteryOptimizationIgnored = false;
  String _espDeviceIp = '192.168.4.1';

  // State untuk form ubah kata sandi
  bool _twoFactorEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSystemSettings();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Sinkronkan status izin dan layanan saat user kembali dari pengaturan Android (Resumed)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadSystemSettings();
    }
  }

  Future<void> _loadSystemSettings() async {
    final bgRunning = await BackgroundMonitoringService.isRunning();
    final notifEnabled = await SystemSettingsService.areNotificationsEnabled();
    final batteryIgnored = await SystemSettingsService.isBatteryOptimizationIgnored();
    final ip = await EspService.getDeviceIp();

    if (mounted) {
      setState(() {
        _isBackgroundServiceRunning = bgRunning;
        _isNotificationsEnabled = notifEnabled;
        _isBatteryOptimizationIgnored = batteryIgnored;
        _espDeviceIp = ip;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleBackgroundService(bool enable) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isBackgroundServiceRunning = enable);

    if (enable) {
      await BackgroundMonitoringService.startService(
        patientId: auth.user?.id,
        token: auth.token,
      );
    } else {
      await BackgroundMonitoringService.stopService();
    }

    await Future.delayed(const Duration(milliseconds: 300));
    final running = await BackgroundMonitoringService.isRunning();
    if (mounted) {
      setState(() => _isBackgroundServiceRunning = running);
    }
  }

  void _showChangePasswordDialog() {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSubmitting = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 24,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF613EEA).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.lock_reset_rounded, color: Color(0xFF613EEA), size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Ubah Kata Sandi',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Masukkan kata sandi saat ini dan tentukan kata sandi baru (minimal 8 karakter kombinasi huruf dan angka).',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 18),

                    if (errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Input Password Lama
                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi Saat Ini',
                        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF613EEA), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureOld ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscureOld = !obscureOld),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Input Password Baru
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'Kata Sandi Baru',
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF613EEA), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Konfirmasi Password Baru
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Konfirmasi Kata Sandi Baru',
                        prefixIcon: const Icon(Icons.check_circle_outline, color: Color(0xFF613EEA), size: 20),
                        suffixIcon: IconButton(
                          icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility, size: 20),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Simpan
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final oldP = oldPasswordController.text.trim();
                                final newP = newPasswordController.text.trim();
                                final confirmP = confirmPasswordController.text.trim();

                                if (oldP.isEmpty || newP.isEmpty) {
                                  setModalState(() => errorMessage = 'Semua kolom kata sandi wajib diisi.');
                                  return;
                                }
                                if (newP != confirmP) {
                                  setModalState(() => errorMessage = 'Konfirmasi kata sandi baru tidak cocok.');
                                  return;
                                }
                                if (newP.length < 8) {
                                  setModalState(() => errorMessage = 'Kata sandi baru minimal 8 karakter.');
                                  return;
                                }

                                setModalState(() {
                                  isSubmitting = true;
                                  errorMessage = null;
                                });

                                final res = await SystemSettingsService.changePassword(
                                  oldPassword: oldP,
                                  newPassword: newP,
                                );

                                if (res['success'] == true) {
                                  if (!mounted) return;
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res['message'] ?? 'Kata sandi berhasil diperbarui'),
                                      backgroundColor: const Color(0xFF059669),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } else {
                                  setModalState(() {
                                    isSubmitting = false;
                                    errorMessage = res['message'] ?? 'Gagal memperbarui kata sandi.';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF613EEA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Simpan Kata Sandi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF613EEA)))
          : RefreshIndicator(
              onRefresh: _loadSystemSettings,
              color: const Color(0xFF613EEA),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // 1. Bagian Izin & Layanan Sistem HP
                    // ==========================================
                    _buildSectionHeader('Izin & Layanan Sistem HP', Icons.tune_rounded),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Item 1: Layanan Latar Belakang (Foreground Service)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (_isBackgroundServiceRunning ? const Color(0xFF10B981) : const Color(0xFF94A3B8)).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.sync_rounded,
                                    color: _isBackgroundServiceRunning ? const Color(0xFF059669) : const Color(0xFF64748B),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Layanan Latar Belakang',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B)),
                                      ),
                                      SizedBox(height: 3),
                                      Text(
                                        'Terus memantau denyut dan glukosa gelang saat layar mati atau swipe RAM.',
                                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.25),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _isBackgroundServiceRunning,
                                  onChanged: _toggleBackgroundService,
                                  activeThumbColor: const Color(0xFF613EEA),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFE2E8F0)),

                          // Item 2: Notifikasi Sistem HP
                          InkWell(
                            onTap: () => SystemSettingsService.openNotificationSettings(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (_isNotificationsEnabled ? const Color(0xFF613EEA) : const Color(0xFFEF4444)).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      _isNotificationsEnabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
                                      color: _isNotificationsEnabled ? const Color(0xFF613EEA) : const Color(0xFFDC2626),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Notifikasi Sistem HP',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B)),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Peringatan penting kadar gula darah darurat dan info status gelang.',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.25),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isNotificationsEnabled,
                                    onChanged: (val) async {
                                      await SystemSettingsService.openNotificationSettings();
                                    },
                                    activeThumbColor: const Color(0xFF613EEA),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFE2E8F0)),

                          // Item 3: Penghemat Baterai OS (Battery Optimization)
                          InkWell(
                            onTap: () => SystemSettingsService.requestIgnoreBatteryOptimizations(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (_isBatteryOptimizationIgnored ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.battery_charging_full_rounded,
                                      color: _isBatteryOptimizationIgnored ? const Color(0xFF059669) : const Color(0xFFD97706),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Optimasi Baterai HP',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B)),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Izinkan berjalan tanpa batas latar belakang agar pengukuran tidak terhenti saat swipe RAM.',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B), height: 1.25),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isBatteryOptimizationIgnored,
                                    onChanged: (val) async {
                                      await SystemSettingsService.requestIgnoreBatteryOptimizations();
                                    },
                                    activeThumbColor: const Color(0xFF613EEA),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFE2E8F0)),

                          // Item 4: Info Aplikasi & Izin Lengkap Android
                          InkWell(
                            onTap: () => SystemSettingsService.openAppDetailsSettings(),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              child: Row(
                                children: [
                                  Icon(Icons.app_settings_alt_outlined, color: Color(0xFF64748B), size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Pengaturan Izin Aplikasi Lengkap di Android',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // 2. Bagian Keamanan Akun (Dipindahkan dari Profil)
                    // ==========================================
                    _buildSectionHeader('Keamanan Akun', Icons.security_rounded),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Change Password
                          InkWell(
                            onTap: _showChangePasswordDialog,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF613EEA).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF613EEA), size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ubah Kata Sandi',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B)),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Perbarui kata sandi akun untuk menjaga keamanan data rekam medis.',
                                          style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFE2E8F0)),

                          // Two-Factor Authentication
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF613EEA).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.shield_outlined, color: Color(0xFF613EEA), size: 22),
                                ),
                                const SizedBox(width: 14),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Autentikasi Dua Langkah (2FA)',
                                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B)),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Lapisan keamanan ekstra saat melakukan login dari perangkat baru.',
                                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: _twoFactorEnabled,
                                  onChanged: (val) {
                                    setState(() => _twoFactorEnabled = val);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(val ? '2FA diaktifkan untuk akun Anda' : '2FA dinonaktifkan'),
                                        duration: const Duration(seconds: 2),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  },
                                  activeThumbColor: const Color(0xFF613EEA),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFE2E8F0)),

                          // Sesi Akun Aktif
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_pin_rounded, color: Color(0xFF0284C7), size: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        user?.name ?? 'Pengguna',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B)),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${user?.email ?? '-'} • Pasien ID: ${user?.id ?? 1}',
                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==========================================
                    // 3. Bagian Perangkat & Jaringan Gelang
                    // ==========================================
                    _buildSectionHeader('Konektivitas Gelang GlucoBand', Icons.watch_outlined),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Setup IP & WiFi Gelang
                          InkWell(
                            onTap: () => DeviceConfigDialog.show(context, onConnected: _loadSystemSettings),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF613EEA).withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.settings_ethernet_rounded, color: Color(0xFF613EEA), size: 22),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Konfigurasi IP & WiFi Gelang',
                                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF1E293B)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'IP ESP32 Aktif: $_espDeviceIp',
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                                ],
                              ),
                            ),
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 16, color: Color(0xFFE2E8F0)),

                          // Buka Pengaturan WiFi HP
                          InkWell(
                            onTap: () => SystemSettingsService.openWifiSettings(),
                            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                            child: const Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Icon(Icons.wifi_rounded, color: Color(0xFF64748B), size: 20),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      'Buka Pengaturan WiFi Smartphone',
                                      style: TextStyle(fontSize: 13, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Icon(Icons.open_in_new_rounded, color: Color(0xFF94A3B8), size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Version Info
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'GlucoBand Mobile App v${AppConstants.currentVersion}',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Sistem Pemantauan Non-Invasif Berbasis NIR & IoT',
                            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF613EEA)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
