import '../../../services/secureStorageService.dart';
import '../../models/userModel.dart';

class AuthLocalDataSource {
  final SecureStorageService _secureStorage;

  AuthLocalDataSource({SecureStorageService? secureStorage})
      : _secureStorage = secureStorage ?? SecureStorageService();

  Future<void> saveSession({required String token, required UserModel user}) async {
    await _secureStorage.saveToken(token);
    await _secureStorage.saveUserData(
      id: user.id,
      name: user.name,
      email: user.email,
      role: user.role,
    );
  }

  Future<String?> getToken() => _secureStorage.getToken();

  Future<UserModel?> getUser() async {
    final data = await _secureStorage.getUserData();
    if (data['name'] == null || data['email'] == null) return null;
    return UserModel(
      id: int.tryParse(data['id'] ?? '0') ?? 0,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'pasien',
    );
  }

  Future<void> clearSession() => _secureStorage.clearAll();

  Future<bool> isLoggedIn() => _secureStorage.hasToken();
}

