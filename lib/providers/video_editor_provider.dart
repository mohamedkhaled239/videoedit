import 'dart:io';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../services/audio_mixing_service.dart';
import '../utils/video_editing_rules.dart';

class VideoEditorProvider extends ChangeNotifier {
  String? _videoPath;
  String? _processedVideoPath;
  String? _thumbnailPath;
  VideoMetadata? _metadata;
  double _exportProgress = 0.0;
  bool _isProcessing = false;
  String? _errorMessage;

  String? get videoPath => _videoPath;
  String? get processedVideoPath => _processedVideoPath;
  String? get thumbnailPath => _thumbnailPath;
  VideoMetadata? get metadata => _metadata;
  double get exportProgress => _exportProgress;
  bool get isProcessing => _isProcessing;
  String? get errorMessage => _errorMessage;

  Future<bool> cancelProcessing() async {
    if (!_isProcessing) return false;
    final cancelled = await VideoEditorBuilder.cancel();
    if (cancelled) {
      _isProcessing = false;
      _exportProgress = 0;
      _errorMessage = null;
      notifyListeners();
    }
    return cancelled;
  }

  Future<String> _createOutputPath(String operation) async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final exportDirectory = Directory(
      p.join(documentsDirectory.path, 'videoedit', 'exports'),
    );
    await exportDirectory.create(recursive: true);

