import 'package:flutter/material.dart';

class Article {
  final String title;
  final String description;
  final String imageUrl;
  final String timeToRead;

  Article({
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.timeToRead,
  });
}

class ArticleProvider extends ChangeNotifier {
  List<Article> _articles = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Article> get articles => _articles;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchArticles() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate API call delay
      await Future.delayed(const Duration(seconds: 1));
      
      // Menggunakan Mock Data (Statis) dengan tema Kemenkes / Kesehatan
      // Karena API Kemenkes tidak menyediakan JSON publik secara langsung.
      _articles = [
        Article(
          title: 'Tips Mengatur Pola Makan untuk Diabetes',
          description: 'Panduan lengkap memilih nutrisi yang tepat bagi penderita diabetes.',
          imageUrl: 'https://images.unsplash.com/photo-1490645935967-10de6ba17061?q=80&w=2053&auto=format&fit=crop',
          timeToRead: '5 min read',
        ),
        Article(
          title: 'Terobosan Baru Teknologi Sensor Glukosa',
          description: 'Inovasi terbaru dalam pemantauan kadar gula darah tanpa rasa sakit.',
          imageUrl: 'https://images.unsplash.com/photo-1579684385127-1ef15d508118?q=80&w=2080&auto=format&fit=crop',
          timeToRead: '8 min read',
        ),
        Article(
          title: 'Aktivitas Fisik yang Dianjurkan Kemenkes',
          description: 'Berolahraga dengan aman untuk menjaga kestabilan glukosa darah.',
          imageUrl: 'https://images.unsplash.com/photo-1571019614242-c5c5dee9f50b?q=80&w=2070&auto=format&fit=crop',
          timeToRead: '6 min read',
        ),
      ];
    } catch (e) {
      _errorMessage = 'Gagal memuat artikel.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
