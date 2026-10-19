import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:gal/gal.dart';
import 'dart:io';

class PermissionsHelper {
  static Future<Map<String, bool>> checkAllPermissions() async {
    Map<String, bool> permissionsStatus = {};

    if (Platform.isAndroid) {
      permissionsStatus['storage'] = await Permission.storage.isGranted;
      permissionsStatus['photos'] = await Permission.photos.isGranted;
      permissionsStatus['videos'] = await Permission.videos.isGranted;
      permissionsStatus['camera'] = await Permission.camera.isGranted;
      permissionsStatus['microphone'] = await Permission.microphone.isGranted;
    } else if (Platform.isIOS) {
      permissionsStatus['photos'] = await Permission.photos.isGranted;
      permissionsStatus['camera'] = await Permission.camera.isGranted;
      permissionsStatus['microphone'] = await Permission.microphone.isGranted;
      permissionsStatus['mediaLibrary'] =
          await Permission.mediaLibrary.isGranted;
    }

    return permissionsStatus;
  }

  static Future<bool> requestGalleryPermission() async {
    if (Platform.isAndroid) {
      final androidVersion = await _getAndroidVersion();

      // MediaStore can save without broad storage access on Android 11+.
      if (androidVersion >= 30) {
        return true;
      }
      final permission = await Permission.storage.request();
      return permission.isGranted;
    } else if (Platform.isIOS) {
      return Gal.requestAccess(toAlbum: true);
    }
    return false;
  }

  static Future<bool> requestCameraPermission() async {
    final permission = await Permission.camera.request();
    return permission.isGranted;
  }

  static Future<bool> requestMicrophonePermission() async {
    final permission = await Permission.microphone.request();
    return permission.isGranted;
  }

  static Future<bool> requestMediaLibraryPermission() async {
    if (Platform.isIOS) {
      final permission = await Permission.mediaLibrary.request();
      return permission.isGranted;
    }
    return true;
  }

  static Future<Map<Permission, PermissionStatus>>
  requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses;

    if (Platform.isAndroid) {
      if (await _getAndroidVersion() >= 33) {
        statuses = await [
          Permission.videos,
          Permission.photos,
          Permission.camera,
          Permission.microphone,
        ].request();
      } else {
        statuses = await [
          Permission.storage,
          Permission.camera,
          Permission.microphone,
        ].request();
      }
    } else if (Platform.isIOS) {
      statuses = await [
        Permission.photos,
        Permission.camera,
        Permission.microphone,
        Permission.mediaLibrary,
      ].request();
    } else {
      statuses = {};
    }

    return statuses;
  }

  static Future<bool> isGalleryPermissionGranted() async {
    if (Platform.isAndroid) {
      if (await _getAndroidVersion() >= 30) {
        return true;
      }
      return Permission.storage.isGranted;
    } else if (Platform.isIOS) {
      return Gal.hasAccess(toAlbum: true);
    }
    return false;
  }

  static Future<bool> isCameraPermissionGranted() async {
    return await Permission.camera.isGranted;
  }

  static Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      return androidInfo.version.sdkInt;
    }
    return 0;
  }

  static Future<bool> isPermissionPermanentlyDenied(
    Permission permission,
  ) async {
    return await permission.isPermanentlyDenied;
  }

  static String getPermissionRationale(Permission permission) {
    if (permission == Permission.photos || permission == Permission.videos) {
      return 'نحتاج إلى الوصول إلى المعرض لحفظ الملفهات المحملة والمعدلة';
    } else if (permission == Permission.camera) {
      return 'نحتاج إلى الوصول إلى الكاميرا لالتقاط الملفهات';
    } else if (permission == Permission.microphone) {
      return 'نحتاج إلى الوصول إلى الميكروفون لتسجيل الصوت مع الملف';
    } else if (permission == Permission.storage) {
      return 'نحتاج إلى الوصول إلى التخزين لحفظ الملفات';
    } else if (permission == Permission.mediaLibrary) {
      return 'نحتاج إلى الوصول إلى مكتبة الوسائط لإضافة الموسيقى والمؤثرات';
    }
    return 'نحتاج إلى هذا التصريح لتشغيل التطبيق بشكل صحيح';
  }

  static Future<void> handlePermissionDenied(
    Permission permission,
    Function() onPermanentlyDenied,
  ) async {
    if (await permission.isPermanentlyDenied) {
      onPermanentlyDenied();
    }
  }

  static Future<bool> requestPermissionWithHandling(
    Permission permission, {
    required Function() onGranted,
    required Function() onDenied,
    required Function() onPermanentlyDenied,
  }) async {
    final status = await permission.request();

    if (status.isGranted) {
      onGranted();
      return true;
    } else if (status.isPermanentlyDenied) {
      onPermanentlyDenied();
      return false;
    } else {
      onDenied();
      return false;
    }
  }

  static Future<String> getPermissionsSummary() async {
    final permissions = await checkAllPermissions();

    StringBuffer summary = StringBuffer();
    summary.writeln('حالة التصريحات:');
    summary.writeln('═' * 40);

    permissions.forEach((key, value) {
      final status = value ? '✅ ممنوح' : '❌ مرفوض';
      summary.writeln('$key: $status');
    });

    return summary.toString();
  }

  static Future<bool> areAllEssentialPermissionsGranted() async {
    if (Platform.isAndroid) {
      if (await _getAndroidVersion() >= 30) {
        return true;
      }
      return Permission.storage.isGranted;
    } else if (Platform.isIOS) {
      return Gal.hasAccess(toAlbum: true);
    }
    return false;
  }
}