    return p.join(
      exportDirectory.path,
      'videoedit_${operation}_${DateTime.now().millisecondsSinceEpoch}.mp4',
    );
  }

  Future<String> _exportAndSave(
    VideoEditorBuilder editor,
    String operation,
  ) async {
    final requestedOutputPath = await _createOutputPath(operation);
    final outputPath = await editor.export(
      outputPath: requestedOutputPath,
      onProgress: (progress) {
        _exportProgress = progress;
        notifyListeners();
      },
    );

    if (outputPath == null || outputPath.isEmpty) {
      throw Exception('لم يتم إنشاء ملف الملف المعدل');
    }

    return _completeExport(outputPath);
  }

  Future<String> _completeExport(String outputPath) async {
    final outputFile = File(outputPath);
    if (!await outputFile.exists() || await outputFile.length() == 0) {
      throw Exception('ملف الملف الناتج غير صالح');
    }

    // Saving is part of a successful edit. Do not report success until the
    // processed file is actually visible in the device gallery.
    await Gal.putVideo(outputPath, album: 'videoedit');

    _videoPath = outputPath;
    _processedVideoPath = outputPath;
    _exportProgress = 1.0;

    // Refreshing preview data is useful but should not invalidate a video that
    // has already been exported and saved successfully.
    try {
      final refreshedEditor = VideoEditorBuilder(videoPath: outputPath);
      _metadata = await refreshedEditor.getVideoMetadata();
      _thumbnailPath = await refreshedEditor.generateThumbnail(
        positionMs: 1000,
        quality: 85,
        width: 320,
        height: 240,
      );
    } catch (_) {}

    return outputPath;
  }

  /// Applies the selected audio gains and, when chosen, loops background music
  /// for the duration of the video before exporting it as a new MP4.
  Future<String?> mixAudio({
    required double originalVolume,
    String? musicPath,
    required double musicVolume,
  }) async {
    if (_videoPath == null) {
      _errorMessage = 'اختر فيديو أولًا';
      notifyListeners();
      return null;
    }
    if (!AudioMixingService.isSupported) {
      _errorMessage = 'خلط الصوت مدعوم حاليًا على iPhone وiPad فقط.';
      notifyListeners();
      return null;
    }
    if (musicPath != null) {
      final music = File(musicPath);
      if (!await music.exists() || await music.length() == 0) {
        _errorMessage = 'ملف الموسيقى غير متاح أو فارغ.';
        notifyListeners();
        return null;
      }
    }

    try {
      _isProcessing = true;
      _exportProgress = 0;
      _errorMessage = null;
      notifyListeners();

      final outputPath = await _createOutputPath('audio');
      final mixedPath = await AudioMixingService.exportMix(
        videoPath: _videoPath!,
        outputPath: outputPath,
        originalVolume: originalVolume,
        musicPath: musicPath,
        musicVolume: musicVolume,
      );
      final completedPath = await _completeExport(mixedPath);
      _isProcessing = false;
      notifyListeners();
      return completedPath;
    } catch (error, stackTrace) {
      _errorMessage =
          'تعذّر تصدير الصوت: ${error.toString().replaceFirst('Exception: ', '')}';
      debugPrint('Audio mix failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> loadVideo(String path) async {
    try {
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('الملف غير موجود أو فارغ');
      }
      _videoPath = path;
      _processedVideoPath = null;
      _errorMessage = null;

      final editor = VideoEditorBuilder(videoPath: path);
      _metadata = await editor.getVideoMetadata();

      _thumbnailPath = await editor.generateThumbnail(
        positionMs: 1000,
        quality: 85,
        width: 320,
        height: 240,
      );

      notifyListeners();
    } catch (e) {
      _errorMessage = 'خطأ في تحميل الملف: $e';
      notifyListeners();
      rethrow;
    }
  }

  Future<String?> trimVideo(int startMs, int endMs) async {
    try {
      final duration = _metadata?.duration ?? 0;
      if (_videoPath == null || duration <= 0) {
        throw Exception('لا يوجد فيديو صالح للقص');
      }
      if (!VideoEditingRules.isValidTrimRange(
        startMs: startMs,
        endMs: endMs,
        durationMs: duration,
      )) {
        throw Exception('نطاق القص غير صالح');
      }
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      final editor = VideoEditorBuilder(
        videoPath: _videoPath!,
      ).trim(startTimeMs: startMs, endTimeMs: endMs);

      final outputPath = await _exportAndSave(editor, 'trim');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في قص الملف: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> mergeVideos(String mainPath, List<String> otherPaths) async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      _errorMessage = null;
      notifyListeners();

      final uniqueOtherPaths = otherPaths
          .where((path) => path != mainPath)
          .toSet()
          .toList();
      if (uniqueOtherPaths.isEmpty) {
        throw Exception('اختر مقطعًا إضافيًا واحدًا على الأقل');
      }

      final allPaths = [mainPath, ...uniqueOtherPaths];
      for (final path in allPaths) {
        final file = File(path);
        if (!await file.exists() || await file.length() == 0) {
          throw Exception('أحد المقاطع غير موجود أو غير صالح');
        }

        try {
          final metadata = await VideoEditorBuilder(
            videoPath: path,
          ).getVideoMetadata();
          if (metadata.duration <= 0) {
            throw Exception('مدة المقطع غير صالحة');
          }
        } catch (_) {
          throw Exception('أحد المقاطع غير مدعوم أو تالف');
        }
      }

      final editor = VideoEditorBuilder(
        videoPath: mainPath,
      ).merge(otherVideoPaths: uniqueOtherPaths);

      final outputPath = await _exportAndSave(editor, 'merge');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (error, stackTrace) {
      final details = error.toString().replaceFirst('Exception: ', '');
      _errorMessage = 'تعذّر دمج المقاطع: $details';
      debugPrint('Video merge failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> changeSpeed(double speed) async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      final editor = VideoEditorBuilder(
        videoPath: _videoPath!,
      ).speed(speed: speed);

      final outputPath = await _exportAndSave(editor, 'speed');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في تغيير السرعة: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> removeAudio() async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      final editor = VideoEditorBuilder(videoPath: _videoPath!).removeAudio();

      final outputPath = await _exportAndSave(editor, 'mute');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في إزالة الصوت: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> extractAudio() async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      final editor = VideoEditorBuilder(videoPath: _videoPath!);

      final outputPath = await editor.extractAudio(
        outputPath: '${_videoPath!}_audio.m4a',
      );

      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في استخراج الصوت: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> rotateVideo(RotationDegree degree) async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      final editor = VideoEditorBuilder(
        videoPath: _videoPath!,
      ).rotate(degree: degree);

      final outputPath = await _exportAndSave(editor, 'rotate');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في تدوير الملف: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> cropVideo(VideoAspectRatio aspectRatio) async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      final editor = VideoEditorBuilder(
        videoPath: _videoPath!,
      ).crop(aspectRatio: aspectRatio);

      final outputPath = await _exportAndSave(editor, 'crop');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في اقتصاص الملف: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> compressVideo(VideoResolution resolution) async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      final editor = VideoEditorBuilder(
        videoPath: _videoPath!,
      ).compress(resolution: resolution);

      final outputPath = await _exportAndSave(editor, 'compress');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في ضغط الملف: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> flipVideo(FlipDirection direction) async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      final editor = VideoEditorBuilder(
        videoPath: _videoPath!,
      ).flip(flipDirection: direction);

      final outputPath = await _exportAndSave(editor, 'flip');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في قلب الملف: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> applyMultipleOperations(
    Map<String, dynamic> operations,
  ) async {
    try {
      _isProcessing = true;
      _exportProgress = 0.0;
      notifyListeners();

      VideoEditorBuilder editor = VideoEditorBuilder(videoPath: _videoPath!);

      if (operations.containsKey('trim')) {
        final trim = operations['trim'] as Map<String, int>;
        editor = editor.trim(
          startTimeMs: trim['start']!,
          endTimeMs: trim['end']!,
        );
      }

      if (operations.containsKey('speed')) {
        editor = editor.speed(speed: operations['speed'] as double);
      }

      if (operations.containsKey('removeAudio') &&
          operations['removeAudio'] == true) {
        editor = editor.removeAudio();
      }

      if (operations.containsKey('rotate')) {
        editor = editor.rotate(degree: operations['rotate'] as RotationDegree);
      }

      if (operations.containsKey('crop')) {
        editor = editor.crop(
          aspectRatio: operations['crop'] as VideoAspectRatio,
        );
      }

      if (operations.containsKey('compress')) {
        editor = editor.compress(
          resolution: operations['compress'] as VideoResolution,
        );
      }

      if (operations.containsKey('flip')) {
        editor = editor.flip(
          flipDirection: operations['flip'] as FlipDirection,
        );
      }

      final outputPath = await _exportAndSave(editor, 'edited');

      _processedVideoPath = outputPath;
      _isProcessing = false;
      notifyListeners();
      return outputPath;
    } catch (e) {
      _errorMessage = 'خطأ في تطبيق العمليات: $e';
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }

  Future<String?> generateNewThumbnail(int positionMs) async {
    try {
      final editor = VideoEditorBuilder(videoPath: _videoPath!);

      _thumbnailPath = await editor.generateThumbnail(
        positionMs: positionMs,
        quality: 85,
        width: 320,
        height: 240,
      );

      notifyListeners();
      return _thumbnailPath;
    } catch (e) {
      _errorMessage = 'خطأ في توليد الثامبنيل: $e';
      notifyListeners();
      return null;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void reset() {
    _videoPath = null;
    _processedVideoPath = null;
    _thumbnailPath = null;
    _metadata = null;
    _exportProgress = 0.0;
    _isProcessing = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> saveProcessedVideoToGallery() async {
    if (_processedVideoPath == null) {
      _errorMessage = 'لا يوجد فيديو معدل للحفظ';
      notifyListeners();
      return false;
    }

    try {
      await Gal.putVideo(_processedVideoPath!, album: 'videoedit');
      return true;
    } catch (e) {
      _errorMessage = 'خطأ في حفظ الملف: $e';
      notifyListeners();
      return false;
    }
  }

  String? getProcessedVideoPathForSharing() {
    return _processedVideoPath;
  }
}
