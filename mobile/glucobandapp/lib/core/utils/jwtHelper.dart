import 'dart:convert';

class JwtHelper {
  /// Mengurai payload JWT tanpa library pihak ketiga
  static Map<String, dynamic>? parseJwt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      String output = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (output.length % 4) {
        case 0:
          break;
        case 2:
          output += '==';
          break;
        case 3:
          output += '=';
          break;
        default:
          return null;
      }
      final decoded = utf8.decode(base64Url.decode(output));
      return json.decode(decoded) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Memeriksa apakah token JWT telah kedaluwarsa
  static bool isExpired(String token, {int bufferSeconds = 30}) {
    final payload = parseJwt(token);
    if (payload == null || !payload.containsKey('exp')) return true;
    final exp = payload['exp'];
    final expSeconds = exp is int ? exp : int.tryParse(exp.toString()) ?? 0;
    if (expSeconds == 0) return true;

    final expDate = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
    return DateTime.now().isAfter(expDate.subtract(Duration(seconds: bufferSeconds)));
  }
}
