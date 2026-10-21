import 'dart:io';

import 'package:flutter/services.dart';

/// Bridges the audio compositor implemented with AVFoundation on iOS.
///
/// The editor package used by this project can remove an audio track but does
/// not expose gain or background-music composition.  Keeping this operation in
/// one service makes its platform support explicit instead of showing controls
/// which only alter the preview.
class AudioMixingService {
  const AudioMixingService._();

  static const MethodChannel _channel = MethodChannel('videoedit/audio_mixer');

  static bool get isSupported => Platform.isIOS;

  static Future<String> exportMix({
    required String videoPath,
    required String outputPath,
    required double originalVolume,
    String? musicPath,
    required double musicVolume,
  }) async {
    if (!isSupported) {
      throw UnsupportedError('خلط الصوت مدعوم حاليًا على iPhone وiPad فقط.');
    }

    final result = await _channel.invokeMethod<String>('exportMix', {
      'videoPath': videoPath,
      'outputPath': outputPath,
      'originalVolume': originalVolume.clamp(0.0, 1.0),
      'musicPath': musicPath,
      'musicVolume': musicVolume.clamp(0.0, 1.0),
    });
    if (result == null || result.isEmpty) {
      throw StateError('لم يُنشأ ملف صوتي صالح.');
    }
    return result;
  }
}
