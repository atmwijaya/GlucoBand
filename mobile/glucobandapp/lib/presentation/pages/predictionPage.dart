import 'package:flutter/material.dart';
import 'predictionResult.dart';

class PredictionPage extends StatefulWidget {
  const PredictionPage({Key? key}) : super(key: key);

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage> {
  final _formKey = GlobalKey<FormState>();
  String gender = 'Laki-laki';
  String activity = 'Ringan';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prediksi Kesehatan')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(decoration: const InputDecoration(labelText: 'Berat Badan (kg)'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(decoration: const InputDecoration(labelText: 'Tinggi Badan (cm)'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              TextFormField(decoration: const InputDecoration(labelText: 'Usia'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                value: gender,
                items: ['Laki-laki', 'Perempuan'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => gender = v!),
                decoration: const InputDecoration(labelText: 'Jenis Kelamin'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField(
                value: activity,
                items: ['Ringan', 'Sedang', 'Tinggi'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setState(() => activity = v!),
                decoration: const InputDecoration(labelText: 'Aktivitas Fisik'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PredictionResultPage()));
                  }
                },
                child: const Text('Prediksi Sekarang'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}