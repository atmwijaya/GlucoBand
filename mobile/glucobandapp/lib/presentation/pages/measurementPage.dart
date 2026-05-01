import 'package:flutter/material.dart';
import 'measurementResult.dart';

class MeasurementPage extends StatelessWidget {
  const MeasurementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengukuran Gula Darah')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.watch, size: 100, color: Colors.blue),
            const SizedBox(height: 20),
            const Text('GlucoBand Siap', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            const Text('Pastikan sensor menempel dengan baik.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const MeasurementResultPage()));
              },
              icon: const Icon(Icons.flash_on),
              label: const Text('Mulai Ukur'),
            ),
          ],
        ),
      ),
    );
  }
}