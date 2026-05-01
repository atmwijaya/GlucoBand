import '../../data/datasources/remote/faqRemote.dart';

class FaqRepository {
  final FaqRemoteDataSource _remote;

  FaqRepository(this._remote);

  Future<List<Map<String, dynamic>>> getFaqs() => _remote.getFaqs();
}