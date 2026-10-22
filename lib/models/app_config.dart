class AppConfig {
  const AppConfig({
    this.enableVideoDownload = false,
    this.rapidApiBaseUrl,
    this.rapidApiHost,
    this.rapidApiKey,
    this.enableAds = false,
  });

  final bool enableVideoDownload;
  final String? rapidApiBaseUrl;
  final String? rapidApiHost;
  final String? rapidApiKey;
  final bool enableAds;

  bool get resolverEnabled =>
      enableVideoDownload &&
      rapidApiBaseUrl != null &&
      rapidApiHost != null &&
      rapidApiKey != null;

  factory AppConfig.fromFirestore(Map<String, dynamic> data) {
    String? optionalString(String shortKey, String legacyKey) {
      for (final key in [shortKey, legacyKey]) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      return null;
    }

    return AppConfig(
      enableVideoDownload:
          data['evd'] == true || data['enableVideoDownload'] == true,
      rapidApiBaseUrl: optionalString('rap', 'rapidApiBaseUrl'),
      rapidApiHost: optionalString('rah', 'rapidApiHost'),
      rapidApiKey: optionalString('rak', 'rapidApiKey'),
      enableAds: data['enableAds'] == true,
    );
  }

  factory AppConfig.defaultConfig() => const AppConfig();
}
