import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/profileProvider.dart';
import '../providers/authProvider.dart';

class EditHealthProfilePage extends StatefulWidget {
  const EditHealthProfilePage({Key? key}) : super(key: key);
  @override
  State<EditHealthProfilePage> createState() => _EditHealthProfilePageState();
}

class _EditHealthProfilePageState extends State<EditHealthProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final weightController = TextEditingController();
  final heightController = TextEditingController();
  final sysController = TextEditingController();
  final diaController = TextEditingController();
  final ageController = TextEditingController();
  String gender = 'L';
  bool diabetesHistory = false;
  bool smokingHistory = false;
  double bmi = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profile = Provider.of<ProfileProvider>(context, listen: false).profileData;
      if (profile != null) {
        weightController.text = '${profile['weight_kg'] ?? ''}';
        heightController.text = '${profile['height_cm'] ?? ''}';
        sysController.text = '${profile['blood_pressure_sys'] ?? ''}';
        diaController.text = '${profile['blood_pressure_dia'] ?? ''}';
        ageController.text = '${profile['age'] ?? ''}';
        gender = profile['gender'] ?? 'L';
        diabetesHistory = profile['diabetes_history'] == 1;
        smokingHistory = profile['smoking_history'] == 1;
        _calculateBMI();
      }
    });
  }

  void _calculateBMI() {
    final w = double.tryParse(weightController.text);
    final h = double.tryParse(heightController.text);
    if (w != null && h != null && h > 0) {
      bmi = w / ((h / 100) * (h / 100));
    } else {
      bmi = 0;
    }
    setState(() {});
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    final data = {
      'age': int.tryParse(ageController.text) ?? 0,
      'gender': gender,
      'weight_kg': double.tryParse(weightController.text),
      'height_cm': double.tryParse(heightController.text),
      'blood_pressure_sys': int.tryParse(sysController.text),
      'blood_pressure_dia': int.tryParse(diaController.text),
      'diabetes_history': diabetesHistory ? 1 : 0,
      'smoking_history': smokingHistory ? 1 : 0,
    };

    final success = await profileProvider.updateProfile(auth.token!, data);
    if (success) {
      if (mounted) Navigator.pop(context);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(profileProvider.errorMessage ?? 'Gagal menyimpan')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Edit Profil Kesehatan'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      bmi > 0 ? bmi.toStringAsFixed(1) : '—',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: bmi > 25
                            ? const Color(0xFFF59E0B)
                            : (bmi > 0 ? const Color(0xFF10B981) : const Color(0xFF94A3B8)),
                      ),
                    ),
                    const Text(
                      'BMI',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    if (bmi > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: bmi > 25
                              ? const Color(0xFFF59E0B).withOpacity(0.1)
                              : const Color(0xFF10B981).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          bmi > 25 ? 'Overweight' : (bmi > 18.5 ? 'Normal' : 'Underweight'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: bmi > 25 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildTextField(weightController, 'Berat Badan (kg)', Icons.monitor_weight_outlined,
                        TextInputType.number, (_) => _calculateBMI()),
                    const SizedBox(height: 14),
                    _buildTextField(heightController, 'Tinggi Badan (cm)', Icons.height,
                        TextInputType.number, (_) => _calculateBMI()),
                    const SizedBox(height: 14),
                    _buildTextField(sysController, 'Tekanan Darah Sistolik', Icons.speed, TextInputType.number),
                    const SizedBox(height: 14),
                    _buildTextField(diaController, 'Tekanan Darah Diastolik', Icons.speed, TextInputType.number),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Input Usia menggunakan TextFormField
                    _buildTextField(ageController, 'Usia (tahun)', Icons.calendar_today, TextInputType.number),
                    const SizedBox(height: 16),
                    // Dropdown Gender
                    _buildDropdown(gender, Icons.person_outline, 'Jenis Kelamin', ['L', 'P'],
                        (v) => setState(() => gender = v!),
                        itemsLabel: const ['Laki-laki', 'Perempuan']),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Riwayat Diabetes', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: const Text('Pernah didiagnosis diabetes melitus'),
                      value: diabetesHistory,
                      activeColor: const Color(0xFF3B82F6),
                      onChanged: (v) => setState(() => diabetesHistory = v),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      title: const Text('Riwayat Merokok', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      subtitle: const Text('Pernah atau sedang merokok'),
                      value: smokingHistory,
                      activeColor: const Color(0xFF3B82F6),
                      onChanged: (v) => setState(() => smokingHistory = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: const Text('Simpan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _buildTextField(TextEditingController controller, String label, IconData icon,
      TextInputType? keyboardType, [void Function(String)? onChanged]) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
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

  Widget _buildDropdown(String value, IconData icon, String label, List<String> items,
      void Function(String?)? onChanged, {List<String>? itemsLabel}) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF64748B)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
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
      items: List.generate(items.length, (i) {
        return DropdownMenuItem(
          value: items[i],
          child: Text(itemsLabel != null ? itemsLabel[i] : items[i]),
        );
      }),
      onChanged: onChanged,
    );
  }
}