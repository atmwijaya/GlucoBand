import 'package:flutter/material.dart';

class MeasurementProvider extends ChangeNotifier {
  double _latestGlucose = 120.55;
  double get latestGlucose => _latestGlucose;

  void updateGlucose(double newValue) {
    _latestGlucose = newValue;
    notifyListeners();
  }
}