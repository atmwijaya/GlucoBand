import 'package:flutter/material.dart';

class PredictionResultPage extends StatelessWidget {
  const PredictionResultPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Prediksi')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text('Risiko Diabetes Rendah', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Skor Risiko: 0.23'),
            const Divider(height: 32),
            const Text('Tren Gula Darah 6 Jam Ke Depan'),
            const SizedBox(height: 8),
            Container(
              height: 200,
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
              child: const Center(child: Text('Grafik Tren')),
            ),
          ],
        ),
      ),
    );
  }
}