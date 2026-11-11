import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/authProvider.dart';
import '../providers/measurementProvider.dart';
import '../providers/notificationProvider.dart';
import '../providers/profileProvider.dart';
import '../providers/articleProvider.dart';
import 'notificationPage.dart';
import 'profilePage.dart';
import 'homePage.dart';
import 'predictionHistoryPage.dart';
import '../../services/espService.dart';
import '../widgets/deviceConfigDialog.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  bool _isDeviceConnected = false;
  String _deviceSsid = 'GlucoBand (ESP32)';
  String _deviceIp = '192.168.4.1';
  Timer? _deviceTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });

    // Cek status perangkat realtime tiap 3 detik
    _deviceTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) _checkDeviceStatus();
    });
  }

  @override
  void dispose() {
    _deviceTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkDeviceStatus() async {
    try {
      final status = await EspService.checkStatus();
      if (!mounted) return;
      setState(() {
        _isDeviceConnected = true;
        final ssid = status['ssid'] != null && status['ssid'].toString().isNotEmpty
            ? status['ssid']
            : status['ap_ssid'] ?? 'GlucoBand-Setup';
        _deviceSsid = '$ssid';
        _deviceIp = status['ip'] ?? _deviceIp;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDeviceConnected = false;
      });
    }
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final notifProvider = Provider.of<NotificationProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final articleProvider = Provider.of<ArticleProvider>(context, listen: false);
    final measurementProvider = Provider.of<MeasurementProvider>(context, listen: false);
    
    if (auth.token != null) {
      notifProvider.fetchNotifications(auth.token!);
      notifProvider.connectSocket(auth.token!);
      profileProvider.fetchProfile();
      articleProvider.fetchArticles();
      measurementProvider.fetchMeasurements();
    }
    _checkDeviceStatus();
  }

  Future<void> _onRefresh() async {
    await _loadData();
    await Future.delayed(const Duration(milliseconds: 800));
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final measurement = Provider.of<MeasurementProvider>(context);
    final notifProvider = Provider.of<NotificationProvider>(context);
    final articleProvider = Provider.of<ArticleProvider>(context);
    
    final currentDate = DateFormat('EEE, dd MMM yyyy').format(DateTime.now());
    final String firstName = auth.user?.name.split(' ').first ?? "Arrasyid";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Slightly lighter background to match image
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: const Color(0xFF613EEA),
        backgroundColor: Colors.white,
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(Icons.settings_outlined, color: Color(0xFF64748B)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/icons/android-chrome-192x192.png',
                          width: 26,
                          height: 26,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'GlucoBand',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF613EEA),
                          ),
                        ),
                      ],
                    ),
                    Stack(
                      children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.notifications_none, color: Color(0xFF613EEA)),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationListPage()),
                            );
                          },
                        ),
                        if (notifProvider.unreadCount > 0)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text(
                                  '${notifProvider.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hi, $firstName!',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  currentDate,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () {
                                final homeState = context.findAncestorStateOfType<HomePageState>();
                                if (homeState != null) {
                                  homeState.setIndex(4); // Pindah ke tab Profile (index 4)
                                } else {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                                  );
                                }
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.white,
                                  backgroundImage: null,
                                  child: auth.user?.name == null
                                      ? const Icon(Icons.person, size: 24, color: Colors.grey)
                                      : Text(
                                          auth.user!.name[0].toUpperCase(),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF613EEA),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Statistics
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Statistik',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            PopupMenuButton<String>(
                              initialValue: measurement.timeFilter,
                              tooltip: 'Pilih Rentang Waktu',
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              onSelected: (String value) {
                                measurement.setTimeFilter(value);
                              },
                              itemBuilder: (BuildContext context) => [
                                const PopupMenuItem<String>(
                                  value: '6 Jam',
                                  child: Row(
                                    children: [
                                      Icon(Icons.history_toggle_off, size: 18, color: Color(0xFF613EEA)),
                                      SizedBox(width: 8),
                                      Text('6 Jam Terakhir', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'Harian',
                                  child: Row(
                                    children: [
                                      Icon(Icons.today, size: 18, color: Color(0xFF613EEA)),
                                      SizedBox(width: 8),
                                      Text('Harian (24 Jam)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'Mingguan',
                                  child: Row(
                                    children: [
                                      Icon(Icons.date_range, size: 18, color: Color(0xFF613EEA)),
                                      SizedBox(width: 8),
                                      Text('Mingguan (7 Hari)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE2E8F0).withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      measurement.timeFilter,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF64748B)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatCard(
                                title: 'GLUCOSE AVG',
                                value: measurement.glucoseAvg > 0
                                    ? measurement.glucoseAvg.toStringAsFixed(0)
                                    : '--',
                                unit: ' mg/dL',
                                child: _buildMiniBarChart(measurement.miniBarHeights),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatCard(
                                title: 'BPM AVG',
                                value: measurement.heartRateAvg > 0
                                    ? '${measurement.heartRateAvg}'
                                    : '--',
                                unit: ' BPM',
                                child: _buildMiniLineChart(measurement.bpmSpots),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildStatCard(
                                title: 'SUHU AVG',
                                value: measurement.tempAvg > 0
                                    ? measurement.tempAvg.toStringAsFixed(1)
                                    : '--',
                                unit: ' °C',
                                child: _buildMiniTempChart(measurement.tempHeights),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),

                      // My Device
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Perangkat GlucoBand',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => DeviceConfigDialog.show(
                                context,
                                onConnected: _checkDeviceStatus,
                              ),
                              icon: const Icon(Icons.settings, size: 16, color: Color(0xFF613EEA)),
                              label: const Text(
                                'Kelola',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF613EEA),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: InkWell(
                          onTap: () => DeviceConfigDialog.show(
                            context,
                            onConnected: _checkDeviceStatus,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: _isDeviceConnected
                                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                    : Colors.red.withValues(alpha: 0.2),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: _isDeviceConnected
                                        ? const Color(0xFFF3F0FF)
                                        : Colors.red.shade50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isDeviceConnected ? Icons.wifi : Icons.wifi_off,
                                    color: _isDeviceConnected
                                        ? const Color(0xFF613EEA)
                                        : Colors.red.shade400,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isDeviceConnected ? _deviceSsid : 'GlucoBand (ESP32)',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Icon(
                                            _isDeviceConnected ? Icons.link : Icons.link_off,
                                            color: const Color(0xFF64748B),
                                            size: 14,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              _isDeviceConnected
                                                  ? 'IP: $_deviceIp '
                                                  : 'Perangkat Terputus',
                                              style: TextStyle(
                                                color: _isDeviceConnected
                                                    ? const Color(0xFF64748B)
                                                    : Colors.red.shade400,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: _isDeviceConnected
                                        ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: _isDeviceConnected
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _isDeviceConnected ? 'Connected' : 'Disconnected',
                                        style: TextStyle(
                                          color: _isDeviceConnected
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFEF4444),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),

                      // Status Terkini
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: const Text(
                          'Status Terkini',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          final double currentGlucose = measurement.latestGlucose;
                          String statusLabel = 'Normal';
                          Color statusColor = const Color(0xFF059669);
                          Color statusBgColor = const Color(0xFF10B981).withValues(alpha: 0.18);
                          String rangeSubtitle = '70-120 range (Normal)';

                          if (currentGlucose > 200) {
                            statusLabel = 'Hiperglikemia';
                            statusColor = const Color(0xFFDC2626);
                            statusBgColor = const Color(0xFFEF4444).withValues(alpha: 0.18);
                            rangeSubtitle = '> 200 mg/dL (Tinggi)';
                          } else if (currentGlucose < 70 && currentGlucose > 0) {
                            statusLabel = 'Hipoglikemia';
                            statusColor = const Color(0xFFD97706);
                            statusBgColor = const Color(0xFFF59E0B).withValues(alpha: 0.18);
                            rangeSubtitle = '< 70 mg/dL (Rendah)';
                          } else if (currentGlucose <= 0) {
                            statusLabel = 'Belum Ada';
                            statusColor = const Color(0xFF64748B);
                            statusBgColor = const Color(0xFF94A3B8).withValues(alpha: 0.18);
                            rangeSubtitle = 'Belum ada pengukuran';
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.baseline,
                                            textBaseline: TextBaseline.alphabetic,
                                            children: [
                                              Text(
                                                currentGlucose > 0
                                                    ? currentGlucose.toStringAsFixed(1)
                                                    : '--',
                                                style: const TextStyle(
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1E293B),
                                                  letterSpacing: -1,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Text(
                                                'mg/dL',
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          const Text(
                                            'CURRENT GLUCOSE LEVEL',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: Color(0xFF94A3B8),
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const Spacer(),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusBgColor,
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Text(
                                              statusLabel,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            rangeSubtitle,
                                            style: TextStyle(
                                              color: Colors.grey[500],
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 30),
                                  SizedBox(
                                    height: 100,
                                    child: _buildMainChart(measurement.mainChartSpots),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action Buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const PredictionHistoryPage()),
                                  );
                                },
                                icon: const Icon(Icons.history, color: Color(0xFF613EEA), size: 20),
                                label: const Text('Riwayat', style: TextStyle(color: Color(0xFF613EEA), fontWeight: FontWeight.w600)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF3F0FF),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  final homeState = context.findAncestorStateOfType<HomePageState>();
                                  if (homeState != null) {
                                    homeState.setIndex(2); // Pindah ke tab Pengukuran (index 2)
                                  }
                                },
                                icon: const Icon(Icons.play_circle_outline, color: Colors.white, size: 20),
                                label: const Text('Ukur Sekarang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF613EEA),
                                  elevation: 2,
                                  shadowColor: const Color(0xFF613EEA).withValues(alpha: 0.4),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Articles
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Artikel & Berita Medis',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              'Lihat Semua',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF613EEA),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (articleProvider.isLoading)
                        const Center(child: CircularProgressIndicator())
                      else if (articleProvider.articles.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Text('Tidak ada artikel tersedia.'),
                        )
                      else
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: articleProvider.articles.length,
                          itemBuilder: (context, index) {
                            final article = articleProvider.articles[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      article.imageUrl,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          width: 80,
                                          height: 80,
                                          color: Colors.grey[200],
                                          child: const Icon(Icons.image, color: Colors.grey),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          article.title,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          article.description,
                                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time, size: 12, color: Color(0xFF94A3B8)),
                                            const SizedBox(width: 4),
                                            Text(
                                              article.timeToRead,
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value, required String unit, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
              Text(unit, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(height: 40, child: child),
        ],
      ),
    );
  }

  Widget _buildMiniBarChart(List<double> heights) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights.map((h) {
        Color barColor = const Color(0xFF613EEA);
        if (h >= 32) {
          barColor = const Color(0xFFEF4444);
        } else if (h <= 18) {
          barColor = const Color(0xFFF59E0B);
        }
        return _bar(h, barColor);
      }).toList(),
    );
  }
  
  Widget _bar(double height, Color color) {
    return Container(
      width: 6,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildMiniLineChart(List<FlSpot> spots) {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF613EEA),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTempChart(List<double> heights) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: heights.map((h) {
        Color barColor = const Color(0xFF10B981); // Hijau normal
        if (h >= 32) {
          barColor = const Color(0xFFEF4444); // Hangat / demam
        } else if (h <= 18) {
          barColor = const Color(0xFF38BDF8); // Sejuk
        }
        return _bar(h, barColor);
      }).toList(),
    );
  }

  Widget _buildMiniFlatChart(double insulinUnits) {
    final double width = (insulinUnits * 5.0).clamp(12.0, 48.0);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: 3,
        decoration: BoxDecoration(
          color: const Color(0xFF613EEA),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildMainChart(List<FlSpot> spots) {
    if (spots.isEmpty) {
      return Center(
        child: Text(
          'Belum ada data glukosa di rentang waktu ini',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[400],
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.15),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
        ),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF613EEA),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF613EEA).withValues(alpha: 0.15),
                  const Color(0xFF613EEA).withValues(alpha: 0.01),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
