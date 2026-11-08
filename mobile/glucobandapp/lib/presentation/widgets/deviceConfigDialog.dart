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
  bool _showWifiSection = false;
  bool _isScanningWifi = false;
  List<Map<String, dynamic>> _scannedNetworks = [];
  Map<String, dynamic>? _selectedNetwork;
  bool _manualSsidInput = false;
  bool _obscurePassword = true;
  bool _isConnectingRouter = false;
  bool _isAutoDiscovering = false;

  // State Transisi Koneksi Otomatis (Saat beralih ke WiFi Rumah/Kantor)
  int _connectionStep = 0; // 0: Normal, 1: ESP Terhubung Menunggu HP, 2: Keduanya Terhubung
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
      _statusMessage = 'Menghubungi ESP32 di ${_ipController.text}...';
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
      final int rssi = (status['rssi'] is num) ? (status['rssi'] as num).toInt() : 0;

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _sensorStatus = init['sensors'];

        _isEspWifiConnected = isConnectedToRouter && currentSsid != null && currentSsid.isNotEmpty;
        _connectedRouterSsid = _isEspWifiConnected ? currentSsid : null;
        _connectedRouterIp = _isEspWifiConnected ? currentIp : null;
        _connectedRouterRssi = _isEspWifiConnected ? rssi : null;

        final displaySsid = _isEspWifiConnected
            ? currentSsid
            : (status['ap_ssid'] ?? 'GlucoBand-Setup');
        _statusMessage = 'Terhubung ke $displaySsid ($currentIp)';
      });

      widget.onDeviceConnected?.call();
    } catch (e) {
      if (!mounted) return;

      if (autoDiscoverOnFail) {
        // Coba auto-discovery otomatis di subnet lokal
        _autoDiscoverEsp();
      } else {
        setState(() {
          _isLoading = false;
          _isSuccess = false;
          _statusMessage = 'Gagal terhubung ke ${_ipController.text}.\nTekan "Cari Otomatis" untuk mendeteksi ESP32 di jaringan Anda.';
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
      _statusMessage = 'Mencari GlucoBand di jaringan WiFi & Hotspot...';
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
          _statusMessage = 'GlucoBand belum ditemukan di jaringan ini.\nPastikan smartphone terhubung ke WiFi "GlucoBand-Setup" atau WiFi yang sama.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAutoDiscovering = false;
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Pencarian otomatis selesai tanpa hasil. Silakan periksa koneksi WiFi.';
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
        const SnackBar(content: Text('Pilih atau masukkan nama WiFi (SSID)')),
      );
      return;
    }

    if (isSecure && password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan kata sandi WiFi untuk jaringan ini')),
      );
      return;
    }

    setState(() {
      _isConnectingRouter = true;
      _isLoading = true;
      _statusMessage = 'Mengirim kredensial ke GlucoBand...\nMenghubungkan ke "$targetSsid".';
      _isSuccess = true;
      _connectionStep = 0;
    });

    try {
      final result = await EspService.configureWifi(targetSsid, password);

      if (!mounted) return;

      if (!result.success && !result.wifiConnected) {
        throw Exception(result.message);
      }

      final String newIp = (result.newIp != null && result.newIp!.isNotEmpty && result.newIp != '192.168.4.1')
          ? result.newIp!
          : (await EspService.waitForConnectionAndGetNewIp(expectedSsid: targetSsid) ?? '');

      if (!mounted) return;

      setState(() {
        _isConnectingRouter = false;
        _isLoading = false;
        _transitionSsid = targetSsid;
        _transitionIp = newIp.isNotEmpty ? newIp : _ipController.text;
        _connectionStep = 1; // Langkah 1: ESP32 Sukses, Menunggu HP
        _statusMessage = 'GlucoBand sukses terhubung ke "$targetSsid"! (IP: $_transitionIp)\nSekarang hubungkan HP ke WiFi "$targetSsid" yang sama.';
      });

      if (newIp.isNotEmpty) {
        _ipController.text = newIp;
        await EspService.saveDeviceIp(newIp);
      }

      // Mulai verifikasi berkala di latar belakang: jika HP sudah di jaringan yang sama, otomatis terdeteksi!
      _startVerificationPoller(newIp.isNotEmpty ? newIp : null);

      // Otomatis buka dialog pengaturan WiFi smartphone agar pengguna langsung memilih router tanpa repot
      await Future.delayed(const Duration(milliseconds: 500));
      EspService.openSystemWifiSettings();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isConnectingRouter = false;
        _isLoading = false;
        _isSuccess = false;
        _connectionStep = 0;
        _statusMessage = 'Gagal menghubungkan ke WiFi: ${e.toString()}';
      });
    }
  }

  /// Poller verifikasi otomatis saat smartphone beralih ke WiFi yang sama
  void _startVerificationPoller(String? targetIp) {
    _verificationTimer?.cancel();
    int attempts = 0;

    _verificationTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      attempts++;
      if (attempts > 30) {
        timer.cancel();
        return;
      }

      final checkIp = targetIp ?? _ipController.text;
      try {
        final status = await EspService.checkStatus(timeout: const Duration(milliseconds: 1000));
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
            _statusMessage = 'Sempurna! Smartphone & GlucoBand kini tersambung di WiFi "$_connectedRouterSsid" ($currentIp)';
          });

          widget.onDeviceConnected?.call();
          _scanNearbyWifi();
        }
      } catch (_) {
        // Coba subnet scan jika targetIp berganti
        if (attempts % 4 == 0) {
          final discovered = await EspService.discoverDeviceIp(probeTimeout: const Duration(milliseconds: 250));
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
        title: const Text('Putuskan Koneksi WiFi?'),
        content: const Text(
          'ESP32 akan memutuskan koneksi dari router dan kembali ke mode Access Point murni (GlucoBand-Setup di 192.168.4.1).',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Putuskan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Memutuskan koneksi WiFi pada ESP32...';
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
        _statusMessage = 'Koneksi WiFi diputus. ESP32 kembali ke mode AP (192.168.4.1).';
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
      return const Icon(Icons.wifi, color: Color(0xFF10B981), size: 20);
    } else if (rssi >= -78) {
      return const Icon(Icons.wifi_2_bar, color: Color(0xFFF59E0B), size: 20);
    } else {
      return const Icon(Icons.wifi_1_bar, color: Colors.grey, size: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSelectedSecure = _selectedNetwork != null
        ? (_selectedNetwork!['is_secure'] == true)
        : true;
    final bool isSelectedAlreadyConnected = _selectedNetwork != null &&
        _isEspWifiConnected &&
        _selectedNetwork!['ssid'] == _connectedRouterSsid;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.wifi_tethering, color: Color(0xFF5A3FE0), size: 26),
                const SizedBox(width: 10),
                const Text(
                  'Koneksi Perangkat GlucoBand',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // CARD WIDGET STEP TRANSISI OTOMATIS (Jika baru saja menghubungkan ke WiFi)
            if (_connectionStep == 1) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFEEF2FF), Color(0xFFE0E7FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Otomatisasi Sambungan WiFi',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF3730A3)),
                    ),
                    const SizedBox(height: 6),
                    // Step 1
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 15),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '1. GlucoBand terhubung ke "$_transitionSsid" (IP: $_transitionIp)',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Step 2
                    Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF4F46E5)),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '2. Sambungkan WiFi HP Anda ke "$_transitionSsid"',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: ElevatedButton.icon(
                              onPressed: () => EspService.openSystemWifiSettings(),
                              icon: const Icon(Icons.wifi, size: 15),
                              label: const Text(
                                'Buka Pengaturan',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4F46E5),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 34,
                          child: OutlinedButton(
                            onPressed: () => _testConnection(autoDiscoverOnFail: true),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF4F46E5)),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Cek Sekarang', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],

            // Status Banner Utama
            if (_statusMessage != null && _connectionStep != 1)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSuccess ? Colors.green.shade200 : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _isSuccess ? Colors.green.shade700 : Colors.red.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Input Alamat IP ESP32 (Satu baris rapi & hemat ruang)
            const Text(
              'Alamat IP ESP32 Aktif',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _ipController,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: '192.168.4.1',
                      prefixIcon: const Icon(Icons.settings_ethernet, size: 20),
                      suffixIcon: _isAutoDiscovering
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF5A3FE0)),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.radar, size: 18, color: Color(0xFF5A3FE0)),
                              tooltip: 'Pindai IP ESP32 Otomatis',
                              onPressed: _isLoading ? null : _autoDiscoverEsp,
                            ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _isLoading ? null : () => _testConnection(autoDiscoverOnFail: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A3FE0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading && !_isConnectingRouter && !_isAutoDiscovering
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Tes IP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Default AP: 192.168.4.1',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
                InkWell(
                  onTap: _isLoading ? null : _autoDiscoverEsp,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.radar, size: 12, color: Color(0xFF5A3FE0)),
                      SizedBox(width: 4),
                      Text(
                        'Pindai IP Otomatis',
                        style: TextStyle(fontSize: 11, color: Color(0xFF5A3FE0), fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Tampilan Status Sensor Hardware
            if (_sensorStatus != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Inisiasi Hardware Sensor',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    _sensorRow('Sensor PPG (MAX30105)', _sensorStatus!['max30105'] == true),
                    const Divider(height: 12),
                    _sensorRow('Sensor Suhu (MLX90614)', _sensorStatus!['mlx90614'] == true),
                    const Divider(height: 12),
                    _sensorRow('Sensor NIR (AS726X)', _sensorStatus!['as726x'] == true),
                    const Divider(height: 12),
                    _sensorRow('Layar OLED (SSD1306)', _sensorStatus!['oled'] == true),
                  ],
                ),
              ),
            ],

            // Section Hubungkan ke WiFi Rumah / Kantor
            const SizedBox(height: 18),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      setState(() => _showWifiSection = !_showWifiSection);
                      if (_showWifiSection && _scannedNetworks.isEmpty) {
                        _scanNearbyWifi();
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.wifi_find, color: Color(0xFF5A3FE0), size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Hubungkan ke WiFi Rumah / Kantor',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                        Icon(
                          _showWifiSection ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: const Color(0xFF5A3FE0),
                        ),
                      ],
                    ),
                  ),

                  if (_showWifiSection) ...[
                    const SizedBox(height: 14),

                    // INDIKATOR STATUS WIFI SAAT INI
                    if (_isEspWifiConnected && _connectedRouterSsid != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.wifi, color: Color(0xFF059669), size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Status: ',
                                        style: TextStyle(fontSize: 11, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Text(
                                          'Telah Terhubung',
                                          style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _connectedRouterSsid!,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                  ),
                                  Text(
                                    'IP: ${_connectedRouterIp ?? _ipController.text}${_connectedRouterRssi != null ? " • Sinyal: $_connectedRouterRssi dBm" : ""}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF047857)),
                                  ),
                                ],
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isLoading ? null : _resetWifiConnection,
                              icon: const Icon(Icons.link_off, size: 14, color: Color(0xFFDC2626)),
                              label: const Text(
                                'Putuskan',
                                style: TextStyle(fontSize: 11, color: Color(0xFFDC2626), fontWeight: FontWeight.bold),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ] else ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.amber.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.wifi_off, color: Colors.amber.shade800, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Belum terhubung ke WiFi router. GlucoBand memancarkan hotspot "GlucoBand-Setup" di 192.168.4.1.',
                                style: TextStyle(fontSize: 11, color: Colors.amber.shade900, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // HEADER DETEKSI WIFI
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'JARINGAN WIFI DI SEKITAR',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        InkWell(
                          onTap: _isScanningWifi ? null : _scanNearbyWifi,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            child: Row(
                              children: [
                                if (_isScanningWifi)
                                  const SizedBox(
                                    width: 12,
                                    height: 12,
                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Color(0xFF5A3FE0)),
                                  )
                                else
                                  const Icon(Icons.refresh, size: 14, color: Color(0xFF5A3FE0)),
                                const SizedBox(width: 4),
                                Text(
                                  _isScanningWifi ? 'Memindai...' : 'Pindai Ulang',
                                  style: const TextStyle(
                                    fontSize: 11,
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
                    const SizedBox(height: 8),

                    // DAFTAR JARINGAN WIFI TERDETEKSI
                    if (_isScanningWifi && _scannedNetworks.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            CircularProgressIndicator(color: const Color(0xFF5A3FE0)),
                            const SizedBox(height: 10),
                            const Text(
                              'Mendeteksi WiFi di sekitar GlucoBand...',
                              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    else if (_scannedNetworks.isNotEmpty) ...[
                      Container(
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _scannedNetworks.length,
                          separatorBuilder: (_, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final net = _scannedNetworks[index];
                            final String ssid = net['ssid'] ?? '';
                            final bool isSecure = net['is_secure'] == true;
                            final int rssi = net['rssi'] ?? -100;
                            final bool isCurrentlyConnected = _isEspWifiConnected && ssid == _connectedRouterSsid;
                            final bool isSelected = _selectedNetwork != null && _selectedNetwork!['ssid'] == ssid;

                            return Container(
                              color: isCurrentlyConnected
                                  ? const Color(0xFFF0FDF4)
                                  : (isSelected ? const Color(0xFFF5F3FF) : Colors.transparent),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                leading: _buildSignalIcon(rssi),
                                title: Text(
                                  ssid,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: (isCurrentlyConnected || isSelected)
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isCurrentlyConnected
                                        ? const Color(0xFF047857)
                                        : (isSelected ? const Color(0xFF5A3FE0) : Colors.black87),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isCurrentlyConnected)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(Icons.check, size: 12, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'Terhubung',
                                              style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      )
                                    else ...[
                                      if (isSecure)
                                        const Icon(Icons.lock, size: 14, color: Colors.grey)
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Terbuka',
                                            style: TextStyle(fontSize: 10, color: Colors.green.shade700, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      const SizedBox(width: 6),
                                      if (isSelected)
                                        const Icon(Icons.radio_button_checked, color: Color(0xFF5A3FE0), size: 18)
                                      else
                                        const Icon(Icons.radio_button_off, color: Colors.grey, size: 18),
                                    ],
                                  ],
                                ),
                                onTap: () => _onSelectNetwork(net),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 6),
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
                            _manualSsidInput ? 'Kembali ke daftar WiFi' : 'Ketik SSID manual (WiFi tersembunyi)',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF5A3FE0), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ] else ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: Text(
                          'Klik "Pindai Ulang" untuk mendeteksi WiFi.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ),
                    ],

                    // Input Manual SSID jika dipilih
                    if (_manualSsidInput) ...[
                      const SizedBox(height: 10),
                      TextField(
                        controller: _ssidController,
                        decoration: InputDecoration(
                          labelText: 'Nama WiFi (SSID)',
                          prefixIcon: const Icon(Icons.wifi, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],

                    // FORM KATA SANDI KONDISIONAL
                    if (_selectedNetwork != null && isSelectedAlreadyConnected) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'GlucoBand saat ini sudah aktif tersambung ke jaringan ini.',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_selectedNetwork != null && !isSelectedSecure) ...[
                      // Jaringan Terbuka (Tanpa Kata Sandi)
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.lock_open, color: Colors.green.shade700, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Jaringan "${_ssidController.text}" bersifat terbuka (Tanpa Kata Sandi).',
                                style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (_selectedNetwork != null || _manualSsidInput) ...[
                      // Jaringan Berkata Sandi
                      const SizedBox(height: 10),
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: _selectedNetwork != null
                              ? 'Password WiFi untuk "${_ssidController.text}"'
                              : 'Password WiFi',
                          prefixIcon: const Icon(Icons.lock_outline, size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              size: 18,
                              color: Colors.grey,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],

                    // TOMBOL AKSI HUBUNGKAN / BERALIH
                    if (!isSelectedAlreadyConnected) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: (_isLoading || _isConnectingRouter) ? null : _connectToWifiRouter,
                          icon: _isConnectingRouter
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.link, size: 18),
                          label: Text(
                            _isConnectingRouter
                                ? 'Menghubungkan ke Router...'
                                : (_isEspWifiConnected
                                    ? 'Beralih ke "${_ssidController.text}"'
                                    : (_selectedNetwork != null
                                        ? 'Hubungkan ke "${_ssidController.text}"'
                                        : 'Hubungkan WiFi')),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5A3FE0),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
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
          child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
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
