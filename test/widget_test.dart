import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:videoedit/models/app_config.dart';
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
      temporaryDirectoryProvider: () async => temporaryDirectory,
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
        temporaryDirectoryProvider: () async => temporaryDirectory,
      );

      final downloaded = await provider.downloadDocument(
        'https://api.example.com/download?id=video-123',
      );

      expect(downloaded, isNotNull);
      expect(downloaded!.fileName, endsWith('.mp4'));
      expect(downloaded.kind, DownloadedFileKind.video);
    },
  );

  test('remote settings default to disabled and parse resolver values', () {
    expect(AppConfig.defaultConfig().enableVideoDownload, isFalse);
    expect(AppConfig.defaultConfig().enableAds, isFalse);
    expect(AppConfig.defaultConfig().resolverEnabled, isFalse);

    final config = AppConfig.fromFirestore({
      'evd': true,
      'rap': ' https://resolver.example.com/ ',
      'rah': 'resolver.p.rapidapi.com',
      'rak': 'secret',
      'enableAds': true,
    });
    expect(config.enableVideoDownload, isTrue);
    expect(config.rapidApiBaseUrl, 'https://resolver.example.com/');
    expect(config.resolverEnabled, isTrue);
    expect(config.enableAds, isTrue);
  });

  test('extracts the first HTTP URL from pasted text', () {
    final provider = DocumentDownloadProvider();
    expect(
      provider.extractUrl('شاهد الفيديو (https://example.com/watch/123), الآن'),
      Uri.parse('https://example.com/watch/123'),
    );
    expect(
      provider.extractUrl('files.example.com/movie.mp4'),
      Uri.parse('https://files.example.com/movie.mp4'),
    );
  });

  test('resolves a social URL with the documented RapidAPI contract', () async {
    late http.Request capturedRequest;
    final provider = DocumentDownloadProvider(
      clientFactory: () => MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          '''{"thumbnail":"https://cdn.example/thumb.jpg","medias":[{"url":"https://cdn.example/video.mp4","quality":"720p","extension":"mp4","type":"video"}],"error":false}''',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    provider.updateConfig(
      const AppConfig(
        enableVideoDownload: true,
        rapidApiBaseUrl: 'https://resolver.example.com',
        rapidApiHost: 'resolver.p.rapidapi.com',
        rapidApiKey: 'secret',
      ),
    );

    final options = await provider.resolveMedia(
      'https://social.example.com/post/123',
    );

    expect(capturedRequest.method, 'POST');
    expect(capturedRequest.url.path, '/v1/social/autolink');
    expect(capturedRequest.headers['x-rapidapi-key'], 'secret');
    expect(
      capturedRequest.headers['x-rapidapi-host'],
      'resolver.p.rapidapi.com',
    );
    expect(capturedRequest.body, contains('social.example.com'));
    expect(options, hasLength(1));
    expect(options!.single.label, 'Video · 720p');
    expect(options.single.fileExtension, 'mp4');
    expect(
      options.single.thumbnail,
      Uri.parse('https://cdn.example/thumb.jpg'),
    );
  });
}
