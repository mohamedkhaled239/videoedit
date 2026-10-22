class ResolvedMedia {
  const ResolvedMedia({
    required this.label,
    required this.url,
    required this.kind,
    this.fileExtension,
    this.thumbnail,
  });

  final String label;
  final Uri url;
  final String kind;
  final String? fileExtension;
  final Uri? thumbnail;

  factory ResolvedMedia.fromJson(Map<String, dynamic> json, {Uri? thumbnail}) {
    final rawUrl = json['url'];
    final url = rawUrl is String ? Uri.tryParse(rawUrl.trim()) : null;
    if (url == null ||
        !const {'http', 'https'}.contains(url.scheme) ||
        url.host.isEmpty) {
      throw const FormatException('Invalid media URL');
    }

    final type = _clean(json['type']) ?? 'file';
    final quality = _clean(json['quality']);
    final labelParts = <String>[_titleCase(type)];
    if (quality != null && quality.toLowerCase() != type.toLowerCase()) {
      labelParts.add(quality);
    }

    final extension = _clean(
      json['extension'],
    )?.replaceFirst(RegExp(r'^\.'), '').toLowerCase();
    return ResolvedMedia(
      label: labelParts.join(' · '),
      url: url,
      kind: type.toLowerCase(),
      fileExtension: extension,
      thumbnail: thumbnail,
    );
  }

  static String? _clean(Object? value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static String _titleCase(String value) =>
      '${value[0].toUpperCase()}${value.substring(1)}';
}
