import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let controller = window!.rootViewController as! FlutterViewController
    let audioMixer = FlutterMethodChannel(
      name: "videoedit/audio_mixer",
      binaryMessenger: controller.binaryMessenger
    )
    audioMixer.setMethodCallHandler { call, result in
      guard call.method == "exportMix" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let arguments = call.arguments as? [String: Any],
            let videoPath = arguments["videoPath"] as? String,
            let outputPath = arguments["outputPath"] as? String,
            let originalVolume = arguments["originalVolume"] as? Double,
            let musicVolume = arguments["musicVolume"] as? Double else {
        result(FlutterError(code: "invalid_arguments", message: "Missing audio export arguments.", details: nil))
        return
      }
      let musicPath = arguments["musicPath"] as? String
      self.exportAudioMix(
        videoPath: videoPath,
        outputPath: outputPath,
        originalVolume: Float(originalVolume),
        musicPath: musicPath,
        musicVolume: Float(musicVolume),
        result: result
      )
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func exportAudioMix(
    videoPath: String,
    outputPath: String,
    originalVolume: Float,
    musicPath: String?,
    musicVolume: Float,
    result: @escaping FlutterResult
  ) {
    let videoUrl = URL(fileURLWithPath: videoPath)
    guard FileManager.default.fileExists(atPath: videoPath) else {
      result(FlutterError(code: "video_not_found", message: "The selected video is no longer available.", details: nil))
      return
    }
    if let musicPath, !musicPath.isEmpty,
       !FileManager.default.fileExists(atPath: musicPath) {
      result(FlutterError(code: "music_not_found", message: "The selected music file is no longer available.", details: nil))
      return
    }

    let videoAsset = AVURLAsset(url: videoUrl)
    guard let sourceVideoTrack = videoAsset.tracks(withMediaType: .video).first else {
      result(FlutterError(code: "invalid_video", message: "No video track was found.", details: nil))
      return
    }
    let duration = videoAsset.duration
    guard duration.isValid, duration.seconds > 0 else {
      result(FlutterError(code: "invalid_duration", message: "The video has no playable duration.", details: nil))
      return
    }

    let composition = AVMutableComposition()
    guard let compositionVideoTrack = composition.addMutableTrack(
      withMediaType: .video,
      preferredTrackID: kCMPersistentTrackID_Invalid
    ) else {
      result(FlutterError(code: "composition_failed", message: "Unable to prepare the video track.", details: nil))
      return
    }

    do {
      try compositionVideoTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: duration),
        of: sourceVideoTrack,
        at: .zero
      )
      compositionVideoTrack.preferredTransform = sourceVideoTrack.preferredTransform
    } catch {
      result(FlutterError(code: "video_insert_failed", message: error.localizedDescription, details: nil))
      return
    }

    var audioParameters = [AVMutableAudioMixInputParameters]()
    if let sourceAudioTrack = videoAsset.tracks(withMediaType: .audio).first,
       let compositionAudioTrack = composition.addMutableTrack(
        withMediaType: .audio,
        preferredTrackID: kCMPersistentTrackID_Invalid
       ) {
      do {
        try compositionAudioTrack.insertTimeRange(
          CMTimeRange(start: .zero, duration: duration),
          of: sourceAudioTrack,
          at: .zero
        )
        let parameters = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
        parameters.setVolume(max(0, min(1, originalVolume)), at: .zero)
        audioParameters.append(parameters)
      } catch {
        result(FlutterError(code: "original_audio_failed", message: error.localizedDescription, details: nil))
        return
      }
    }

    if let musicPath, !musicPath.isEmpty {
      let musicAsset = AVURLAsset(url: URL(fileURLWithPath: musicPath))
      guard let sourceMusicTrack = musicAsset.tracks(withMediaType: .audio).first,
            musicAsset.duration.isValid, musicAsset.duration.seconds > 0,
            let compositionMusicTrack = composition.addMutableTrack(
              withMediaType: .audio,
              preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
        result(FlutterError(code: "invalid_music", message: "No playable audio track was found in the selected music.", details: nil))
        return
      }
      do {
        var cursor = CMTime.zero
        while CMTimeCompare(cursor, duration) < 0 {
          let remaining = CMTimeSubtract(duration, cursor)
          let segmentDuration = CMTimeCompare(musicAsset.duration, remaining) > 0 ? remaining : musicAsset.duration
          try compositionMusicTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: segmentDuration),
            of: sourceMusicTrack,
            at: cursor
          )
          cursor = CMTimeAdd(cursor, segmentDuration)
        }
        let parameters = AVMutableAudioMixInputParameters(track: compositionMusicTrack)
        parameters.setVolume(max(0, min(1, musicVolume)), at: .zero)
        audioParameters.append(parameters)
      } catch {
        result(FlutterError(code: "music_insert_failed", message: error.localizedDescription, details: nil))
        return
      }
    }

    let outputUrl = URL(fileURLWithPath: outputPath)
    try? FileManager.default.removeItem(at: outputUrl)
    guard let exportSession = AVAssetExportSession(
      asset: composition,
      presetName: AVAssetExportPresetHighestQuality
    ) else {
      result(FlutterError(code: "export_unavailable", message: "Unable to create the export session.", details: nil))
      return
    }
    exportSession.outputURL = outputUrl
    exportSession.outputFileType = .mp4
    let audioMix = AVMutableAudioMix()
    audioMix.inputParameters = audioParameters
    exportSession.audioMix = audioMix
    exportSession.shouldOptimizeForNetworkUse = true
    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        if exportSession.status == .completed {
          result(outputPath)
        } else {
          result(FlutterError(
            code: "audio_export_failed",
            message: exportSession.error?.localizedDescription ?? "Audio export did not complete.",
            details: nil
          ))
        }
      }
    }
  }
}
