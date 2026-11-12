import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/espService.dart';

class DeviceConfigDialog extends StatefulWidget {
  final VoidCallback? onDeviceConnected;

  const DeviceConfigDialog({super.key, this.onDeviceConnected});

  static Future<void> show(BuildContext context, {VoidCallback? onConnected}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeviceConfigDialog(onDeviceConnected: onConnected),
    );
  }

  @override
  State<DeviceConfigDialog> createState() => _DeviceConfigDialogState();
}

class _DeviceConfigDialogState extends State<DeviceConfigDialog> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;
  Map<String, dynamic>? _sensorStatus;

  // Status Jaringan WiFi Router Saat Ini
  bool _isEspWifiConnected = false;
  String? _connectedRouterSsid;
  String? _connectedRouterIp;
  int? _connectedRouterRssi;

  // Manajemen WiFi Scanner
  bool _isScanningWifi = false;
  List<Map<String, dynamic>> _scannedNetworks = [];
  Map<String, dynamic>? _selectedNetwork;
  bool _manualSsidInput = false;
  bool _obscurePassword = true;
  bool _isConnectingRouter = false;
  bool _isAutoDiscovering = false;

  // Pengaturan Lanjutan (Collapsible untuk IP Manual & Diagnosa Sensor)
  bool _showAdvancedSettings = false;

  // State Transisi Koneksi Otomatis (Saat beralih ke WiFi Rumah/Kantor)
  int _connectionStep =
      0; // 0: Normal, 1: ESP Terhubung Menunggu HP, 2: Keduanya Terhubung
  String? _transitionSsid;
  String? _transitionIp;
  Timer? _verificationTimer;

  @override
  void initState() {
    super.initState();
    _loadCurrentIpAndTest();
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    _ipController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentIpAndTest() async {
    final ip = await EspService.getDeviceIp();
    if (!mounted) return;
    setState(() {
      _ipController.text = ip;
    });
    _testConnection(autoDiscoverOnFail: true);
  }

  /// Menghubungkan dan Menguji IP aktif (dengan auto-fallback dan auto-discover)
  Future<void> _testConnection({bool autoDiscoverOnFail = false}) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Menghubungkan ke GlucoBand...';
      _isSuccess = false;
      _sensorStatus = null;
    });

    try {
      await EspService.saveDeviceIp(_ipController.text);
      final status = await EspService.checkStatus();
      final init = await EspService.initDevice();

      if (!mounted) return;

      final bool isConnectedToRouter = status['wifi_connected'] == true;
      final String? currentSsid = status['ssid']?.toString();
      final String currentIp = status['ip'] ?? _ipController.text;
      final int rssi = (status['rssi'] is num)
          ? (status['rssi'] as num).toInt()
          : 0;

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _sensorStatus = init['sensors'];

        _isEspWifiConnected =
            isConnectedToRouter &&
            currentSsid != null &&
            currentSsid.isNotEmpty;
        _connectedRouterSsid = _isEspWifiConnected ? currentSsid : null;
        _connectedRouterIp = _isEspWifiConnected ? currentIp : null;
        _connectedRouterRssi = _isEspWifiConnected ? rssi : null;

        final displaySsid = _isEspWifiConnected
            ? currentSsid
            : (status['ap_ssid'] ?? 'GlucoBand-Setup');
        _statusMessage = 'Terhubung ke $displaySsid';
      });

      widget.onDeviceConnected?.call();

      // Otomatis pindai WiFi di sekitar agar pengguna awam langsung melihat daftar WiFi
      if (_scannedNetworks.isEmpty && !_isScanningWifi) {
        _scanNearbyWifi();
      }
    } catch (e) {
      if (!mounted) return;

      if (autoDiscoverOnFail) {
        // Coba auto-discovery otomatis di subnet lokal
        _autoDiscoverEsp();
      } else {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _statusMessage =
              'GlucoBand belum terdeteksi di ${_ipController.text}.';
        });
      }
    }
  }

  /// Auto-discovery memindai subnet HP & mDNS untuk menemukan IP ESP32 secara instan
  Future<void> _autoDiscoverEsp() async {
    if (_isAutoDiscovering) return;

    setState(() {
      _isAutoDiscovering = true;
      _isLoading = true;
      _statusMessage = 'Mencari GlucoBand di sekitar...';
      _isSuccess = false;
    });

    try {
      final foundIp = await EspService.discoverDeviceIp(
        onProgress: (msg) {
          if (mounted) setState(() => _statusMessage = msg);
        },
      );

      if (!mounted) return;

      if (foundIp != null && foundIp.isNotEmpty) {
        setState(() {
          _ipController.text = foundIp;
          _isAutoDiscovering = false;
        });

        // Verifikasi IP yang ditemukan
        await _testConnection(autoDiscoverOnFail: false);
      } else {
        setState(() {
          _isAutoDiscovering = false;
          _isLoading = false;
          _isSuccess = false;
          _statusMessage =
              'GlucoBand belum ditemukan.\nPastikan HP terhubung ke WiFi "GlucoBand-Setup".';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAutoDiscovering = false;
        _isLoading = false;
        _isSuccess = false;
        _statusMessage =
            'Pencarian selesai tanpa hasil. Silakan periksa koneksi WiFi HP Anda.';
      });
    }
  }

  /// Memindai jaringan WiFi di sekitar ESP32
  Future<void> _scanNearbyWifi() async {
    if (_isScanningWifi) return;

    setState(() {
      _isScanningWifi = true;
    });

    try {
      final networks = await EspService.scanWifiNetworks();
      if (!mounted) return;

      setState(() {
        _isScanningWifi = false;
        _scannedNetworks = networks;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanningWifi = false;
      });
    }
  }

  void _onSelectNetwork(Map<String, dynamic> network) {
    setState(() {
      _selectedNetwork = network;
      _ssidController.text = network['ssid'] ?? '';
      _manualSsidInput = false;
      if (network['is_secure'] == false) {
        _passwordController.clear();
      }
    });
  }

  /// Menghubungkan ESP32 ke WiFi Router dan memandu otomatisasi koneksi HP
  Future<void> _connectToWifiRouter() async {
    final String targetSsid = _ssidController.text.trim();
    final bool isSecure = _selectedNetwork != null
        ? (_selectedNetwork!['is_secure'] == true)
        : true;
    final String password = _passwordController.text.trim();

    if (targetSsid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih nama WiFi terlebih dahulu'),
        ),
      );
      return;
    }

    if (isSecure && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan kata sandi WiFi untuk melanjutkan'),
        ),
      );
      return;
    }

    setState(() {
      _isConnectingRouter = true;
      _isLoading = true;
      _statusMessage = 'Menghubungkan gelang ke "$targetSsid"...';
      _isSuccess = true;
      _connectionStep = 0;
    });

    try {
      final result = await EspService.configureWifi(targetSsid, password);

      if (!mounted) return;

      if (!result.success && !result.wifiConnected) {
        throw Exception(result.message);
      }

      final String newIp =
          (result.newIp != null &&
              result.newIp!.isNotEmpty &&
              result.newIp != '192.168.4.1')
          ? result.newIp!
          : (await EspService.waitForConnectionAndGetNewIp(
                  expectedSsid: targetSsid,
                ) ??
                '');

      if (!mounted) return;

      setState(() {
        _isConnectingRouter = false;
        _isLoading = false;
        _transitionSsid = targetSsid;
        _transitionIp = newIp.isNotEmpty ? newIp : _ipController.text;
        _connectionStep = 1; // Langkah 1: ESP32 Sukses, Menunggu HP
        _statusMessage = 'Gelang sukses terhubung ke "$targetSsid"!';
      });

      if (newIp.isNotEmpty) {
        _ipController.text = newIp;
        await EspService.saveDeviceIp(newIp);
      }

      // Mulai verifikasi berkala di latar belakang: jika HP sudah di jaringan yang sama, otomatis terdeteksi!
      _startVerificationPoller(newIp.isNotEmpty ? newIp : null);

      // Otomatis buka pengaturan WiFi smartphone agar pengguna langsung memilih WiFi yang sama
      await Future.delayed(const Duration(milliseconds: 500));
      EspService.openSystemWifiSettings();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnectingRouter = false;
        _isLoading = false;
        _isSuccess = false;
        _connectionStep = 0;
        _statusMessage = 'Gagal menghubungkan gelang ke WiFi: ${e.toString()}';
      });
    }
  }

  /// Poller verifikasi otomatis saat smartphone beralih ke WiFi yang sama
  void _startVerificationPoller(String? targetIp) {
    _verificationTimer?.cancel();
    int attempts = 0;

    _verificationTimer = Timer.periodic(const Duration(milliseconds: 1500), (
      timer,
    ) async {
      attempts++;
      if (attempts > 30) {
        timer.cancel();
        return;
      }

      final checkIp = targetIp ?? _ipController.text;
      try {
        final status = await EspService.checkStatus(
          timeout: const Duration(milliseconds: 1000),
        );
        final init = await EspService.initDevice();

        if (status['wifi_connected'] == true) {
          timer.cancel();
          if (!mounted) return;

          final currentIp = status['ip'] ?? checkIp;
          setState(() {
            _connectionStep = 2; // Langkah 2: Lengkap & Terhubung Sempurna!
            _isEspWifiConnected = true;
            _connectedRouterSsid = status['ssid'] ?? _transitionSsid;
            _connectedRouterIp = currentIp;
            _ipController.text = currentIp;
            _sensorStatus = init['sensors'];
            _isSuccess = true;
            _statusMessage =
                'Sempurna! HP dan Gelang sudah terhubung di WiFi "$_connectedRouterSsid"';
          });

          widget.onDeviceConnected?.call();
          _scanNearbyWifi();
        }
      } catch (_) {
        if (attempts % 4 == 0) {
          final discovered = await EspService.discoverDeviceIp(
            probeTimeout: const Duration(milliseconds: 250),
          );
          if (discovered != null && mounted) {
            _ipController.text = discovered;
          }
        }
      }
    });
  }

  Future<void> _resetWifiConnection() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Putuskan Koneksi WiFi?',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: const Text(
          'Gelang GlucoBand akan memutuskan koneksi dari router dan kembali ke mode awal (GlucoBand-Setup).',
          style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Memutuskan koneksi WiFi pada gelang...';
      _connectionStep = 0;
    });

    try {
      await EspService.resetWifi();
      await EspService.saveDeviceIp('192.168.4.1');
      if (!mounted) return;

      setState(() {
        _ipController.text = '192.168.4.1';
        _isEspWifiConnected = false;
        _connectedRouterSsid = null;
        _connectedRouterIp = null;
        _isLoading = false;
        _isSuccess = true;
        _selectedNetwork = null;
        _statusMessage = 'WiFi berhasil diputus. Gelang kembali ke mode awal.';
      });

      widget.onDeviceConnected?.call();
      _scanNearbyWifi();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _statusMessage = 'Gagal memutuskan WiFi: ${e.toString()}';
        _isSuccess = false;
      });
    }
  }

  Widget _buildSignalIcon(int rssi) {
    if (rssi >= -65) {
      return const Icon(Icons.wifi, color: Color(0xFF10B981), size: 22);
    } else if (rssi >= -78) {
      return const Icon(Icons.wifi_2_bar, color: Color(0xFFF59E0B), size: 22);
    } else {
      return const Icon(Icons.wifi_1_bar, color: Color(0xFF94A3B8), size: 22);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelectedSecure = _selectedNetwork != null
        ? (_selectedNetwork!['is_secure'] == true)
        : true;
    final bool isSelectedAlreadyConnected =
        _selectedNetwork != null &&
        _isEspWifiConnected &&
        _selectedNetwork!['ssid'] == _connectedRouterSsid;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar & Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 10),
              child: Column(
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF5A3FE0).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.wifi_tethering,
                          color: Color(0xFF5A3FE0),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sambungkan GlucoBand',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Hubungkan gelang ke WiFi rumah Anda',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.grey),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            // Konten Dialog (Scrollable)
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ==========================================
                    // 1. KARTU STATUS PERANGKAT (Friendly UX)
                    // ==========================================
                    _buildDeviceStatusBanner(),

                    const SizedBox(height: 14),

                    // ==========================================
                    // 2. KARTU PANDUAN LANGKAH TRANSISI (Step 1 & 2)
                    // ==========================================
                    if (_connectionStep == 1) ...[
                      _buildTransitionGuideCard(),
                      const SizedBox(height: 16),
                    ],

                    // ==========================================
                    // 3. BAGIAN UTAMA: PILIH JARINGAN WIFI
                    // ==========================================
                    if (_connectionStep != 1) ...[
                      _buildWifiSelectionSection(
                        isSelectedSecure: isSelectedSecure,
                        isSelectedAlreadyConnected: isSelectedAlreadyConnected,
                      ),
                    ],

                    const SizedBox(height: 16),

                    // ==========================================
                    // 4. PENGATURAN LANJUTAN (IP ESP & DIAGNOSA)
                    // ==========================================
                    _buildAdvancedSettingsSection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Banner status ramah untuk pengguna awam & lansia
  Widget _buildDeviceStatusBanner() {
    if (_isLoading && !_isConnectingRouter) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F3FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFDDD6FE)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Color(0xFF5A3FE0),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Menghubungkan ke GlucoBand...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5A3FE0),
                    ),
                  ),
                  if (_statusMessage != null)
                    Text(
                      _statusMessage!,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (!_isSuccess) {
      // Perangkat Belum Terdeteksi
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(
                  Icons.wifi_off_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
                SizedBox(width: 8),
                Text(
                  'Gelang Belum Terdeteksi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Untuk menghubungkan pertama kali:\n1. Pastikan gelang GlucoBand sudah menyala.\n2. Buka menu WiFi di HP Anda, lalu pilih WiFi bernama "GlucoBand-Setup".',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => EspService.openSystemWifiSettings(),
                    icon: const Icon(Icons.wifi, size: 16),
                    label: const Text(
                      'Buka Pengaturan WiFi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD97706),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _testConnection(autoDiscoverOnFail: true),
                  icon: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Color(0xFFB45309),
                  ),
                  label: const Text(
                    'Cari Lagi',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: Color(0xFFB45309),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFDE68A)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Perangkat Terhubung
    if (_isEspWifiConnected && _connectedRouterSsid != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFA7F3D0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFF10B981),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Gelang Terhubung ke WiFi',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const Spacer(),
                      if (_connectedRouterRssi != null)
                        _buildSignalIcon(_connectedRouterRssi!),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _connectedRouterSsid!,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Siap digunakan untuk memantau gula darah Anda.',
                    style: TextStyle(fontSize: 11.5, color: Color(0xFF059669)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Terhubung via Hotspot Setup Langsung
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.sensors,
              color: Color(0xFF2563EB),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gelang Siap Dihubungkan',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E40AF),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Pilih WiFi rumah Anda di bawah agar gelang dapat terhubung.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tampilan panduan transisi saat beralih ke WiFi rumah
  Widget _buildTransitionGuideCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFC7D2FE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sync_rounded, color: Color(0xFF4338CA), size: 20),
              SizedBox(width: 8),
              Text(
                'Langkah Terakhir: Hubungkan HP Anda',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF3730A3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Langkah 1
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF10B981),
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '1. Gelang GlucoBand sudah tersambung ke "$_transitionSsid"',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Langkah 2
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '2. Sekarang sambungkan WiFi HP Anda ke "$_transitionSsid" yang sama.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => EspService.openSystemWifiSettings(),
                  icon: const Icon(Icons.wifi, size: 16),
                  label: const Text(
                    'Buka Pengaturan WiFi HP',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _testConnection(autoDiscoverOnFail: true),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Cek Sambungan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4F46E5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Bagian Utama: Memilih WiFi langsung layaknya pengaturan WiFi biasa
  Widget _buildWifiSelectionSection({
    required bool isSelectedSecure,
    required bool isSelectedAlreadyConnected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section WiFi
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Row(
              children: [
                Icon(Icons.wifi, color: Color(0xFF5A3FE0), size: 20),
                SizedBox(width: 8),
                Text(
                  'Pilih WiFi Rumah / Kantor',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: _isScanningWifi ? null : _scanNearbyWifi,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (_isScanningWifi)
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          color: Color(0xFF5A3FE0),
                        ),
                      )
                    else
                      const Icon(
                        Icons.refresh,
                        size: 16,
                        color: Color(0xFF5A3FE0),
                      ),
                    const SizedBox(width: 4),
                    Text(
                      _isScanningWifi ? 'Mencari...' : 'Pindai Ulang',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF5A3FE0),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _isEspWifiConnected
              ? 'Pilih jaringan di bawah ini jika ingin mengganti koneksi WiFi gelang:'
              : 'Pilih nama WiFi Anda dari daftar di bawah ini:',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 10),

        // DAFTAR JARINGAN WIFI
        if (_isScanningWifi && _scannedNetworks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: const [
                CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Color(0xFF5A3FE0),
                ),
                SizedBox(height: 12),
                Text(
                  'Mencari sinyal WiFi di sekitar gelang...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        else if (_scannedNetworks.isNotEmpty) ...[
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _scannedNetworks.length,
              separatorBuilder: (_, index) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, index) {
                final net = _scannedNetworks[index];
                final String ssid = net['ssid'] ?? '';
                final bool isSecure = net['is_secure'] == true;
                final int rssi = net['rssi'] ?? -100;
                final bool isCurrentlyConnected =
                    _isEspWifiConnected && ssid == _connectedRouterSsid;
                final bool isSelected =
                    _selectedNetwork != null &&
                    _selectedNetwork!['ssid'] == ssid;

                return InkWell(
                  onTap: () => _onSelectNetwork(net),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: isCurrentlyConnected
                          ? const Color(0xFFECFDF5)
                          : (isSelected
                                ? const Color(0xFFF5F3FF)
                                : Colors.transparent),
                    ),
                    child: Row(
                      children: [
                        _buildSignalIcon(rssi),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ssid,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: (isCurrentlyConnected || isSelected)
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isCurrentlyConnected
                                  ? const Color(0xFF065F46)
                                  : (isSelected
                                        ? const Color(0xFF5A3FE0)
                                        : const Color(0xFF1E293B)),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentlyConnected) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Terhubung',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          if (isSecure)
                            const Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: Color(0xFF94A3B8),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Terbuka',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          const SizedBox(width: 8),
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: isSelected
                                ? const Color(0xFF5A3FE0)
                                : const Color(0xFFCBD5E1),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                setState(() {
                  _manualSsidInput = !_manualSsidInput;
                  if (_manualSsidInput) {
                    _selectedNetwork = null;
                    _ssidController.clear();
                  }
                });
              },
              child: Text(
                _manualSsidInput
                    ? 'Kembali ke daftar WiFi'
                    : 'WiFi tidak muncul? Ketik manual',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5A3FE0),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const Text(
                  'Belum ada WiFi yang terdeteksi.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 6),
                TextButton.icon(
                  onPressed: _scanNearbyWifi,
                  icon: const Icon(
                    Icons.refresh,
                    size: 16,
                    color: Color(0xFF5A3FE0),
                  ),
                  label: const Text(
                    'Pindai Ulang WiFi',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF5A3FE0),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Input Manual SSID jika dipilih
        if (_manualSsidInput) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _ssidController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Nama WiFi (SSID)',
              labelStyle: const TextStyle(fontSize: 13),
              hintText: 'Misal: WiFi_Rumah',
              prefixIcon: const Icon(Icons.wifi, size: 20),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],

        // FORM KATA SANDI DAN TOMBOL HUBUNGKAN
        if (_selectedNetwork != null || _manualSsidInput) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF5A3FE0),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'WiFi Terpilih: ${_ssidController.text}',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedNetwork = null;
                          _manualSsidInput = false;
                          _ssidController.clear();
                          _passwordController.clear();
                        });
                      },
                      child: const Text(
                        'Ganti',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF5A3FE0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),

                if (isSelectedAlreadyConnected) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Color(0xFF10B981),
                          size: 16,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gelang sudah tersambung aktif ke jaringan ini.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!isSelectedSecure && !_manualSsidInput) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Text(
                      'Jaringan "${_ssidController.text}" bersifat terbuka (Tanpa kata sandi).',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade900,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _isConnectingRouter)
                          ? null
                          : _connectToWifiRouter,
                      icon: _isConnectingRouter
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.link, size: 20),
                      label: Text(
                        _isConnectingRouter
                            ? 'Menghubungkan...'
                            : 'Sambungkan ke "${_ssidController.text}"',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A3FE0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi WiFi',
                      labelStyle: const TextStyle(fontSize: 13),
                      hintText: 'Masukkan kata sandi...',
                      prefixIcon: const Icon(Icons.lock_outline, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          size: 20,
                          color: const Color(0xFF64748B),
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: (_isLoading || _isConnectingRouter)
                          ? null
                          : _connectToWifiRouter,
                      icon: _isConnectingRouter
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.link, size: 20),
                      label: Text(
                        _isConnectingRouter
                            ? 'Menghubungkan...'
                            : 'Sambungkan ke "${_ssidController.text}"',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A3FE0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Bagian Pengaturan Lanjutan (IP Manual & Sensor Hardware)
  Widget _buildAdvancedSettingsSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              setState(() {
                _showAdvancedSettings = !_showAdvancedSettings;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.tune,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengaturan Lanjutan',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _showAdvancedSettings
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (_showAdvancedSettings) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Penjelasan Singkat
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF2FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFC7D2FE)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Color(0xFF4338CA),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gunakan menu ini hanya jika ingin mengatur alamat IP ESP secara manual atau memeriksa sensor hardware.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF312E81),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Input IP ESP32 Manual
                  const Text(
                    'Alamat IP ESP32 Aktif',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ipController,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(fontSize: 13.5),
                          decoration: InputDecoration(
                            hintText: '192.168.4.1',
                            prefixIcon: const Icon(
                              Icons.settings_ethernet,
                              size: 20,
                            ),
                            suffixIcon: _isAutoDiscovering
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFF5A3FE0),
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(
                                      Icons.radar,
                                      size: 18,
                                      color: Color(0xFF5A3FE0),
                                    ),
                                    tooltip: 'Pindai IP ESP32 Otomatis',
                                    onPressed: _isLoading
                                        ? null
                                        : _autoDiscoverEsp,
                                  ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _isLoading
                            ? null
                            : () => _testConnection(autoDiscoverOnFail: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A3FE0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child:
                            _isLoading &&
                                !_isConnectingRouter &&
                                !_isAutoDiscovering
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Tes IP',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Default Hotspot: 192.168.4.1',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      InkWell(
                        onTap: _isLoading ? null : _autoDiscoverEsp,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.radar,
                              size: 12,
                              color: Color(0xFF5A3FE0),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Pindai IP Otomatis',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF5A3FE0),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Status Sensor Hardware
                  if (_sensorStatus != null) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Status Sensor Hardware',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          _sensorRow(
                            'Sensor PPG (MAX30105)',
                            _sensorStatus!['max30105'] == true,
                          ),
                          const Divider(height: 12),
                          _sensorRow(
                            'Sensor Suhu (MLX90614)',
                            _sensorStatus!['mlx90614'] == true,
                          ),
                          const Divider(height: 12),
                          _sensorRow(
                            'Sensor NIR (AS726X)',
                            _sensorStatus!['as726x'] == true,
                          ),
                          const Divider(height: 12),
                          _sensorRow(
                            'Layar OLED (SSD1306)',
                            _sensorStatus!['oled'] == true,
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Tombol Putuskan WiFi jika sedang terhubung ke router
                  if (_isEspWifiConnected) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _resetWifiConnection,
                        icon: const Icon(
                          Icons.link_off,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                        label: const Text(
                          'Putuskan WiFi (Reset ke Hotspot AP)',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sensorRow(String name, bool isOk) {
    return Row(
      children: [
        Icon(
          isOk ? Icons.check_circle : Icons.cancel,
          color: isOk ? Colors.green : Colors.red,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          isOk ? 'AKTIF (OK)' : 'TIDAK TERDETEKSI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isOk ? Colors.green.shade700 : Colors.red.shade700,
          ),
        ),
      ],
    );
  }
}
