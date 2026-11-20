import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../data/models/measurementModel.dart';
import '../../services/apiService.dart';
import '../../core/constants/apiConstant.dart';

class MeasurementProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<MeasurementModel> _measurements = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _timeFilter = '6 Jam'; // Pilihan untuk Statistik: '6 Jam', '1 Hari', '7 Hari'
  double _liveGlucose = 0.0;

  // Getters
  List<MeasurementModel> get measurements => _measurements;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get timeFilter => _timeFilter;

  /// Daftar pengukuran yang telah difilter sesuai rentang waktu aktif
  List<MeasurementModel> get filteredMeasurements {
    if (_measurements.isEmpty) return [];

    final now = DateTime.now();
    DateTime cutoff;
    if (_timeFilter == '6 Jam') {
      cutoff = now.subtract(const Duration(hours: 6));
    } else if (_timeFilter == '1 Hari' || _timeFilter == '24 Jam' || _timeFilter == 'Harian' || _timeFilter == 'Day') {
      cutoff = now.subtract(const Duration(hours: 24));
    } else if (_timeFilter == '7 Hari' || _timeFilter == '1 Minggu' || _timeFilter == '7 Days' || _timeFilter == 'Week') {
      cutoff = now.subtract(const Duration(days: 7));
    } else {
      cutoff = now.subtract(const Duration(hours: 6));
    }

    final filtered = _measurements
        .where((m) => m.createdAt.isAfter(cutoff))
        .toList();
    return filtered;
  }

  /// Glukosa terkini (terbaru dari database atau hasil live streaming)
  double get latestGlucose {
    if (_measurements.isNotEmpty) {
      return _measurements.first.glucoseEstimated;
    }
    return _liveGlucose;
  }

  /// Rata-rata kadar glukosa riil dalam periode yang dipilih
  double get glucoseAvg {
    final list = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (list.isEmpty) {
      return _liveGlucose > 0 ? _liveGlucose : 0.0;
    }
    final sum = list.fold<double>(0.0, (prev, m) => prev + m.glucoseEstimated);
    return double.parse((sum / list.length).toStringAsFixed(1));
  }

  /// Persentase waktu dalam rentang normal (Time in Range: 70 - 140 mg/dL)
  int get rangePercent {
    final list = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (list.isEmpty) return 0;
    final inRangeCount = list
        .where((m) => m.glucoseEstimated >= 70.0 && m.glucoseEstimated <= 140.0)
        .length;
    return ((inRangeCount / list.length) * 100).round();
  }

  /// Estimasi kebutuhan insulin riil (Correction Factor / Bolus Unit) berdasarkan rata-rata glukosa
  double get insulin {
    final avg = glucoseAvg;
    if (avg <= 0) return 0.0;
    if (avg > 100.0) {
      final calculated = (avg - 100.0) / 35.0;
      return double.parse(calculated.clamp(0.5, 20.0).toStringAsFixed(1));
    }
    return 1.0;
  }

  /// Rata-rata detak jantung (BPM) dalam periode yang dipilih
  int get heartRateAvg {
    final list = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (list.isEmpty) return 0;
    final validHeartRates = list.where((m) => m.ppgHeartRate > 0).toList();
    if (validHeartRates.isEmpty) return 0;
    final sum = validHeartRates.fold<int>(
      0,
      (prev, m) => prev + m.ppgHeartRate,
    );
    return (sum / validHeartRates.length).round();
  }

  /// Rata-rata suhu permukaan kulit (°C) dalam periode yang dipilih
  double get tempAvg {
    final list = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (list.isEmpty) return 0.0;
    final validTemps = list.where((m) => m.skinTempCelsius > 0).toList();
    if (validTemps.isEmpty) return 0.0;
    final sum = validTemps.fold<double>(
      0.0,
      (prev, m) => prev + m.skinTempCelsius,
    );
    return double.parse((sum / validTemps.length).toStringAsFixed(1));
  }

  /// Daftar model pengukuran yang ditampilkan pada grafik utama (kronologis)
  List<MeasurementModel> get mainChartMeasurements {
    final sourceList = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (sourceList.isEmpty) return [];

    final chronological = List<MeasurementModel>.from(sourceList)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return chronological.length > 15
        ? chronological.sublist(chronological.length - 15)
        : chronological;
  }

  /// Daftar hingga 6 pengukuran terbaru (kronologis) untuk diagram batang statistik interaktif
  List<MeasurementModel> get recentMeasurements {
    final sourceList = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (sourceList.isEmpty) return [];

    final chronological = List<MeasurementModel>.from(sourceList)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return chronological.length > 6
        ? chronological.sublist(chronological.length - 6)
        : chronological;
  }

  /// Titik-titik grafik utama (Status Terkini) berdasarkan riwayat kronologis
  List<FlSpot> get mainChartSpots {
    final sourceList = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (sourceList.isEmpty) {
      if (latestGlucose > 0) {
        return [FlSpot(0, latestGlucose), FlSpot(1, latestGlucose)];
      }
      return [];
    }

    // Urutkan kronologis (terlama ke terbaru untuk grafik sumbu X kiri ke kanan)
    final chronological = List<MeasurementModel>.from(sourceList)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Batasi maksimum 15 titik agar grafik tetap rapi
    final displayedList = chronological.length > 15
        ? chronological.sublist(chronological.length - 15)
        : chronological;

    if (displayedList.length == 1) {
      final val = displayedList.first.glucoseEstimated;
      return [FlSpot(0, val), FlSpot(1, val)];
    }

    return List.generate(displayedList.length, (index) {
      return FlSpot(index.toDouble(), displayedList[index].glucoseEstimated);
    });
  }

  /// Nilai ketinggian batang (15 - 40 px) untuk mini bar chart berdasarkan 5 data riil terbaru
  List<double> get miniBarHeights {
    final sourceList = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (sourceList.isEmpty) {
      return [20.0, 25.0, 20.0, 25.0, 20.0];
    }

    final latestFive = sourceList.take(5).toList().reversed.toList();
    return latestFive.map((m) {
      // Normalisasi nilai glukosa (rentang 50 - 250 mg/dL ke tinggi 15 - 40 px)
      final normalized =
          ((m.glucoseEstimated - 50.0) / (250.0 - 50.0) * 25.0 + 15.0).clamp(
            12.0,
            40.0,
          );
      return normalized;
    }).toList();
  }

  /// Titik mini line chart untuk kartu rentang (Range)
  List<FlSpot> get miniLineSpots {
    final sourceList = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    if (sourceList.isEmpty) {
      return const [FlSpot(0, 1), FlSpot(1, 2), FlSpot(2, 1.5), FlSpot(3, 3)];
    }
    final latestFour = sourceList.take(4).toList().reversed.toList();
    if (latestFour.length == 1) {
      return const [FlSpot(0, 2), FlSpot(1, 2)];
    }
    return List.generate(latestFour.length, (i) {
      final g = latestFour[i].glucoseEstimated;
      // Normalisasi indikator rentang (1-3)
      final spotY = g < 70 ? 1.0 : (g > 140 ? 3.0 : 2.0);
      return FlSpot(i.toDouble(), spotY);
    });
  }

  /// Titik mini line chart untuk kartu Detak Jantung (BPM)
  List<FlSpot> get bpmSpots {
    final sourceList = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    final validList = sourceList.where((m) => m.ppgHeartRate > 0).toList();
    if (validList.isEmpty) {
      return const [FlSpot(0, 72), FlSpot(1, 76), FlSpot(2, 74), FlSpot(3, 78)];
    }
    final latestFour = validList.take(5).toList().reversed.toList();
    if (latestFour.length == 1) {
      final val = latestFour.first.ppgHeartRate.toDouble();
      return [FlSpot(0, val), FlSpot(1, val)];
    }
    return List.generate(latestFour.length, (i) {
      return FlSpot(i.toDouble(), latestFour[i].ppgHeartRate.toDouble());
    });
  }

  /// Nilai ketinggian suhu tubuh (15 - 40 px) untuk mini chart Suhu
  List<double> get tempHeights {
    final sourceList = filteredMeasurements.isNotEmpty
        ? filteredMeasurements
        : _measurements;
    final validList = sourceList.where((m) => m.skinTempCelsius > 0).toList();
    if (validList.isEmpty) {
      return [25.0, 27.0, 26.0, 28.0, 26.5];
    }
    final latestFive = validList.take(5).toList().reversed.toList();
    return latestFive.map((m) {
      // Normalisasi suhu 34.0°C - 39.0°C ke tinggi 15 - 40 px
      final normalized =
          ((m.skinTempCelsius - 34.0) / (39.0 - 34.0) * 25.0 + 15.0).clamp(
            12.0,
            40.0,
          );
      return normalized;
    }).toList();
  }

  /// Mengubah filter rentang waktu: '6 Jam', 'Day', atau 'Weekly'
  void setTimeFilter(String newFilter) {
    if (_timeFilter != newFilter) {
      _timeFilter = newFilter;
      notifyListeners();
    }
  }

  /// Mengambil data pengukuran riil dari API Backend
  Future<void> fetchMeasurements() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.measurements);
      if (response.statusCode == 200 && response.data is List) {
        final List listData = response.data;
        _measurements = listData
            .map((item) => MeasurementModel.fromJson(item))
            .toList();

        // Urutkan dari data paling baru ke terlama
        _measurements.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        if (_measurements.isNotEmpty) {
          _liveGlucose = _measurements.first.glucoseEstimated;
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Menyimpan data pengukuran baru ke API Backend & otomatis menyinkronkan riwayat
  Future<bool> saveMeasurement({
    required int patientId,
    required double glucose,
    required int heartRate,
    required double temperature,
  }) async {
    try {
      final payload = {
        'patient_id': patientId,
        'glucose_estimated': glucose,
        'ppg_heart_rate': heartRate,
        'skin_temp_celsius': temperature,
        'created_at': DateTime.now().toIso8601String(),
        'source': 'wifi',
      };

      final response = await _apiService.post(
        ApiConstants.measurements,
        data: payload,
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        await fetchMeasurements();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('[MeasurementProvider] Error saveMeasurement: $e');
      return false;
    }
  }

  /// Menghapus satu item pengukuran dari backend dan state lokal
  Future<bool> deleteMeasurement(int? id, {DateTime? createdAt}) async {
    bool deletedOnServer = false;
    if (id != null && id > 0) {
      try {
        final response = await _apiService.delete(
          '${ApiConstants.measurements}/$id',
        );
        if (response.statusCode == 200 || response.statusCode == 204) {
          deletedOnServer = true;
        }
      } catch (e) {
        debugPrint('[MeasurementProvider] Error deleteMeasurement: $e');
      }
    }

    // Selalu sinkronkan penghapusan pada state list lokal aplikasi
    final initialCount = _measurements.length;
    _measurements.removeWhere((m) =>
        (id != null && m.id == id) ||
        (createdAt != null && m.createdAt.isAtSameMomentAs(createdAt)));

    if (_measurements.length < initialCount) {
      notifyListeners();
      return true;
    }

    return deletedOnServer;
  }

  /// Memperbarui nilai glukosa secara langsung saat selesai pengukuran di perangkat
  void updateGlucose(double newValue) {
    _liveGlucose = newValue;
    // Buat entri lokal sementara agar langsung muncul di dashboard
    final newEntry = MeasurementModel(
      glucoseEstimated: newValue,
      status: newValue > 200
          ? 'hiperglikemia'
          : (newValue < 70 ? 'hipoglikemia' : 'normal'),
      ppgHeartRate: 75,
      skinTempCelsius: 36.5,
      createdAt: DateTime.now(),
    );
    _measurements.insert(0, newEntry);
    notifyListeners();
  }
}
