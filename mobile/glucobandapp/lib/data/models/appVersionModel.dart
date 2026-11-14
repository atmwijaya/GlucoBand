class AppVersionModel {
  final String latestVersion;
  final int latestBuildNumber;
  final String downloadUrl;
  final String changelog;
  final bool forceUpdate;

  AppVersionModel({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.downloadUrl,
    required this.changelog,
    required this.forceUpdate,
  });

  factory AppVersionModel.fromJson(Map<String, dynamic> json) {
    return AppVersionModel(
      latestVersion: json['latest_version']?.toString() ?? '1.0.0',
      latestBuildNumber: json['latest_build_number'] is int
          ? json['latest_build_number']
          : int.tryParse(json['latest_build_number']?.toString() ?? '1') ?? 1,
      downloadUrl: json['download_url']?.toString() ?? 'https://glucobandpro.id/download/glucoband.apk',
      changelog: json['changelog']?.toString() ?? 'Pembaruan aplikasi GlucoBand telah tersedia.',
      forceUpdate: json['force_update'] == true,
    );
  }

  bool hasUpdate(int currentBuildNumber, String currentVersion) {
    // 1. Cek nomor build rilis
    if (latestBuildNumber > currentBuildNumber) {
      return true;
    }

    // 2. Cek nomor versi semantik (x.y.z)
    return _isSemanticNewer(latestVersion, currentVersion);
  }

  static bool _isSemanticNewer(String latest, String current) {
    try {
      final latestClean = latest.split('+').first.trim();
      final currentClean = current.split('+').first.trim();

      final latestParts = latestClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = currentClean.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = latestParts.length > currentParts.length ? latestParts.length : currentParts.length;
      for (int i = 0; i < maxLength; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
