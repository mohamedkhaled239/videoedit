import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class StudioBrand extends StatelessWidget {
  const StudioBrand({super.key, this.icon = Icons.play_arrow_rounded});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ستوديو المونتاج الذكي',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        textDirection: TextDirection.rtl,
        children: [
          // أيقونة الشعار
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: .26),
                  AppColors.primary.withValues(alpha: .08),
                ],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: .35),
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .14),
                  blurRadius: 12,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: AppColors.primary, size: 25),
          ),
          const SizedBox(width: 12),
          // الاسم + الوصف
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ستوديو المونتاج الذكي',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'حوّل أفكارك إلى فيديوهات احترافية',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class StudioAppBar extends StatelessWidget {
  const StudioAppBar({
    super.key,
    this.icon = Icons.play_arrow_rounded,
    this.onSettings,
  });

  final IconData icon;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);

    return Semantics(
      header: true,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          width: double.infinity,
          height: 72,
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF0FAFB)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            border: Border.all(color: AppColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1849676E),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                // خط إضاءة رفيع في الأعلى
                Positioned(
                  top: 0,
                  left: 40,
                  right: 40,
                  height: 1.5,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          AppColors.primary.withValues(alpha: .6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Center(child: StudioBrand(icon: icon)),
                if (onSettings != null)
                  PositionedDirectional(
                    start: 12,
                    top: 14,
                    child: IconButton(
                      tooltip: 'الإعدادات',
                      onPressed: onSettings,
                      style: IconButton.styleFrom(
                        minimumSize: const Size(44, 44),
                        backgroundColor: AppColors.elevatedSurface,
                        side: const BorderSide(color: AppColors.border),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MintButton extends StatelessWidget {
  const MintButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.height = 58,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: FilledButton.icon(
        onPressed: busy ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: .55),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        icon: busy
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Icon(icon, size: 25),
        label: Text(label),
      ),
    );
  }
}
