import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profileProvider.dart';
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

  final List<TextEditingController> _glucoseControllers = [
    TextEditingController(),
    TextEditingController(),
    TextEditingController(),
  ];

  String _gender = 'L';
  String _activity = 'Ringan';
  double _bmi = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfileData());
  }

  void _loadProfileData() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final profile = profileProvider.profileData;
    if (profile != null) {
      setState(() {
        if (profile['weight_kg'] != null) {
          _weightController.text = profile['weight_kg'].toString();
        }
        if (profile['height_cm'] != null) {
          _heightController.text = profile['height_cm'].toString();
        }
        if (profile['age'] != null) {
          _ageController.text = profile['age'].toString();
        }
        _gender = profile['gender'] ?? 'L';
        _calculateBMI();
      });
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

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    for (final c in _glucoseControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      final Map<String, dynamic> predictionData = {
        'weight': double.parse(_weightController.text),
        'height': double.parse(_heightController.text),
        'age': int.parse(_ageController.text),
        'gender': _gender,
        'activity': _activity,
        'bmi': _bmi,
        'glucoseHistory': [
          double.tryParse(_glucoseControllers[0].text) ?? 0,
          double.tryParse(_glucoseControllers[1].text) ?? 0,
          double.tryParse(_glucoseControllers[2].text) ?? 0,
        ],
      };

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PredictionResultPage(predictionData: predictionData),
        ),
      );
    }
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
              // Kartu informasi
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF3B82F6).withOpacity(0.1),
                      const Color(0xFF60A5FA).withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF3B82F6).withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.info_outline,
                          color: Color(0xFF3B82F6), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Data diambil otomatis dari profil kesehatan Anda. Lengkapi data di bawah untuk hasil prediksi yang akurat.',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bagian Data Dasar
              Row(
                children: const [
                  Icon(Icons.person_outline, size: 20, color: Color(0xFF64748B)),
                  SizedBox(width: 8),
                  Text(
                    'Data Dasar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Field input berat, tinggi, usia, gender, aktivitas (pakai helper)
              _buildTextField(
                controller: _weightController,
                label: 'Berat Badan (kg)',
                icon: Icons.monitor_weight_outlined,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                onChanged: (_) => _calculateBMI(),
              ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _heightController,
                label: 'Tinggi Badan (cm)',
                icon: Icons.height,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                onChanged: (_) => _calculateBMI(),
              ),

              // Tampilkan BMI jika sudah ada
              if (_bmi > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Text('BMI:',
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 14)),
                        const SizedBox(width: 8),
                        Text(
                          _bmi.toStringAsFixed(1),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: _bmi > 25
                                ? Colors.orange
                                : (_bmi > 18.5 ? Colors.green : Colors.blue),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _bmi > 25
                              ? 'Overweight'
                              : (_bmi > 18.5 ? 'Normal' : 'Underweight'),
                          style: TextStyle(
                            fontSize: 13,
                            color: _bmi > 25
                                ? Colors.orange
                                : (_bmi > 18.5 ? Colors.green : Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _buildTextField(
                controller: _ageController,
                label: 'Usia',
                icon: Icons.calendar_today_outlined,
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                value: _gender,
                items: const [
                  {'label': 'Laki-laki', 'value': 'L'},
                  {'label': 'Perempuan', 'value': 'P'},
                ],
                icon: Icons.person_outline,
                label: 'Jenis Kelamin',
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 12),
              _buildDropdown(
                value: _activity,
                items: const [
                  {'label': 'Ringan', 'value': 'Ringan'},
                  {'label': 'Sedang', 'value': 'Sedang'},
                  {'label': 'Tinggi', 'value': 'Tinggi'},
                ],
                icon: Icons.fitness_center_outlined,
                label: 'Aktivitas Fisik',
                onChanged: (v) => setState(() => _activity = v!),
              ),
              const SizedBox(height: 24),

              // Bagian Riwayat Glukosa (opsional)
              Row(
                children: [
                  const Icon(Icons.show_chart,
                      size: 20, color: Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  const Text(
                    'Riwayat 3 Pengukuran Gula Darah',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(opsional)',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: index == 0 ? 0 : 6,
                        right: index == 2 ? 0 : 6,
                      ),
                      child: TextFormField(
                        controller: _glucoseControllers[index],
                        decoration: InputDecoration(
                          labelText: 'Ke-${index + 1}',
                          hintText: 'mg/dL',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: Color(0xFF3B82F6), width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 14),
                          labelStyle: const TextStyle(fontSize: 13),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),

              // Tombol prediksi
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
                        fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
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

  // Widget helper untuk input teks
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
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
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // Widget helper untuk dropdown
  Widget _buildDropdown({
    required String value,
    required List<Map<String, String>> items,
    required IconData icon,
    required String label,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(
              value: e['value'], child: Text(e['label']!)))
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
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
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}