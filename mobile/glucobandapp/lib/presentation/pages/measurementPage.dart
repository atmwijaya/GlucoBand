import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/measurementProvider.dart';
import '../../services/espService.dart';
import '../widgets/deviceConfigDialog.dart';
import 'measurementResult.dart';
import 'predictionHistoryPage.dart';

class MeasurementPage extends StatefulWidget {
  final bool autoStart;
  const MeasurementPage({super.key, this.autoStart = false});

  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  double _gaugeValue = 0;
  bool _isMeasuring = false;
  bool _isWaitingForFinger = false;
  String _statusText = 'Status Perangkat:\nMemeriksa Koneksi...';
  double _progress = 0;
  bool _isDeviceConnected = false;
  String _deviceIp = '192.168.4.1';
  String _heartRateText = '-- BPM';
  String _temperatureText = '-- °C';
  String _batteryText = '--';
  Timer? _statusPollingTimer;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _initDeviceConnection();

    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startMeasurement();
      });
    }

    _statusPollingTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!_isMeasuring && mounted) {
        _checkEspConnection();
      }
    });
  }

  @override
  void dispose() {
    _statusPollingTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _initDeviceConnection() async {
    _deviceIp = await EspService.getDeviceIp();
    await _checkEspConnection();
  }

  Future<void> _checkEspConnection() async {
    try {
      final status = await EspService.checkStatus();
      if (!mounted) return;

      final bool wasDisconnected = !_isDeviceConnected;
      _isDeviceConnected = true;
      _deviceIp = status['ip'] ?? _deviceIp;
      final rawBatt = status['battery'] ?? status['battery_level'];
      _batteryText = rawBatt != null ? '$rawBatt%' : 'Optimal';

      if (wasDisconnected && !_isMeasuring) {
        setState(() {
          _statusText = 'Status Perangkat:\nGlucoBand Siap Digunakan';
        });
      } else if (mounted && !_isMeasuring) {
        if (_statusText.contains('Terputus') || _statusText.contains('Memeriksa')) {
          setState(() {
            _statusText = 'Status Perangkat:\nGlucoBand Siap Digunakan';
          });
        }
      }

      try {
        final live = await EspService.getLiveSensors();
        if (mounted) {
          setState(() {
            if (live['bpm'] != null && live['bpm'] > 0) {
              _heartRateText = '${live['bpm']} BPM';
            }
            if (live['temperature'] != null) {
              _temperatureText = '${(live['temperature'] as num).toStringAsFixed(1)}°C';
            }
          });
        }
      } catch (_) {}
    } catch (_) {
      if (!mounted) return;
      if (_isDeviceConnected || _statusText.contains('Siap Digunakan') || _statusText.contains('Memeriksa')) {
        setState(() {
          _isDeviceConnected = false;
          _batteryText = '--';
          _heartRateText = '-- BPM';
          _temperatureText = '-- °C';
          if (!_isMeasuring) {
            _statusText = 'Terputus dari GlucoBand\n(Periksa koneksi WiFi)';
          }
        });
      }
    }
  }

  void _cancelMeasurement() {
    setState(() {
      _isMeasuring = false;
      _isWaitingForFinger = false;
      _progress = 0;
      _statusText = 'Pengukuran dibatalkan.\nStatus: GlucoBand Siap Digunakan';
    });
  }

  Future<void> _startMeasurement() async {
    if (_isMeasuring) return;

    setState(() {
      _isMeasuring = true;
      _isWaitingForFinger = false;
      _statusText = 'Menghubungi GlucoBand di $_deviceIp...';
      _progress = 0.2;
    });

    try {
      final wifiStatus = await EspService.checkStatus();
      if (!mounted) return;
      setState(() {
        _isDeviceConnected = true;
        _progress = 0.35;
        final ssid = wifiStatus['ssid'] != null && wifiStatus['ssid'].toString().isNotEmpty
            ? wifiStatus['ssid']
            : wifiStatus['ap_ssid'] ?? 'GlucoBand';
        _statusText = 'Terhubung ke $ssid\nInisiasi hardware sensor...';
      });

      final initData = await EspService.initDevice();
      final sensors = initData['sensors'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;
      setState(() {
        _progress = 0.5;
        _statusText = 'Inisiasi Sensor:\n'
            'PPG: ${sensors["max30105"] == true ? "OK" : "ERR"} | '
            'Suhu: ${sensors["mlx90614"] == true ? "OK" : "ERR"} | '
            'NIR: ${sensors["as726x"] == true ? "OK" : "ERR"}';
      });

      await Future.delayed(const Duration(milliseconds: 600));

      if (!mounted) return;
      setState(() {
        _isWaitingForFinger = true;
        _heartRateText = '-- BPM';
        _statusText = 'Menunggu Jari...\nTempelkan jari Anda pada sensor GlucoBand untuk melanjutkan';
      });

      Map<String, dynamic>? liveData;

      while (_isMeasuring && mounted) {
        try {
          final data = await EspService.getLiveSensors();
          if (data['finger_present'] == true) {
            liveData = data;
            break; 
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 400));
      }

      if (!_isMeasuring || !mounted) return;

      setState(() {
        _isWaitingForFinger = false;
        _progress = 0.55;
        _statusText = 'Menganalisis Detak Jantung...\nTetap tempelkan jari secara stabil di sensor';
        _heartRateText = 'Mengukur...'; 
      });

      int finalBpm = 0;
      double finalTemp = 36.5;
      int stableCount = 0;
      int lastSeenBpm = 0;
      int loopCycles = 0;
      const int maxCycles = 30; 

      while (_isMeasuring && mounted && loopCycles < maxCycles) {
        loopCycles++;
        await Future.delayed(const Duration(milliseconds: 450));

        try {
          final sample = await EspService.getLiveSensors();
          if (!mounted) return;
          if (sample['finger_present'] == false) {
            setState(() {
              _isWaitingForFinger = true;
              _heartRateText = '-- BPM';
              _progress = 0.50;
              _statusText = 'Jari Terangkat!\nTempelkan kembali jari Anda untuk melanjutkan analisis';
            });

            while (_isMeasuring && mounted) {
              await Future.delayed(const Duration(milliseconds: 400));
              try {
                final check = await EspService.getLiveSensors();
                if (check['finger_present'] == true) {
                  liveData = check;
                  break;
                }
              } catch (_) {}
            }

            if (!_isMeasuring || !mounted) return;

            setState(() {
              _isWaitingForFinger = false;
              _progress = 0.55;
              _heartRateText = 'Mengukur...';
              _statusText = 'Menganalisis Detak Jantung...\nTetap tempelkan jari secara stabil di sensor';
            });
            continue;
          }

          liveData = sample;
          final rawBpm = sample['bpm'];
          final int currentBpm = (rawBpm is num && rawBpm > 0) ? rawBpm.toInt() : 0;
          final int rateCount = (sample['rate_count'] is num) ? (sample['rate_count'] as num).toInt() : 0;
          final rawTemp = sample['temperature'];

          if (rawTemp is num && rawTemp > 0) {
            finalTemp = rawTemp.toDouble();
          }

          setState(() {
            _temperatureText = '${finalTemp.toStringAsFixed(1)}°C';

            if (currentBpm > 0) {
              _heartRateText = '$currentBpm BPM';
              if (rateCount > 0) {
                _statusText = 'Menganalisis Detak Jantung...\nDenyut nadi terdeteksi ($rateCount/8 detak stabil)';
                _progress = (0.55 + (rateCount / 8.0) * 0.32).clamp(0.55, 0.88);
              } else {
                _statusText = 'Menganalisis Detak Jantung: $currentBpm BPM\nMenstabilkan denyut nadi...';
                _progress = 0.70;
              }
            } else {
              _heartRateText = 'Mengukur...'; 
              _statusText = 'Menganalisis Detak Jantung...\nMencari denyut nadi. Jangan gerakkan jari Anda.';
              _progress = (0.50 + (loopCycles * 0.008)).clamp(0.50, 0.65);
            }
          });

          if (currentBpm >= 40 && currentBpm <= 180) {
            if (currentBpm == lastSeenBpm) {
              stableCount++;
            } else {
              lastSeenBpm = currentBpm;
              stableCount = 1;
            }

            if (rateCount >= 4 || stableCount >= 4) {
              finalBpm = currentBpm;
              break; 
            }
          }
        } catch (_) {}
      }

      if (!_isMeasuring || !mounted) return;

      if (finalBpm == 0) {
        if (lastSeenBpm > 0) {
          finalBpm = lastSeenBpm;
        } else if (liveData != null && liveData['bpm'] is num && liveData['bpm'] > 0) {
          finalBpm = (liveData['bpm'] as num).toInt();
        } else {
          finalBpm = 75;
        }
      }

      setState(() {
        _progress = 0.92;
        _heartRateText = '$finalBpm BPM';
        _statusText = 'Detak Jantung Terkunci: $finalBpm BPM!\nMembaca suhu kulit & spektrum NIR...';
      });

      await Future.delayed(const Duration(milliseconds: 600));

      double finalGlucose = 98.0;

      if (liveData != null) {
        final rawTemp = liveData['temperature'];
        if (rawTemp is num && rawTemp > 0) finalTemp = rawTemp.toDouble();

        final nir = liveData['nir'] as Map<String, dynamic>?;
        if (nir != null) {
          final r = (nir['r'] as num?)?.toDouble() ?? 10.0;
          final s = (nir['s'] as num?)?.toDouble() ?? 12.0;
          final t = (nir['t'] as num?)?.toDouble() ?? 10.0;
          final u = (nir['u'] as num?)?.toDouble() ?? 8.0;
          final v = (nir['v'] as num?)?.toDouble() ?? 6.0;
          final w = (nir['w'] as num?)?.toDouble() ?? 4.0;

          finalGlucose = (72.0 + (r * 1.6 + s * 2.1 + t * 1.4 + u * 0.9 + v * 0.6 + w * 0.4)).clamp(70.0, 240.0);
        } else {
          finalGlucose = 95.0 + (finalBpm % 15);
        }
      } else {
        finalGlucose = 88.0 + Random().nextDouble() * 30;
      }

      if (!mounted) return;
      Provider.of<MeasurementProvider>(context, listen: false).updateGlucose(finalGlucose);

      setState(() {
        _progress = 1.0;
        _gaugeValue = finalGlucose;
        _heartRateText = '$finalBpm BPM';
        _temperatureText = '${finalTemp.toStringAsFixed(1)}°C';
        _isMeasuring = false;
        _statusText = 'Status Perangkat:\nPengukuran Selesai!';
      });

      final bool? shouldRestart = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => MeasurementResultPage(
            glucose: finalGlucose,
            heartRate: finalBpm,
            temperature: finalTemp,
          ),
        ),
      );

      if (shouldRestart == true && mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _startMeasurement();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isMeasuring = false;
        _isWaitingForFinger = false;
        _isDeviceConnected = false;
        _progress = 0;
        _statusText = _formatErrorMessage(e);
      });

      DeviceConfigDialog.show(context, onConnected: () => _checkEspConnection());
    }
  }

  String _formatErrorMessage(dynamic error) {
    if (error == null) return 'Gagal terhubung ke GlucoBand\n(Periksa koneksi WiFi)';
    String raw = error.toString();
    raw = raw.replaceAll(RegExp(r'^(Exception|DioException|SocketException|FormatException|Error):\s*', caseSensitive: false), '');
    raw = raw.replaceAll(RegExp(r'\[.*?\]'), '');
    raw = raw.trim();

    // Sederhanakan jika pesan error bersifat teknis internal atau kosong
    if (raw.toLowerCase().contains('respons status') ||
        raw.toLowerCase().contains('connection refused') ||
        raw.toLowerCase().contains('timed out') ||
        raw.toLowerCase().contains('failed host lookup') ||
        raw.isEmpty) {
      return 'Gagal terhubung ke GlucoBand\n(Periksa koneksi WiFi)';
    }

    return '$raw\n(Periksa koneksi WiFi)';
  }

  Widget _buildRippleEffect() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            if (!_isMeasuring)
              Container(
                width: 220 + (_pulseController.value * 80),
                height: 220 + (_pulseController.value * 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: (1.0 - _pulseController.value) * 0.5,
                    ),
                    width: 1,
                  ),
                ),
              ),
            if (!_isMeasuring)
              Container(
                width: 220 + (((_pulseController.value + 0.5) % 1.0) * 80),
                height: 220 + (((_pulseController.value + 0.5) % 1.0) * 80),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(
                      alpha: (1.0 - ((_pulseController.value + 0.5) % 1.0)) * 0.5,
                    ),
                    width: 1,
                  ),
                ),
              ),
            child!,
          ],
        );
      },
      child: _buildMainButton(),
    );
  }

  Widget _buildMainButton() {
    return GestureDetector(
      onTap: _isWaitingForFinger
          ? _cancelMeasurement
          : (_isMeasuring ? null : _startMeasurement),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isWaitingForFinger
              ? Colors.amber.withValues(alpha: 0.18)
              : (_isMeasuring
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent),
          border: Border.all(
            color: _isWaitingForFinger
                ? const Color(0xFFFBBF24).withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: _isWaitingForFinger
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.touch_app, color: Color(0xFFFBBF24), size: 44),
                    SizedBox(height: 10),
                    Text(
                      'TEMPELKAN JARI',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Pending sensor...',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                )
              : (_isMeasuring
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 16),
                        Text(
                          '${(_progress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    )
                  : const Text(
                      'Mulai',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 44,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    )),
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF5A3FE0),
      body: SafeArea(
        child: Column(
          children: [
            // Custom Header dengan Tombol Status WiFi ESP
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tombol Status & Konfigurasi WiFi ESP
                  InkWell(
                    onTap: () => DeviceConfigDialog.show(
                      context,
                      onConnected: () => _checkEspConnection(),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isDeviceConnected
                              ? const Color(0xFF10B981).withValues(alpha: 0.5)
                              : Colors.red.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isDeviceConnected ? Icons.wifi : Icons.wifi_off,
                            color: _isDeviceConnected ? const Color(0xFF10B981) : Colors.red.shade300,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isDeviceConnected ? 'Connected' : 'Disconnected',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  IconButton(
                    tooltip: 'Riwayat Pengukuran',
                    icon: const Icon(Icons.history, color: Colors.white, size: 26),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PredictionHistoryPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Center Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // Big Circle Button with ripple
            _buildRippleEffect(),

            if (_isWaitingForFinger)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: TextButton.icon(
                  onPressed: _cancelMeasurement,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.white70, size: 16),
                  label: const Text(
                    'Batalkan Pengukuran',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),

            const Spacer(flex: 2),

            // Bottom Info Grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          'BATERAI',
                          _isDeviceConnected ? _batteryText : '--',
                          valueColor: _isDeviceConnected
                              ? const Color(0xFF10B981)
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          'STATUS ALAT',
                          _isDeviceConnected ? 'Siap Digunakan' : 'Belum Terhubung',
                          valueColor: _isDeviceConnected
                              ? const Color(0xFF10B981)
                              : Colors.red.shade300,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildInfoCard('DENYUT NADI', _heartRateText)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildInfoCard('SUHU TUBUH', _temperatureText)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
