import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:videoedit/models/video_project.dart';
import 'package:videoedit/providers/document_download_provider.dart';
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

  test('downloads a direct MP4 video and preserves its media kind', () async {
    final temporaryDirectory = await Directory.systemTemp.createTemp(
      'videoedit_download_test_',
    );
    addTearDown(() => temporaryDirectory.delete(recursive: true));

    final mp4Header = <int>[
      0,
      0,
      0,
      24,
      ...'ftypisom'.codeUnits,
      0,
      0,
      2,
      0,
      ...'isomiso2'.codeUnits,
    ];
    final provider = DocumentDownloadProvider(
      clientFactory: () => MockClient(
        (_) async => http.Response.bytes(
          mp4Header,
          200,
          headers: {
            'content-type': 'video/mp4',
            'content-length': '${mp4Header.length}',
          },
        ),
      ),
      documentsDirectoryProvider: () async => temporaryDirectory,
    );

    final downloaded = await provider.downloadDocument(
      'https://files.example.com/sample.mp4',
    );

    expect(downloaded, isNotNull);
    expect(downloaded!.kind, DownloadedFileKind.video);
    expect(downloaded.fileName, 'sample.mp4');
    expect(await File(downloaded.path).readAsBytes(), mp4Header);
  });

  test(
    'detects an MP4 response from an API URL without an extension',
    () async {
      final temporaryDirectory = await Directory.systemTemp.createTemp(
        'videoedit_api_download_test_',
      );
      addTearDown(() => temporaryDirectory.delete(recursive: true));
      final mp4Header = <int>[0, 0, 0, 24, ...'ftypisom'.codeUnits];
      final provider = DocumentDownloadProvider(
        clientFactory: () => MockClient(
          (_) async => http.Response.bytes(
            mp4Header,
            200,
            headers: {
              'content-type': 'application/octet-stream',
              'content-length': '${mp4Header.length}',
            },
          ),
        ),
        documentsDirectoryProvider: () async => temporaryDirectory,
      );

      final downloaded = await provider.downloadDocument(
        'https://api.example.com/download?id=video-123',
      );

      expect(downloaded, isNotNull);
      expect(downloaded!.fileName, endsWith('.mp4'));
      expect(downloaded.kind, DownloadedFileKind.video);
    },
  );
}
