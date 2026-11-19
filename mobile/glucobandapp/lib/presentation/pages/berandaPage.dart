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
import 'measurementHistoryPage.dart';
import '../../services/espService.dart';
import '../widgets/deviceConfigDialog.dart';
import '../widgets/glucoseChart.dart';
import '../../core/utils/glucoseStatus.dart';
import '../../data/models/measurementModel.dart';

class BerandaPage extends StatefulWidget {
  const BerandaPage({super.key});

  @override
  State<BerandaPage> createState() => _BerandaPageState();
}

class _BerandaPageState extends State<BerandaPage> {
  bool _isDeviceConnected = false;
  String _deviceSsid = 'GlucoBand (ESP32)';
  String _deviceIp = '192.168.4.1';
  String _batteryText = 'Optimal';
  Timer? _deviceTimer;
  String _glucoseTimeFilter = '1 Hari';

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
        final rawBatt = status['battery'] ?? status['battery_level'];
        _batteryText = rawBatt != null ? '$rawBatt%' : 'Optimal';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDeviceConnected = false;
        _batteryText = '--';
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
      notifProvider.connectSocket(auth.token!, currentUserId: auth.user?.id);
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
                                      Icon(Icons.access_time, size: 18, color: Color(0xFF613EEA)),
                                      SizedBox(width: 8),
                                      Text('6 Jam', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: '1 Hari',
                                  child: Row(
                                    children: [
                                      Icon(Icons.today, size: 18, color: Color(0xFF613EEA)),
                                      SizedBox(width: 8),
                                      Text('1 Hari', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: '7 Hari',
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_month, size: 18, color: Color(0xFF613EEA)),
                                      SizedBox(width: 8),
                                      Text('7 Hari', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                              child: _buildInteractiveStatCard(
                                title: 'GLUCOSE AVG',
                                icon: Icons.water_drop_rounded,
                                iconColor: const Color(0xFF613EEA),
                                value: measurement.glucoseAvg > 0
                                    ? measurement.glucoseAvg.toStringAsFixed(0)
                                    : '--',
                                unit: ' mg/dL',
                                statusBadge: GlucoseStatusHelper.getLabel(measurement.glucoseAvg),
                                statusColor: GlucoseStatusHelper.getColor(measurement.glucoseAvg),
                                statusBg: GlucoseStatusHelper.getBgColor(measurement.glucoseAvg),
                                metricType: 'glucose',
                                measurements: measurement.recentMeasurements,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInteractiveStatCard(
                                title: 'BPM AVG',
                                icon: Icons.favorite_rounded,
                                iconColor: const Color(0xFFEF4444),
                                value: measurement.heartRateAvg > 0
                                    ? '${measurement.heartRateAvg}'
                                    : '--',
                                unit: ' BPM',
                                statusBadge: GlucoseStatusHelper.getBpmLabel(measurement.heartRateAvg),
                                statusColor: GlucoseStatusHelper.getBpmColor(measurement.heartRateAvg),
                                statusBg: GlucoseStatusHelper.getBpmColor(measurement.heartRateAvg).withValues(alpha: 0.12),
                                metricType: 'bpm',
                                measurements: measurement.recentMeasurements,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildInteractiveStatCard(
                                title: 'SUHU AVG',
                                icon: Icons.thermostat_rounded,
                                iconColor: const Color(0xFF0D9488),
                                value: measurement.tempAvg > 0
                                    ? measurement.tempAvg.toStringAsFixed(1)
                                    : '--',
                                unit: ' °C',
                                statusBadge: GlucoseStatusHelper.getTempLabel(measurement.tempAvg),
                                statusColor: GlucoseStatusHelper.getTempColor(measurement.tempAvg),
                                statusBg: GlucoseStatusHelper.getTempColor(measurement.tempAvg).withValues(alpha: 0.12),
                                metricType: 'temp',
                                measurements: measurement.recentMeasurements,
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
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: _isDeviceConnected
                                            ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                            : Colors.red.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
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
                                            _isDeviceConnected ? 'Terhubung' : 'Terputus',
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
                                    if (_isDeviceConnected) ...[
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.battery_std_rounded,
                                            size: 13,
                                            color: Color(0xFF10B981),
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            _batteryText,
                                            style: const TextStyle(
                                              color: Color(0xFF059669),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
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
                          final statusColor = GlucoseStatusHelper.getColor(currentGlucose);
                          final statusBgColor = GlucoseStatusHelper.getBgColor(currentGlucose);
                          final statusLabel = GlucoseStatusHelper.getLabel(currentGlucose);
                          final rangeSubtitle = GlucoseStatusHelper.getSubtitle(currentGlucose);

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: currentGlucose > 200
                                      ? const Color(0xFFEF4444).withValues(alpha: 0.25)
                                      : (currentGlucose < 70 && currentGlucose > 0
                                          ? const Color(0xFFF59E0B).withValues(alpha: 0.25)
                                          : const Color(0xFFF1F5F9)),
                                  width: currentGlucose > 200 || (currentGlucose < 70 && currentGlucose > 0) ? 1.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.06),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
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
                                                style: TextStyle(
                                                  fontSize: 48,
                                                  fontWeight: FontWeight.w800,
                                                  color: currentGlucose > 0 ? statusColor : const Color(0xFF1E293B),
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
                                            'LEVEL GLUKOSA SAAT INI',
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
                                              border: Border.all(
                                                color: statusColor.withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration: BoxDecoration(
                                                    color: statusColor,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ],
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
                                  const SizedBox(height: 20),

                                  _buildGlucoseMeter(currentGlucose, statusColor),

                                  const SizedBox(height: 24),

                                  GlucoseStockChart(
                                    measurements: measurement.measurements,
                                    latestGlucose: currentGlucose,
                                    timeFilter: _glucoseTimeFilter,
                                    statusColor: statusColor,
                                    onFilterChanged: (newFilter) {
                                      setState(() {
                                        _glucoseTimeFilter = newFilter;
                                      });
                                    },
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
                                    MaterialPageRoute(builder: (_) => const MeasurementHistoryPage()),
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

  Widget _buildInteractiveStatCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String unit,
    required String statusBadge,
    required Color statusColor,
    required Color statusBg,
    required String metricType,
    required List<MeasurementModel> measurements,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Judul & Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 9,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 13, color: iconColor),
            ],
          ),
          const SizedBox(height: 6),

          // Nilai Rata-rata & Satuan
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Chip Status Ringkas
          if (value != '--')
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: statusBg,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusBadge,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            )
          else
            const SizedBox(height: 15),

          const SizedBox(height: 10),

          // Diagram Batang Interaktif Seragam
          SizedBox(
            height: 44,
            child: _buildMiniBarChartWidget(metricType, measurements),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniBarChartWidget(
    String metricType,
    List<MeasurementModel> measurements,
  ) {
    if (measurements.isEmpty) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(
          4,
          (_) => Container(
            width: 6,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      );
    }

    final List<BarChartGroupData> barGroups = [];
    double maxY = 100.0;

    for (int i = 0; i < measurements.length; i++) {
      final m = measurements[i];
      double toY = 0.0;
      Color barColor = const Color(0xFF613EEA);

      if (metricType == 'glucose') {
        toY = m.glucoseEstimated;
        barColor = GlucoseStatusHelper.getColor(m.glucoseEstimated);
        if (toY > maxY) maxY = toY;
      } else if (metricType == 'bpm') {
        toY = m.ppgHeartRate.toDouble();
        barColor = GlucoseStatusHelper.getBpmColor(m.ppgHeartRate);
        if (toY > maxY) maxY = toY;
      } else {
        final temp = m.skinTempCelsius;
        toY = temp > 0
            ? ((temp - 34.0) / (40.0 - 34.0) * 35.0 + 8.0).clamp(6.0, 42.0)
            : 0.0;
        barColor = GlucoseStatusHelper.getTempColor(temp);
        maxY = 45.0;
      }

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: toY > 0 ? toY : 3.0,
              color: toY > 0 ? barColor : const Color(0xFFE2E8F0),
              width: 7,
              borderRadius: BorderRadius.circular(4),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY > 0 ? maxY : 100.0,
                color: const Color(0xFFF8FAFC),
              ),
            ),
          ],
        ),
      );
    }

    return BarChart(
      BarChartData(
        maxY: maxY > 0 ? maxY * 1.15 : 100.0,
        minY: 0,
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF0F172A),
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            tooltipMargin: 4,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (group.x >= measurements.length) return null;
              final m = measurements[group.x];
              String valStr = '';
              if (metricType == 'glucose') {
                valStr = '${m.glucoseEstimated.toStringAsFixed(0)} mg/dL';
              } else if (metricType == 'bpm') {
                valStr = m.ppgHeartRate > 0 ? '${m.ppgHeartRate} BPM' : '-- BPM';
              } else {
                valStr = m.skinTempCelsius > 0
                    ? '${m.skinTempCelsius.toStringAsFixed(1)} °C'
                    : '-- °C';
              }
              final timeStr = DateFormat('HH:mm').format(m.createdAt);
              return BarTooltipItem(
                '$valStr\n$timeStr',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
              );
            },
          ),
        ),
        barGroups: barGroups,
      ),
    );
  }

  Widget _meterZoneBadge(String label, Color color, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isActive ? color.withValues(alpha: 0.6) : Colors.transparent,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
          color: isActive ? color : const Color(0xFF94A3B8),
        ),
      ),
    );
  }

  Widget _buildGlucoseMeter(double currentGlucose, Color statusColor) {
    final double fraction = GlucoseStatusHelper.getMeterFraction(currentGlucose);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Baris Label Zona Meter
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _meterZoneBadge('< 70 Hipo', const Color(0xFFF59E0B), currentGlucose < 70 && currentGlucose > 0),
            _meterZoneBadge('70-140 Normal', const Color(0xFF10B981), currentGlucose >= 70 && currentGlucose <= 140),
            _meterZoneBadge('140-200 Waspada', const Color(0xFFF97316), currentGlucose > 140 && currentGlucose <= 200),
            _meterZoneBadge('> 200 Hiper', const Color(0xFFEF4444), currentGlucose > 200),
          ],
        ),
        const SizedBox(height: 8),

        // Batang Meteran Bersegmen
        LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final pointerX = (fraction * (totalWidth - 14)).clamp(0.0, totalWidth - 14);

            return Stack(
              clipBehavior: Clip.none,
              children: [
                // 4 Segmen Warna Meter
                Container(
                  height: 8,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      // Hipo: < 70 (30 / 260 ≈ 15%)
                      Expanded(
                        flex: 15,
                        child: Container(color: const Color(0xFFF59E0B)),
                      ),
                      const SizedBox(width: 2),
                      // Normal: 70 - 140 (70 / 260 ≈ 35%)
                      Expanded(
                        flex: 35,
                        child: Container(color: const Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 2),
                      // Waspada: 140 - 200 (60 / 260 ≈ 25%)
                      Expanded(
                        flex: 25,
                        child: Container(color: const Color(0xFFF97316)),
                      ),
                      const SizedBox(width: 2),
                      // Hiper: > 200 (60 / 260 ≈ 25%)
                      Expanded(
                        flex: 25,
                        child: Container(color: const Color(0xFFEF4444)),
                      ),
                    ],
                  ),
                ),

                // Jarum Penunjuk Meteran (Animated Pointer Indicator)
                if (currentGlucose > 0)
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutBack,
                    left: pointerX,
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 16,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withValues(alpha: 0.5),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
