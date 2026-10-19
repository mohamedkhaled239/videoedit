import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:video_player/video_player.dart';

import '../utils/app_colors.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.videoPath});

  final String videoPath;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _controller;
  bool _isInitializing = true;
  bool _showControls = true;
  String? _errorMessage;
  int _initializationAttempt = 0;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final attempt = ++_initializationAttempt;
    if (mounted) {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });
    }

    final previousController = _controller;
    _controller = null;
    previousController?.removeListener(_onPlayerChanged);
    await previousController?.dispose();

    VideoPlayerController? nextController;
    try {
      final file = File(widget.videoPath);
      if (!await file.exists() || await file.length() == 0) {
        throw const FileSystemException('ملف الفيديو غير موجود أو فارغ');
      }

      // بعض أجهزة MediaTek تفشل عند تبديل decoder إلى Flutter texture بعد
      // التصدير. Surface النظام يتجنب MediaCodec.setOutputSurface على Android.
      nextController = VideoPlayerController.file(
        file,
        viewType: defaultTargetPlatform == TargetPlatform.android
            ? VideoViewType.platformView
            : VideoViewType.textureView,
      );
      await nextController.initialize();

      if (!mounted || attempt != _initializationAttempt) {
        await nextController.dispose();
        return;
      }

      _controller = nextController;
      nextController.addListener(_onPlayerChanged);
      setState(() => _isInitializing = false);
    } catch (error) {
      await nextController?.dispose();
      if (!mounted || attempt != _initializationAttempt) return;
      setState(() {
        _isInitializing = false;
        _errorMessage = 'تعذّر تشغيل الفيديو المعدّل على المشغل الداخلي.';
      });
      debugPrint('Video player initialization failed: $error');
    }
  }

  void _onPlayerChanged() {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;

    if (controller.value.hasError) {
      setState(() => _errorMessage = 'حدث خطأ أثناء تشغيل الفيديو.');
      return;
    }
    setState(() {});
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    try {
      if (controller.value.isPlaying) {
        await controller.pause();
      } else {
        await controller.play();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'تعذّر تشغيل الفيديو.');
      debugPrint('Video playback failed: $error');
    }
  }

  Future<void> _seekRelative(Duration offset) async {
    final controller = _controller;
    if (controller == null) return;
    var target = controller.value.position + offset;
    if (target < Duration.zero) target = Duration.zero;
    if (target > controller.value.duration) {
      target = controller.value.duration;
    }
    await controller.seekTo(target);
  }

  Future<void> _openWithDevicePlayer() async {
    try {
      await OpenFile.open(widget.videoPath, type: 'video/mp4');
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر فتح الفيديو بمشغل الجهاز.')),
      );
      debugPrint('Opening video externally failed: $error');
    }
  }

  @override
  void dispose() {
    _initializationAttempt++;
    _controller?.removeListener(_onPlayerChanged);
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('مشغل الفيديو'),
        foregroundColor: Colors.white,
        backgroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: Center(
          child: _errorMessage != null
              ? _buildErrorState()
              : _isInitializing ||
                    controller == null ||
                    !controller.value.isInitialized
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppColors.primary),
                    SizedBox(height: 20),
                    Text(
                      'جاري تجهيز الفيديو...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                )
              : _buildPlayer(controller),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.video_file_outlined,
            color: Color(0xFFFF7168),
            size: 64,
          ),
          const SizedBox(height: 18),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _initializePlayer,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _openWithDevicePlayer,
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('فتح بمشغل الجهاز'),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayer(VideoPlayerController controller) {
    final value = controller.value;
    return GestureDetector(
      onTap: () => setState(() => _showControls = !_showControls),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: value.aspectRatio > 0 ? value.aspectRatio : 16 / 9,
            child: VideoPlayer(controller),
          ),
          if (_showControls && !value.isPlaying)
            IconButton.filled(
              onPressed: _togglePlayback,
              iconSize: 54,
              icon: const Icon(Icons.play_arrow_rounded),
            ),
          if (_showControls)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VideoProgressIndicator(
                      controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: AppColors.primary,
                        bufferedColor: Colors.white38,
                        backgroundColor: Colors.white24,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        Text(
                          _formatDuration(value.position),
                          style: const TextStyle(color: Colors.white),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () =>
                              _seekRelative(const Duration(seconds: -10)),
                          icon: const Icon(Icons.replay_10),
                        ),
                        IconButton(
                          onPressed: _togglePlayback,
                          icon: Icon(
                            value.isPlaying ? Icons.pause : Icons.play_arrow,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _seekRelative(const Duration(seconds: 10)),
                          icon: const Icon(Icons.forward_10),
                        ),
                        const Spacer(),
                        Text(
                          _formatDuration(value.duration),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
