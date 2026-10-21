import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

/// Opens the native system sheet with an exported MP4.
///
/// Supplying [sharePositionOrigin] is required for a correctly anchored iPad
/// popover and is harmless on Android and iPhone.
Future<void> shareExportedVideo(BuildContext context, String videoPath) async {
  final file = File(videoPath);
  final renderBox = context.findRenderObject() as RenderBox?;
  final origin = renderBox == null
      ? null
      : renderBox.localToGlobal(Offset.zero) & renderBox.size;
  if (!await file.exists() || await file.length() == 0) {
    throw StateError('ملف الفيديو المُصدَّر غير متاح للمشاركة.');
  }

  await Share.shareXFiles(
    [XFile(videoPath, mimeType: 'video/mp4')],
    subject: 'فيديو من videoedit',
    text: 'تم تصدير هذا الفيديو باستخدام videoedit.',
    sharePositionOrigin: origin,
  );
}

SnackBar exportedVideoSnackBar(
  BuildContext context,
  String videoPath, {
  required String message,
}) => SnackBar(
  content: Text(message),
  duration: const Duration(seconds: 7),
  action: SnackBarAction(
    label: 'مشاركة',
    onPressed: () async {
      try {
        await shareExportedVideo(context, videoPath);
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('تعذّرت المشاركة: $error')));
        }
      }
    },
  ),
);
