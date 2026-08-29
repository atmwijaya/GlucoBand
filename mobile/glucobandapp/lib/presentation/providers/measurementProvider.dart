import 'package:flutter/material.dart';

class MeasurementProvider extends ChangeNotifier {
  double _latestGlucose = 120.5;
  final double _glucoseAvg = 115.0;
  final int _rangePercent = 92;
  final double _insulin = 4.0;

  double get latestGlucose => _latestGlucose;
  double get glucoseAvg => _glucoseAvg;
  int get rangePercent => _rangePercent;
  double get insulin => _insulin;

  void updateGlucose(double newValue) {
    _latestGlucose = newValue;
    notifyListeners();
  }
}
