import 'dart:io';

import 'package:easy_video_editor/easy_video_editor.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../providers/video_editor_provider.dart';
import '../utils/app_colors.dart';
import '../utils/export_sharing.dart';
import '../widgets/custom_app_bar.dart';

enum EditType { speed, rotate, crop, compress, flip, multiple }

class EditScreen extends StatefulWidget {
  const EditScreen({
    super.key,
    required this.videoPath,
    required this.editType,
  });

  final String videoPath;
  final EditType editType;

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  VideoPlayerController? _controller;
  double _speed = 1;
  RotationDegree _rotation = RotationDegree.degree90;
  VideoAspectRatio _aspectRatio = VideoAspectRatio.ratio16x9;
  VideoResolution _resolution = VideoResolution.p720;
  FlipDirection _flipDirection = FlipDirection.horizontal;
  bool _isProcessing = false;
  String? _previewError;

  @override
  void initState() {
    super.initState();
    _initializePreview();
  }

  Future<void> _initializePreview() async {
    try {
      final controller = VideoPlayerController.file(File(widget.videoPath));
      await controller.initialize();
      await controller.setLooping(true);
      controller.addListener(_onPlaybackChanged);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (_) {
      if (mounted) setState(() => _previewError = 'تعذّرت معاينة الفيديو');
    }
  }

  void _onPlaybackChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlaybackChanged);
    _controller?.dispose();
    super.dispose();
  }

  String get _title => switch (widget.editType) {
    EditType.speed => 'تغيير السرعة',
    EditType.rotate => 'تدوير الفيديو',
    EditType.crop => 'اقتصاص الفيديو',
    EditType.compress => 'جودة التصدير',
    EditType.flip => 'قلب الفيديو',
    EditType.multiple => 'تعديلات الفيديو',
  };

  String get _actionLabel => switch (widget.editType) {
    EditType.speed => 'تطبيق السرعة',
    EditType.rotate => 'تطبيق التدوير',
    EditType.crop => 'تطبيق الاقتصاص',
    EditType.compress => 'تصدير بهذه الجودة',
    EditType.flip => 'تطبيق القلب',
    EditType.multiple => 'تطبيق التغييرات',
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoEditorProvider>();
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            CustomAppBar(isBack: true, title: _title),
            Expanded(
              child: Stack(
                children: [
                  ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 116),
                    children: [
                      _buildPreview(),
                      const SizedBox(height: 18),
                      _buildToolPanel(),
                    ],
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 20,
                    child: FilledButton.icon(
                      onPressed: _isProcessing ? null : _applyEdit,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(_actionLabel),
                    ),
                  ),
                  if (_isProcessing)
                    _ProcessingOverlay(
                      progress: provider.exportProgress,
                      onCancel: provider.cancelProcessing,
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: _previewError != null
            ? Center(
                child: Text(
                  _previewError!,
                  style: const TextStyle(color: AppColors.textSecondary),
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
                  if (widget.editType == EditType.crop)
                    Center(child: _CropGuide(aspectRatio: _aspectRatio)),
                  Center(
                    child: IconButton.filledTonal(
                      onPressed: () async {
                        controller.value.isPlaying
                            ? await controller.pause()
                            : await controller.play();
                      },
                      iconSize: 34,
                      icon: Icon(
                        controller.value.isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 8,
                    child: Directionality(
                      textDirection: TextDirection.ltr,
                      child: VideoProgressIndicator(
                        controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: AppColors.primary,
                          bufferedColor: AppColors.primaryLight,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildToolPanel() => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppColors.border),
    ),
    child: switch (widget.editType) {
      EditType.speed => _buildSpeed(),
      EditType.rotate => _buildRotation(),
      EditType.crop => _buildCrop(),
      EditType.compress => _buildQuality(),
      EditType.flip => _buildFlip(),
      EditType.multiple => const Text(
        'استخدم الأدوات المنفصلة للحصول على تحكم أدق ونتائج قابلة للتراجع.',
        style: TextStyle(color: AppColors.textSecondary),
      ),
    },
  );

  Widget _buildSpeed() {
    const presets = [0.25, 0.5, 1.0, 1.5, 2.0];
    return Column(
      children: [
        Text(
          'السرعة الحالية: ${_speed.toStringAsFixed(_speed == 1 ? 1 : 2)}×',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 16),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Slider(
            value: _speed,
            min: .25,
            max: 2,
            divisions: 7,
            label: '${_speed.toStringAsFixed(2)}×',
            onChanged: _setSpeed,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: presets
              .map(
                (speed) => _ChoiceTile(
                  label: '${speed.toStringAsFixed(speed == 1 ? 1 : 2)}×',
                  selected: (_speed - speed).abs() < .01,
                  onTap: () => _setSpeed(speed),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          'تعكس المعاينة السرعة المختارة، ويُغيّر التصدير مدة الملف فعليًا.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _setSpeed(double value) {
    setState(() => _speed = value);
    _controller?.setPlaybackSpeed(value);
  }

  Widget _buildRotation() {
    const options = [
      ('90°', RotationDegree.degree90),
      ('180°', RotationDegree.degree180),
      ('270°', RotationDegree.degree270),
    ];
    return _OptionGrid(
      children: options
          .map(
            (option) => _ChoiceTile(
              label: option.$1,
              icon: Icons.rotate_90_degrees_cw_rounded,
              selected: _rotation == option.$2,
              onTap: () => setState(() => _rotation = option.$2),
            ),
          )
          .toList(),
    );
  }

  Widget _buildCrop() {
    const options = [
      ('16:9', VideoAspectRatio.ratio16x9, Icons.crop_16_9_rounded),
      ('9:16', VideoAspectRatio.ratio9x16, Icons.crop_portrait_rounded),
      ('1:1', VideoAspectRatio.ratio1x1, Icons.crop_square_rounded),
      ('4:3', VideoAspectRatio.ratio4x3, Icons.crop_5_4_rounded),
    ];
    return Column(
      children: [
        _OptionGrid(
          children: options
              .map(
                (option) => _ChoiceTile(
                  label: option.$1,
                  icon: option.$3,
                  selected: _aspectRatio == option.$2,
                  onTap: () => setState(() => _aspectRatio = option.$2),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 14),
        const Text(
          'يطبّق محرك المعالجة اقتصاصًا مركزيًا بالنسبة المختارة.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildQuality() {
    const options = [
      ('360p', VideoResolution.p360),
      ('480p', VideoResolution.p480),
      ('720p', VideoResolution.p720),
      ('1080p', VideoResolution.p1080),
      ('2160p', VideoResolution.p2160),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: options
          .map(
            (option) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ChoiceTile(
                label: option.$1,
                icon: Icons.high_quality_rounded,
                selected: _resolution == option.$2,
                onTap: () => setState(() => _resolution = option.$2),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildFlip() => _OptionGrid(
    children: [
      _ChoiceTile(
        label: 'أفقي',
        icon: Icons.flip_rounded,
        selected: _flipDirection == FlipDirection.horizontal,
        onTap: () => setState(() => _flipDirection = FlipDirection.horizontal),
      ),
      _ChoiceTile(
        label: 'رأسي',
        icon: Icons.flip_rounded,
        selected: _flipDirection == FlipDirection.vertical,
        onTap: () => setState(() => _flipDirection = FlipDirection.vertical),
      ),
    ],
  );

  Future<void> _applyEdit() async {
    setState(() => _isProcessing = true);
    final provider = context.read<VideoEditorProvider>();
    try {
      final result = switch (widget.editType) {
        EditType.speed => await provider.changeSpeed(_speed),
        EditType.rotate => await provider.rotateVideo(_rotation),
        EditType.crop => await provider.cropVideo(_aspectRatio),
        EditType.compress => await provider.compressVideo(_resolution),
        EditType.flip => await provider.flipVideo(_flipDirection),
        EditType.multiple => null,
      };
      if (!mounted) return;
      if (result == null) {
        throw Exception(provider.errorMessage ?? 'تعذّر تصدير الفيديو');
      }
      ScaffoldMessenger.of(context).showSnackBar(
        exportedVideoSnackBar(
          context,
          result,
          message: 'تم إنشاء الملف وحفظه في المعرض',
        ),
      );
      // Stay on this screen long enough for the user to use the Share action.
      // The provider already points to the exported video, so backing out keeps
      // the new file as the active project.
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString()),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }
}

class _OptionGrid extends StatelessWidget {
  const _OptionGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    alignment: WrapAlignment.center,
    children: children,
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? AppColors.primary.withValues(alpha: .18)
        : AppColors.elevatedSurface,
    borderRadius: BorderRadius.circular(13),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(13),
      child: Container(
        constraints: const BoxConstraints(minWidth: 76, minHeight: 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: selected
                    ? AppColors.primaryLight
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: 7),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CropGuide extends StatelessWidget {
  const _CropGuide({required this.aspectRatio});
  final VideoAspectRatio aspectRatio;

  double get ratio => switch (aspectRatio) {
    VideoAspectRatio.ratio1x1 => 1,
    VideoAspectRatio.ratio4x3 => 4 / 3,
    VideoAspectRatio.ratio3x4 => 3 / 4,
    VideoAspectRatio.ratio16x9 => 16 / 9,
    VideoAspectRatio.ratio9x16 => 9 / 16,
  };

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    widthFactor: ratio < 1 ? .42 : .85,
    child: AspectRatio(
      aspectRatio: ratio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primaryLight, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
        ),
      ),
    ),
  );
}

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay({required this.progress, required this.onCancel});
  final double progress;
  final Future<bool> Function() onCancel;

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: ColoredBox(
      color: AppColors.background.withValues(alpha: .90),
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
              CircularProgressIndicator(value: progress > 0 ? progress : null),
              const SizedBox(height: 18),
              Text(
                progress > 0
                    ? 'جاري التصدير ${(progress * 100).round()}%'
                    : 'جاري تجهيز الفيديو…',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded),
                label: const Text('إلغاء التصدير'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
