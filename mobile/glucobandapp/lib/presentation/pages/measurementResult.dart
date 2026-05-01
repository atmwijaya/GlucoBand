import 'package:flutter/material.dart';

class MeasurementResultPage extends StatelessWidget {
  const MeasurementResultPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasil Pengukuran')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text('120 mg/dL', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
            const Text('Normal', style: TextStyle(fontSize: 18, color: Colors.green)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _infoCard('Detak', '72 BPM'),
                _infoCard('SpO2', '98%'),
                _infoCard('Suhu', '36.5°C'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
      ),
    );
  }
}