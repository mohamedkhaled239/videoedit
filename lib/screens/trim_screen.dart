import 'dart:io';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../providers/video_editor_provider.dart';
import '../utils/app_colors.dart';
import '../widgets/custom_app_bar.dart';

class TrimScreen extends StatefulWidget {
  const TrimScreen({super.key, required this.videoPath});
  final String videoPath;

  @override
  State<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends State<TrimScreen> {
  VideoPlayerController? _controller;
  RangeValues _range = const RangeValues(0, 1);
  double _durationMs = 1;
  final List<String> _thumbnails = [];
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final controller = VideoPlayerController.file(File(widget.videoPath));
      await controller.initialize();
      final duration = controller.value.duration.inMilliseconds.toDouble();
      if (duration <= 0) throw Exception('مدة الفيديو غير صالحة');
      controller.addListener(_onPlaybackChanged);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _durationMs = duration;
        _range = RangeValues(0, duration);
      });
      await _generateTimeline(duration.toInt());
    } catch (error) {
      if (mounted) setState(() => _error = 'تعذّر تجهيز الفيديو: $error');
    }
  }

  Future<void> _generateTimeline(int durationMs) async {
    final editor = VideoEditorBuilder(videoPath: widget.videoPath);
    final frames = <String>[];
    for (var index = 0; index < 7; index++) {
      if (!mounted) return;
      try {
        final position = durationMs * index ~/ 7;
        final path = await editor.generateThumbnail(
          positionMs: position,
          quality: 68,
          width: 150,
          height: 90,
        );
        if (path != null) frames.add(path);
      } catch (_) {
        // A missing frame should not prevent trimming the video.
      }
    }
    if (mounted) setState(() => _thumbnails.addAll(frames));
  }

  void _onPlaybackChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (controller.value.isPlaying &&
        controller.value.position.inMilliseconds >= _range.end) {
      controller.pause();
      controller.seekTo(Duration(milliseconds: _range.start.round()));
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlaybackChanged);
    _controller?.dispose();
    super.dispose();
  }

  String _format(double milliseconds) {
    final total = (milliseconds / 1000).floor();
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoEditorProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            const CustomAppBar(isBack: true, title: 'قص الفيديو'),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 112),
                    children: [
                      _buildPreview(),
                      const SizedBox(height: 18),
                      _buildTimeline(),
                      const SizedBox(height: 18),
                      _buildTimes(),
                    ],
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: FilledButton.icon(
                      onPressed: _isProcessing || _error != null
                          ? null
                          : _trimVideo,
                      icon: const Icon(Icons.content_cut_rounded),
                      label: const Text('قص الفيديو وتصديره'),
                    ),
                  ),
                  if (_isProcessing)
                    Positioned.fill(
                      child: ColoredBox(
                        color: AppColors.background.withValues(alpha: .92),
                        child: Center(
                          child: Container(
                            width: 300,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  value: provider.exportProgress > 0
                                      ? provider.exportProgress
                                      : null,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  provider.exportProgress > 0
                                      ? 'جاري التصدير ${(provider.exportProgress * 100).round()}%'
                                      : 'جاري تجهيز المقطع…',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                OutlinedButton(
                                  onPressed: provider.cancelProcessing,
                                  child: const Text('إلغاء التصدير'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    final controller = _controller;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              )
            : controller == null || !controller.value.isInitialized
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: AspectRatio(
                      aspectRatio: controller.value.aspectRatio,
                      child: VideoPlayer(controller),
                    ),
                  ),
                  Center(
                    child: IconButton.filledTonal(
                      onPressed: _playSelection,
                      iconSize: 36,
                      icon: Icon(
                        controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 9,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        '${_format(controller.value.position.inMilliseconds.toDouble())} / ${_format(_durationMs)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _playSelection() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      return;
    }
    final position = controller.value.position.inMilliseconds;
    if (position < _range.start || position >= _range.end) {
      await controller.seekTo(Duration(milliseconds: _range.start.round()));
    }
    await controller.play();
  }

  Widget _buildTimeline() => Container(
    padding: const EdgeInsets.fromLTRB(12, 18, 12, 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        SizedBox(
          height: 64,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: _thumbnails.isEmpty
                ? const ColoredBox(
                    color: AppColors.elevatedSurface,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Row(
                    children: _thumbnails
                        .map(
                          (path) => Expanded(
                            child: Image.file(
                              File(path),
                              fit: BoxFit.cover,
                              height: 64,
                              errorBuilder: (_, __, ___) => const ColoredBox(
                                color: AppColors.elevatedSurface,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -4),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: RangeSlider(
              values: _range,
              min: 0,
              max: _durationMs,
              labels: RangeLabels(_format(_range.start), _format(_range.end)),
              onChanged: (values) async {
                if (values.end - values.start < 100) return;
                setState(() => _range = values);
                await _controller?.pause();
                await _controller?.seekTo(
                  Duration(milliseconds: values.start.round()),
                );
              },
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildTimes() {
    final selected = _range.end - _range.start;
    return Row(
      children: [
        Expanded(
          child: _TimeCard(label: 'البداية', value: _format(_range.start)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TimeCard(label: 'النهاية', value: _format(_range.end)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _TimeCard(
            label: 'المدة',
            value: _format(selected),
            highlight: true,
          ),
        ),
      ],
    );
  }

  Future<void> _trimVideo() async {
    setState(() => _isProcessing = true);
    final provider = context.read<VideoEditorProvider>();
    try {
      await _controller?.pause();
      final result = await provider.trimVideo(
        _range.start.round(),
        _range.end.round(),
      );
      if (!mounted) return;
      if (result == null) {
        throw Exception(provider.errorMessage ?? 'تعذّر قص الفيديو');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم قص الفيديو وحفظه في المعرض')),
      );
      Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
    decoration: BoxDecoration(
      color: highlight
          ? AppColors.primary.withValues(alpha: .16)
          : AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: highlight ? AppColors.primary : AppColors.border,
      ),
    ),
    child: Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 5),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    ),
  );
}
