import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/measurementProvider.dart';
import '../../data/models/measurementModel.dart';

class MeasurementHistoryPage extends StatefulWidget {
  const MeasurementHistoryPage({super.key});

  @override
  State<MeasurementHistoryPage> createState() => _MeasurementHistoryPageState();
}

class _MeasurementHistoryPageState extends State<MeasurementHistoryPage> {
  String _statusFilter = 'Semua'; // Pilihan: 'Semua', 'Normal', 'Hiperglikemia', 'Hipoglikemia'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MeasurementProvider>(context, listen: false).fetchMeasurements();
    });
  }

  String _formatDate(DateTime dt) {
    try {
      return DateFormat('dd MMM yyyy, HH:mm').format(dt.toLocal());
    } catch (_) {
      return dt.toString();
    }
  }

  Color _getStatusColor(String status, double glucose) {
    final s = status.toLowerCase();
    if (s.contains('hiper') || glucose > 200) {
      return const Color(0xFFEF4444);
    }
    if (s.contains('hipo') || (glucose < 70 && glucose > 0)) {
      return const Color(0xFFF59E0B);
    }
    return const Color(0xFF10B981);
  }

  String _formatStatusLabel(String status, double glucose) {
    final s = status.toLowerCase();
    if (s.contains('hiper') || glucose > 200) return 'Hiperglikemia';
    if (s.contains('hipo') || (glucose < 70 && glucose > 0)) return 'Hipoglikemia';
    return 'Normal';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0.5,
        title: const Text(
          'Riwayat Pengukuran',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: () {
              Provider.of<MeasurementProvider>(context, listen: false).fetchMeasurements();
            },
          ),
        ],
      ),
      body: Consumer<MeasurementProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.measurements.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF613EEA)),
            );
          }

          final allMeasurements = provider.measurements;

          // Filter berdasarkan status kategori
          final filteredList = allMeasurements.where((m) {
            if (_statusFilter == 'Semua') return true;
            final label = _formatStatusLabel(m.status, m.glucoseEstimated);
            return label == _statusFilter;
          }).toList();

          return RefreshIndicator(
            color: const Color(0xFF613EEA),
            onRefresh: () => provider.fetchMeasurements(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Ringkasan Statistik
                if (allMeasurements.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: _buildSummaryCard(allMeasurements),
                    ),
                  ),

                // 2. Filter Kategori Chips
                if (allMeasurements.isNotEmpty)
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          _buildFilterChip('Semua', allMeasurements.length),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Normal',
                            allMeasurements.where((m) => _formatStatusLabel(m.status, m.glucoseEstimated) == 'Normal').length,
                            const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Hiperglikemia',
                            allMeasurements.where((m) => _formatStatusLabel(m.status, m.glucoseEstimated) == 'Hiperglikemia').length,
                            const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                            'Hipoglikemia',
                            allMeasurements.where((m) => _formatStatusLabel(m.status, m.glucoseEstimated) == 'Hipoglikemia').length,
                            const Color(0xFFF59E0B),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 3. Konten Daftar Riwayat
                if (filteredList.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF613EEA).withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.monitor_heart_outlined,
                                size: 54,
                                color: Color(0xFF613EEA),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              allMeasurements.isEmpty
                                  ? 'Belum Ada Riwayat Pengukuran'
                                  : 'Tidak Ada Data untuk Filter Ini',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              allMeasurements.isEmpty
                                  ? 'Lakukan pengukuran dengan GlucoBand lalu tekan tombol "Simpan Data" untuk mencatat ke riwayat.'
                                  : 'Coba pilih kategori filter lain di atas.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final item = filteredList[index];
                          return _buildMeasurementItem(item, provider);
                        },
                        childCount: filteredList.length,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // Widget Kartu Ringkasan Statistik
  Widget _buildSummaryCard(List<MeasurementModel> list) {
    if (list.isEmpty) return const SizedBox.shrink();

    final glucoses = list.map((m) => m.glucoseEstimated).where((g) => g > 0).toList();
    final avg = glucoses.isNotEmpty ? (glucoses.reduce((a, b) => a + b) / glucoses.length).toStringAsFixed(1) : '0';
    final maxG = glucoses.isNotEmpty ? glucoses.reduce((a, b) => a > b ? a : b).toStringAsFixed(0) : '0';
    final minG = glucoses.isNotEmpty ? glucoses.reduce((a, b) => a < b ? a : b).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF613EEA), Color(0xFF7C5CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF613EEA).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Ringkasan Pengukuran',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${list.length} Data',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric('Rata-rata', '$avg mg/dL'),
              ),
              Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.25)),
              Expanded(
                child: _buildSummaryMetric('Tertinggi', '$maxG mg/dL'),
              ),
              Container(width: 1, height: 32, color: Colors.white.withValues(alpha: 0.25)),
              Expanded(
                child: _buildSummaryMetric('Terendah', '$minG mg/dL'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String value) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // Filter Chip
  Widget _buildFilterChip(String label, int count, [Color? activeColor]) {
    final isSelected = _statusFilter == label;
    final color = activeColor ?? const Color(0xFF613EEA);

    return InkWell(
      onTap: () {
        setState(() {
          _statusFilter = label;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Card Item Pengukuran
  Widget _buildMeasurementItem(MeasurementModel item, MeasurementProvider provider) {
    final statusColor = _getStatusColor(item.status, item.glucoseEstimated);
    final statusLabel = _formatStatusLabel(item.status, item.glucoseEstimated);
    final formattedDate = _formatDate(item.createdAt);
    final itemKey = ValueKey(item.id != null ? 'meas_${item.id}' : 'meas_${item.createdAt.millisecondsSinceEpoch}');

    return Dismissible(
      key: itemKey,
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Hapus Riwayat'),
            content: const Text('Apakah Anda yakin ingin menghapus data pengukuran ini?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        final success = await provider.deleteMeasurement(item.id, createdAt: item.createdAt);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Riwayat pengukuran berhasil dihapus' : 'Gagal menghapus data'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(width: 6),
            Text(
              'Hapus',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Baris Atas: Glukosa, Status & Tombol Hapus
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        item.glucoseEstimated.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'mg/dL',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        formattedDate,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                        tooltip: 'Hapus Riwayat',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _confirmDelete(item, provider),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 10),

              // Baris Bawah: Detak Jantung, Suhu Kulit
              Row(
                children: [
                  // Detak Jantung (BPM)
                  _buildSensorPill(
                    Icons.favorite,
                    const Color(0xFFEF4444),
                    '${item.ppgHeartRate} BPM',
                  ),
                  const SizedBox(width: 8),

                  // Suhu Kulit (°C)
                  _buildSensorPill(
                    Icons.thermostat,
                    const Color(0xFFF59E0B),
                    '${item.skinTempCelsius.toStringAsFixed(1)} °C',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorPill(IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(MeasurementModel item, MeasurementProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Riwayat'),
        content: const Text('Apakah Anda yakin ingin menghapus data pengukuran ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await provider.deleteMeasurement(item.id, createdAt: item.createdAt);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success ? 'Data pengukuran berhasil dihapus' : 'Gagal menghapus data',
                    ),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text('Hapus', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
