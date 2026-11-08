import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Layanan penyimpanan aman berbasis enkripsi hardware.
/// - Android: Menggunakan Android Keystore (AES-256 GCM) via EncryptedSharedPreferences.
/// - iOS: Menggunakan Apple Keychain Services.
class SecureStorageService {
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';

  /// Menyimpan token autentikasi JWT ke Android Keystore
  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  /// Menyimpan Refresh Token JWT ke Android Keystore
  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _keyRefreshToken, value: refreshToken);
  }

  /// Mengambil Refresh Token JWT
  Future<String?> getRefreshToken() async {
    try {
      return await _storage.read(key: _keyRefreshToken);
    } catch (_) {
      return null;
    }
  }

  /// Mengambil token JWT dengan fallback migrasi otomatis dari SharedPreferences lama
  Future<String?> getToken() async {
    try {
      String? token = await _storage.read(key: _keyToken);

      // Fallback: Jika pengguna pernah login di versi lama (sebelum enkripsi Keystore),
      // migrasikan token dari SharedPreferences ke SecureStorage secara transparan.
      if (token == null || token.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final legacyToken = prefs.getString('token');
        if (legacyToken != null && legacyToken.isNotEmpty) {
          token = legacyToken;
          await saveToken(legacyToken);
          await prefs.remove('token'); // Hapus dari plain storage
        }
      }
      return token;
    } catch (_) {
      // Jika terjadi error pada Keystore (misal key invalidated saat device lock diubah),
      // fallback membaca dari storage
      return null;
    }
  }

  /// Menyimpan data profil pengguna terenkripsi
  Future<void> saveUserData({
    required int id,
    required String name,
    required String email,
    required String role,
  }) async {
    await _storage.write(key: _keyUserId, value: id.toString());
    await _storage.write(key: _keyUserName, value: name);
    await _storage.write(key: _keyUserEmail, value: email);
    await _storage.write(key: _keyUserRole, value: role);
  }

  /// Mengambil data pengguna terenkripsi
  Future<Map<String, String?>> getUserData() async {
    try {
      final id = await _storage.read(key: _keyUserId);
      final name = await _storage.read(key: _keyUserName);
      final email = await _storage.read(key: _keyUserEmail);
      final role = await _storage.read(key: _keyUserRole);

      // Fallback ke SharedPreferences jika data lama belum termigrasi
      if (name == null || email == null) {
        final prefs = await SharedPreferences.getInstance();
        return {
          'id': id ?? prefs.getString('user_id'),
          'name': name ?? prefs.getString('user_name'),
          'email': email ?? prefs.getString('user_email'),
          'role': role ?? prefs.getString('user_role') ?? 'pasien',
        };
      }

      return {
        'id': id,
        'name': name,
        'email': email,
        'role': role,
      };
    } catch (_) {
      return {'id': null, 'name': null, 'email': null, 'role': null};
    }
  }

  /// Menghapus seluruh sesi, token, dan kredensial saat logout
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
    } catch (_) {}

    // Bersihkan juga SharedPreferences warisan lama agar tidak ada jejak kredensial
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_id');
      await prefs.remove('user_name');
      await prefs.remove('user_email');
      await prefs.remove('user_role');
    } catch (_) {}
  }

  /// Memeriksa apakah token aktif tersedia
  Future<bool> hasToken() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }
}

