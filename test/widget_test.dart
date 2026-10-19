import 'package:flutter_test/flutter_test.dart';
import 'package:videoedit/models/video_project.dart';
import 'package:videoedit/utils/video_editing_rules.dart';

void main() {
  group('trim range validation', () {
    test('accepts a valid selection inside the source duration', () {
      expect(
        VideoEditingRules.isValidTrimRange(
          startMs: 1000,
          endMs: 5000,
          durationMs: 8000,
        ),
        isTrue,
      );
    });

    test('rejects inverted, tiny, and out-of-bounds selections', () {
      expect(
        VideoEditingRules.isValidTrimRange(
          startMs: 5000,
          endMs: 1000,
          durationMs: 8000,
        ),
        isFalse,
      );
      expect(
        VideoEditingRules.isValidTrimRange(
          startMs: 1000,
          endMs: 1050,
          durationMs: 8000,
        ),
        isFalse,
      );
      expect(
        VideoEditingRules.isValidTrimRange(
          startMs: 0,
          endMs: 9000,
          durationMs: 8000,
        ),
        isFalse,
      );
    });
  });

  test('speed calculation predicts exported duration', () {
    expect(
      VideoEditingRules.speedAdjustedDurationMs(durationMs: 10000, speed: 2),
      5000,
    );
    expect(
      VideoEditingRules.speedAdjustedDurationMs(durationMs: 10000, speed: .5),
      20000,
    );
  });

  test('video project metadata survives persistence round trip', () {
    final project = VideoProject(
      id: 'project-1',
      name: 'رحلة',
      videoPath: '/videos/source.mp4',
      thumbnailPath: '/thumbs/source.jpg',
      durationMs: 12500,
      updatedAt: DateTime.utc(2026, 10, 19),
    );

    final restored = VideoProject.fromJson(project.toJson());
    expect(restored.id, project.id);
    expect(restored.name, project.name);
    expect(restored.videoPath, project.videoPath);
    expect(restored.thumbnailPath, project.thumbnailPath);
    expect(restored.durationMs, project.durationMs);
    expect(restored.updatedAt, project.updatedAt);
  });
}
