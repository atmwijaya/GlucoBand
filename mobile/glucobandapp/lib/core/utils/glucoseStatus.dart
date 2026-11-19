import 'package:flutter/material.dart';

/// Helper kelas untuk klasifikasi status klinis glukosa darah, BPM, dan suhu tubuh
class GlucoseStatusHelper {
  // Rentang glukosa standar klinis (mg/dL)
  static const double hypoThreshold = 70.0;
  static const double normalUpper = 140.0;
  static const double hyperThreshold = 200.0;

  /// Kategori status glukosa: 'hipoglikemia' | 'normal' | 'waspada' | 'hiperglikemia'
  static String getStatusKey(double glucose) {
    if (glucose <= 0) return 'empty';
    if (glucose < hypoThreshold) return 'hipoglikemia';
    if (glucose <= normalUpper) return 'normal';
    if (glucose <= hyperThreshold) return 'waspada';
    return 'hiperglikemia';
  }

  /// Label status glukosa dalam bahasa Indonesia
  static String getLabel(double glucose) {
    if (glucose <= 0) return 'Belum Ada';
    if (glucose < hypoThreshold) return 'Hipoglikemia';
    if (glucose <= normalUpper) return 'Normal';
    if (glucose <= hyperThreshold) return 'Waspada';
    return 'Hiperglikemia';
  }

  /// Subtitle rentang klinis
  static String getSubtitle(double glucose) {
    if (glucose <= 0) return 'Belum ada data pengukuran';
    if (glucose < hypoThreshold) return '< 70 mg/dL (Rendah)';
    if (glucose <= normalUpper) return '70-140 mg/dL (Ideal)';
    if (glucose <= hyperThreshold) return '140-200 mg/dL (Pre-Diabetes/Waspada)';
    return '> 200 mg/dL (Tinggi)';
  }

  /// Warna utama status glukosa
  static Color getColor(double glucose) {
    if (glucose <= 0) return const Color(0xFF64748B);
    if (glucose < hypoThreshold) return const Color(0xFFF59E0B); // Amber
    if (glucose <= normalUpper) return const Color(0xFF10B981); // Emerald Green
    if (glucose <= hyperThreshold) return const Color(0xFFF97316); // Orange Waspada
    return const Color(0xFFEF4444); // Red Hiper
  }

  /// Warna background lembut untuk status badge
  static Color getBgColor(double glucose) {
    if (glucose <= 0) return const Color(0xFFF1F5F9);
    if (glucose < hypoThreshold) return const Color(0xFFFFFBEB);
    if (glucose <= normalUpper) return const Color(0xFFECFDF5);
    if (glucose <= hyperThreshold) return const Color(0xFFFFF7ED);
    return const Color(0xFFFEF2F2);
  }

  /// Posisi meteran (0.0 - 1.0) untuk gauge indicator
  /// Rentang visual skala: 40 mg/dL (0.0) sampai 300 mg/dL (1.0)
  static double getMeterFraction(double glucose) {
    if (glucose <= 0) return 0.0;
    const double minVal = 40.0;
    const double maxVal = 300.0;
    final clamped = glucose.clamp(minVal, maxVal);
    return (clamped - minVal) / (maxVal - minVal);
  }

  /// Warna status detak jantung (BPM)
  static Color getBpmColor(int bpm) {
    if (bpm <= 0) return const Color(0xFF94A3B8);
    if (bpm < 60) return const Color(0xFFF59E0B); // Bradikardia
    if (bpm <= 100) return const Color(0xFF10B981); // Normal (60-100)
    return const Color(0xFFEF4444); // Takikardia (>100)
  }

  /// Label status detak jantung (BPM)
  static String getBpmLabel(int bpm) {
    if (bpm <= 0) return 'Belum Ada';
    if (bpm < 60) return 'Rendah';
    if (bpm <= 100) return 'Normal';
    return 'Tinggi';
  }

  /// Warna status suhu tubuh (°C)
  static Color getTempColor(double temp) {
    if (temp <= 0) return const Color(0xFF94A3B8);
    if (temp < 36.0) return const Color(0xFF0284C7); // Dingin/Hipotermia
    if (temp <= 37.5) return const Color(0xFF10B981); // Normal (36.0 - 37.5)
    return const Color(0xFFEF4444); // Demam (>37.5)
  }

  /// Label status suhu tubuh
  static String getTempLabel(double temp) {
    if (temp <= 0) return 'Belum Ada';
    if (temp < 36.0) return 'Rendah';
    if (temp <= 37.5) return 'Normal';
    return 'Hangat';
  }
}
