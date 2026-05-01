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
  String gender = 'L';
  int age = 25;
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
        gender = profile['gender'] ?? 'L';
        age = profile['age'] ?? 25;
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
      'age': age,
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
      appBar: AppBar(title: const Text('Edit Profil Kesehatan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Text('BMI:', style: TextStyle(fontSize: 18)),
                      const Spacer(),
                      Text(
                        bmi > 0 ? bmi.toStringAsFixed(1) : '—',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: bmi > 25 ? Colors.orange : (bmi > 0 ? Colors.green : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: weightController,
                decoration: const InputDecoration(labelText: 'Berat Badan (kg)'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateBMI(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: heightController,
                decoration: const InputDecoration(labelText: 'Tinggi Badan (cm)'),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateBMI(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: sysController,
                decoration: const InputDecoration(labelText: 'Tekanan Darah Sistolik'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: diaController,
                decoration: const InputDecoration(labelText: 'Tekanan Darah Diastolik'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('Usia:'),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Slider(
                      value: age.toDouble(),
                      min: 1,
                      max: 120,
                      divisions: 119,
                      label: age.toString(),
                      onChanged: (v) => setState(() => age = v.toInt()),
                    ),
                  ),
                  Text('$age tahun'),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                value: gender,
                items: ['L', 'P'].map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(e == 'L' ? 'Laki-laki' : 'Perempuan'),
                )).toList(),
                onChanged: (v) => setState(() => gender = v!),
                decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Riwayat Diabetes'),
                value: diabetesHistory,
                onChanged: (v) => setState(() => diabetesHistory = v),
              ),
              SwitchListTile(
                title: const Text('Riwayat Merokok'),
                value: smokingHistory,
                onChanged: (v) => setState(() => smokingHistory = v),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _save,
                child: const Text('Simpan'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}