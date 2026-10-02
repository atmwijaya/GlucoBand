import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/predictionProvider.dart';
import '../providers/authProvider.dart';
import '../providers/profileProvider.dart';

class PredictionHistoryPage extends StatefulWidget {
  const PredictionHistoryPage({super.key});

  @override
  State<PredictionHistoryPage> createState() => _PredictionHistoryPageState();
}

class _PredictionHistoryPageState extends State<PredictionHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHistory();
    });
  }

  Future<void> _loadHistory() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final profile = Provider.of<ProfileProvider>(context, listen: false);
    final prediction = Provider.of<PredictionProvider>(context, listen: false);

    if (profile.profileData != null && profile.profileData!['id'] != null) {
      await prediction.fetchHistory(profile.profileData!['id'], auth.token!);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      DateTime dt;
      try {
        dt = DateTime.parse(dateStr).toLocal();
      } catch (_) {
        dt = HttpDate.parse(dateStr).toLocal();
      }
      return DateFormat('dd MMM yyyy, HH:mm').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        title: const Text('Riwayat Prediksi'),
      ),
      body: Consumer<PredictionProvider>(
        builder: (context, provider, child) {
          if (provider.loadingHistory) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF613EEA)));
          }

          if (provider.history.isEmpty) {
            return const Center(
              child: Text(
                'Belum ada riwayat prediksi',
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.history.length,
            itemBuilder: (context, index) {
              final item = provider.history[index];
              final formattedDate = _formatDate(item['created_at']);

              double lastGlucose = 0;
              if (item['predicted_values'] != null && item['predicted_values'] is List) {
                final values = item['predicted_values'] as List;
                if (values.isNotEmpty) {
                   final lastVal = values.last;
                   if (lastVal is Map && lastVal.containsKey('glucose')) {
                     lastGlucose = (lastVal['glucose'] as num).toDouble();
                   }
                }
              }

              return Dismissible(
                key: Key(item['id'].toString()),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text("Hapus Riwayat"),
                        content: const Text("Anda yakin ingin menghapus data ini?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text("Batal"),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      );
                    },
                  );
                },
                onDismissed: (direction) {
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  provider.deleteHistoryItem(item['id'], auth.token!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Riwayat berhasil dihapus')),
                  );
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                child: Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.only(left: 16, right: 8, top: 8, bottom: 8),
                    title: Text(
                      formattedDate,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    subtitle: const Text('Prediksi 6 Jam'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${lastGlucose.toStringAsFixed(1)} mg/dL',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: lastGlucose > 140 
                                ? Colors.red 
                                : lastGlucose < 70 
                                    ? Colors.orange 
                                    : Colors.green,
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () async {
                            final bool? confirm = await showDialog<bool>(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Hapus Riwayat"),
                                  content: const Text("Anda yakin ingin menghapus data ini?"),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text("Batal"),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text("Hapus", style: TextStyle(color: Colors.red)),
                                    ),
                                  ],
                                );
                              },
                            );

                            if (confirm == true) {
                              if (!context.mounted) return;
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              provider.deleteHistoryItem(item['id'], auth.token!);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Riwayat berhasil dihapus')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
