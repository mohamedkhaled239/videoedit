class VideoProject {
  const VideoProject({
    required this.id,
    required this.name,
    required this.videoPath,
    required this.thumbnailPath,
    required this.durationMs,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String videoPath;
  final String? thumbnailPath;
  final int durationMs;
  final DateTime updatedAt;

  VideoProject copyWith({
    String? name,
    String? videoPath,
    String? thumbnailPath,
  }) {
    return VideoProject(
      id: id,
      name: name ?? this.name,
      videoPath: videoPath ?? this.videoPath,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      durationMs: durationMs,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'videoPath': videoPath,
    'thumbnailPath': thumbnailPath,
    'durationMs': durationMs,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory VideoProject.fromJson(Map<String, dynamic> json) => VideoProject(
    id: json['id'] as String,
    name: json['name'] as String,
    videoPath: json['videoPath'] as String,
    thumbnailPath: json['thumbnailPath'] as String?,
    durationMs: json['durationMs'] as int,
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );
}
