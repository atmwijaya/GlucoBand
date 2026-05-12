import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profileProvider.dart';
import '../providers/authProvider.dart';
import '../providers/predictionProvider.dart';
import 'predictionResult.dart';

class PredictionPage extends StatefulWidget {
  const PredictionPage({Key? key}) : super(key: key);

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();

  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  final _sysController = TextEditingController();
  final _diaController = TextEditingController();
  final _bloodGlucoseController = TextEditingController();

  final _glucoseControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  String _gender = 'Laki-laki';
  String _hypertension = 'Tidak';
  String _heartDisease = 'Tidak';
  String _smoking = 'Tidak Pernah';
  double _bmi = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  void _loadProfile() {
    final profileProvider = Provider.of<ProfileProvider>(
      context,
      listen: false,
    );
    final profile = profileProvider.profileData;

    if (profile != null) {
      setState(() {
        // Isi data dasar
        if (profile['weight_kg'] != null) {
          _weightController.text = profile['weight_kg'].toString();
        }
        if (profile['height_cm'] != null) {
          _heightController.text = profile['height_cm'].toString();
        }
        if (profile['age'] != null) {
          _ageController.text = profile['age'].toString();
        }
        if (profile['blood_pressure_sys'] != null) {
          _sysController.text = profile['blood_pressure_sys'].toString();
        }
        if (profile['blood_pressure_dia'] != null) {
          _diaController.text = profile['blood_pressure_dia'].toString();
        }

        // Isi dropdowns
        if (profile['gender'] != null) {
          _gender = profile['gender'] == 'L' || profile['gender'] == 'Male'
              ? 'Laki-laki'
              : 'Perempuan';
        }
        if (profile['hypertension'] != null) {
          _hypertension =
              profile['hypertension'] == true || profile['hypertension'] == 1
              ? 'Ya'
              : 'Tidak';
        }
        if (profile['heart_disease'] != null) {
          _heartDisease =
              profile['heart_disease'] == true || profile['heart_disease'] == 1
              ? 'Ya'
              : 'Tidak';
        }
        if (profile['smoking_history'] != null) {
          final smokingCode = profile['smoking_history'];
          if (smokingCode == 0)
            _smoking = 'Tidak Pernah';
          else if (smokingCode == 1)
            _smoking = 'Pernah';
          else if (smokingCode == 2)
            _smoking = 'Masih';
        }

        _calculateBMI();
      });
    } else {
      // Jika profile belum ada, coba fetch lagi
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.token != null) {
        profileProvider.fetchProfile(auth.token!);
      }
    }
  }

  void _calculateBMI() {
    final w = double.tryParse(_weightController.text);
    final h = double.tryParse(_heightController.text);
    if (w != null && h != null && h > 0) {
      _bmi = w / ((h / 100) * (h / 100));
    } else {
      _bmi = 0;
    }
    setState(() {});
  }

  void _resetForm() {
    setState(() {
      _weightController.clear();
      _heightController.clear();
      _ageController.clear();
      _sysController.clear();
      _diaController.clear();
      _bloodGlucoseController.clear();

      for (var controller in _glucoseControllers) {
        controller.clear();
      }

      _gender = 'Laki-laki';
      _hypertension = 'Tidak';
      _heartDisease = 'Tidak';
      _smoking = 'Tidak Pernah';
      _bmi = 0;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final predictionProvider = Provider.of<PredictionProvider>(
      context,
      listen: false,
    );

    String genderCode = _gender == 'Laki-laki' ? 'Male' : 'Female';
    int hyperCode = _hypertension == 'Ya' ? 1 : 0;
    int heartCode = _heartDisease == 'Ya' ? 1 : 0;
    int smokingCode = _smoking == 'Tidak Pernah'
        ? 0
        : (_smoking == 'Pernah' ? 1 : 2);

    List<double> glucoseHistory = _glucoseControllers
        .map((c) => double.tryParse(c.text.trim()) ?? 0.0)
        .toList();

    if (glucoseHistory.where((v) => v > 0).length < 3) {
      double lastValid = glucoseHistory.lastWhere(
        (v) => v > 0,
        orElse: () => double.tryParse(_bloodGlucoseController.text) ?? 110.0,
      );

      while (glucoseHistory.where((v) => v > 0).length < 3) {
        glucoseHistory.add(lastValid);
      }
    }

    final inputData = {
      'age': int.tryParse(_ageController.text) ?? 0,
      'gender': genderCode,
      'bmi': _bmi,
      'hypertension': hyperCode,
      'heart_disease': heartCode,
      'smoking_history': smokingCode,
      'blood_glucose_level':
          double.tryParse(_bloodGlucoseController.text) ?? 100,
      'glucose_history': _glucoseControllers
          .map((c) => double.tryParse(c.text) ?? 0)
          .toList(),
    };

    await predictionProvider.fetchRisk(inputData, auth.token!);
    if (!mounted) return;

    if (predictionProvider.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(predictionProvider.error!)));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PredictionResultPage(inputData: inputData),
      ),
    );
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    _sysController.dispose();
    _diaController.dispose();
    _bloodGlucoseController.dispose();
    for (var c in _glucoseControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Prediksi Kesehatan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.1),
                      const Color(0xFF60A5FA).withOpacity(0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF3B82F6)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Data diambil dari profil kesehatan Anda. Anda dapat mengubah atau mereset form di bawah ini.',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Tombol Reset
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _resetForm,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Reset Form'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ),

              const SizedBox(height: 8),

              _buildTextField(
                _weightController,
                'Berat Badan (kg)',
                Icons.monitor_weight_outlined,
                TextInputType.number,
                (_) => _calculateBMI(),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                _heightController,
                'Tinggi Badan (cm)',
                Icons.height,
                TextInputType.number,
                (_) => _calculateBMI(),
              ),

              if (_bmi > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          'BMI:',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _bmi.toStringAsFixed(1),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _bmi > 25 ? Colors.orange : Colors.green,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _bmi > 25 ? 'Overweight' : 'Normal',
                          style: TextStyle(
                            color: _bmi > 25 ? Colors.orange : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),
              _buildTextField(
                _ageController,
                'Usia',
                Icons.calendar_today,
                TextInputType.number,
              ),

              const SizedBox(height: 12),
              _buildDropdown(
                'Hipertensi',
                _hypertension,
                ['Tidak', 'Ya'],
                (val) => setState(() => _hypertension = val!),
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                'Penyakit Jantung',
                _heartDisease,
                ['Tidak', 'Ya'],
                (val) => setState(() => _heartDisease = val!),
              ),
              const SizedBox(height: 12),
              _buildDropdown('Jenis Kelamin', _gender, [
                'Laki-laki',
                'Perempuan',
              ], (val) => setState(() => _gender = val!)),
              const SizedBox(height: 12),
              _buildDropdown('Riwayat Merokok', _smoking, [
                'Tidak Pernah',
                'Pernah',
                'Masih',
              ], (val) => setState(() => _smoking = val!)),

              const SizedBox(height: 12),
              _buildTextField(
                _bloodGlucoseController,
                'Glukosa Darah Saat Ini (mg/dL)',
                Icons.monitor_heart_outlined,
                TextInputType.number,
              ),

              const SizedBox(height: 24),
              const Text(
                'Riwayat 3 Pengukuran Gula Darah (mg/dL)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: i == 0 ? 0 : 6,
                        right: i == 2 ? 0 : 6,
                      ),
                      child: _buildTextField(
                        _glucoseControllers[i],
                        'Ke-${i + 1}',
                        null,
                        TextInputType.number,
                        null,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.insights, color: Colors.white),
                  label: const Text(
                    'Prediksi Sekarang',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData? icon,
    TextInputType? type, [
    Function(String)? onChanged,
  ]) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null
            ? Icon(icon, color: const Color(0xFF64748B))
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?)? onChanged,
  ) {
    final effectiveValue = items.contains(value) ? value : items.first;

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: (val) {
        if (val != null) onChanged?.call(val);
      },
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
