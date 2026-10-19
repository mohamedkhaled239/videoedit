class AppConfig {
  final bool enableAds;

  AppConfig({this.enableAds = true});

  factory AppConfig.fromFirestore(Map<String, dynamic> data) {
    return AppConfig(enableAds: data['enableAds'] ?? true);
  }

  Map<String, dynamic> toMap() {
    return {'enableAds': enableAds};
  }

  // Default config
  factory AppConfig.defaultConfig() {
    return AppConfig(enableAds: true);
  }
}
