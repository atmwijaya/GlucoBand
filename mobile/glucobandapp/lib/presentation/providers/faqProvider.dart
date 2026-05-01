import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../../core/constants/apiConstant.dart';
import '../../data/datasources/remote/faqRemote.dart';
import '../../data/repositories/faqRepository.dart';
import '../../data/models/faqModel.dart';

class FaqProvider extends ChangeNotifier {
  List<FaqModel> _faqs = [];
  bool _isLoading = false;

  List<FaqModel> get faqs => _faqs;
  bool get isLoading => _isLoading;

  Future<void> fetchFaqs(String token) async {
    _isLoading = true;
    notifyListeners();

    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ));

    try {
      final repo = FaqRepository(FaqRemoteDataSource(dio));
      final data = await repo.getFaqs();
      _faqs = data.map((json) => FaqModel.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching FAQs: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}