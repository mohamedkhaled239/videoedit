import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class DownloadedDocument {
  const DownloadedDocument({
    required this.path,
    required this.fileName,
    required this.mimeType,
  });

  final String path;
  final String fileName;
  final String mimeType;
}

class DocumentDownloadProvider extends ChangeNotifier {
  DocumentDownloadProvider({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  static const Duration _networkTimeout = Duration(seconds: 20);
  static const int _maximumFileSize = 200 * 1024 * 1024;
  static const String _offlineMessage =
      'لا يوجد اتصال بالإنترنت. تأكد من الشبكة ثم حاول مرة أخرى.';

  static const Map<String, String> _mimeExtensions = {
    'application/pdf': 'pdf',
    'application/msword': 'doc',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        'docx',
    'text/plain': 'txt',
    'text/csv': 'csv',
    'application/rtf': 'rtf',
    'text/rtf': 'rtf',
    'application/vnd.ms-excel': 'xls',
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': 'xlsx',
    'application/vnd.ms-powerpoint': 'ppt',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation':
        'pptx',
    'application/zip': 'zip',
    'application/x-zip-compressed': 'zip',
    'application/vnd.oasis.opendocument.text': 'odt',
    'application/vnd.oasis.opendocument.spreadsheet': 'ods',
    'application/vnd.oasis.opendocument.presentation': 'odp',
  };

  static const Set<String> _genericBinaryMimeTypes = {
    'application/octet-stream',
    'application/download',
    'application/x-download',
  };

  static const Set<String> _supportedExtensions = {
    'pdf',
    'doc',
    'docx',
    'txt',
    'csv',
    'rtf',
    'xls',
    'xlsx',
    'ppt',
    'pptx',
    'zip',
    'odt',
    'ods',
    'odp',
  };

  final http.Client Function() _clientFactory;

  bool _isDownloading = false;
  double _downloadProgress = 0;
  String? _errorMessage;
  String? _downloadedFilePath;

  bool get isDownloading => _isDownloading;
  double get downloadProgress => _downloadProgress;
  String? get errorMessage => _errorMessage;
  String? get downloadedFilePath => _downloadedFilePath;

  bool _isNetworkError(Object error) {
    return error is SocketException ||
        error is HandshakeException ||
        error is TimeoutException ||
        error is http.ClientException;
  }

  String _extensionOf(String value) {
    return p.extension(value).replaceFirst('.', '').toLowerCase();
  }

  String _sanitizeFileName(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[^\w\s\-.]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'[()<>]'), '')
        .trim();
    return sanitized.isEmpty
        ? 'videoedit_${DateTime.now().millisecondsSinceEpoch}'
        : sanitized;
  }

  String? _fileNameFromContentDisposition(String? value) {
    if (value == null || value.isEmpty) return null;
    final encoded = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(value);
    if (encoded != null) return Uri.decodeComponent(encoded.group(1)!);

    return RegExp(
      r'filename="?([^";]+)"?',
      caseSensitive: false,
    ).firstMatch(value)?.group(1)?.trim();
  }

  bool _startsWithBytes(List<int> bytes, List<int> signature) {
    if (bytes.length < signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[index] != signature[index]) return false;
    }
    return true;
  }

  Future<bool> _matchesExpectedFormat(File file, String extension) async {
    final randomAccessFile = await file.open();
    try {
      final bytes = await randomAccessFile.read(8192);
      if (bytes.isEmpty) return false;

      const zipSignatures = [
        [0x50, 0x4B, 0x03, 0x04],
        [0x50, 0x4B, 0x05, 0x06],
        [0x50, 0x4B, 0x07, 0x08],
      ];
      const oleSignature = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];

      switch (extension) {
        case 'pdf':
          return _startsWithBytes(bytes, const [0x25, 0x50, 0x44, 0x46]);
        case 'doc':
        case 'xls':
        case 'ppt':
          return _startsWithBytes(bytes, oleSignature);
        case 'docx':
        case 'xlsx':
        case 'pptx':
        case 'zip':
        case 'odt':
        case 'ods':
        case 'odp':
          return zipSignatures.any(
            (signature) => _startsWithBytes(bytes, signature),
          );
        case 'rtf':
          return _startsWithBytes(bytes, const [0x7B, 0x5C, 0x72, 0x74, 0x66]);
        case 'txt':
        case 'csv':
          final controlBytes = bytes.where(
            (byte) =>
                byte == 0 || (byte < 0x09) || (byte > 0x0D && byte < 0x20),
          );
          return controlBytes.length / bytes.length < 0.01;
      }
      return false;
    } finally {
      await randomAccessFile.close();
    }
  }

  Future<DownloadedDocument?> downloadDocument(String url) async {
    http.Client? client;
    IOSink? sink;
    File? outputFile;

    try {
      final uri = Uri.tryParse(url);
      if (uri == null ||
          !const {'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        _errorMessage = 'أدخل رابطًا مباشرًا وصحيحًا للملف.';
        notifyListeners();
        return null;
      }

      _isDownloading = true;
      _downloadProgress = 0;
      _errorMessage = null;
      _downloadedFilePath = null;
      notifyListeners();

      client = _clientFactory();
      final response = await client
          .send(http.Request('GET', uri))
          .timeout(_networkTimeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      final mimeType = (response.headers['content-type'] ?? '')
          .split(';')
          .first
          .trim()
          .toLowerCase();
      final dispositionName = _fileNameFromContentDisposition(
        response.headers['content-disposition'],
      );
      final candidateName = dispositionName?.isNotEmpty == true
          ? dispositionName!
          : p.basename(uri.path);
      final urlExtension = _extensionOf(candidateName);
      final mimeExtension = _mimeExtensions[mimeType];
      final extension =
          mimeExtension ??
          (_genericBinaryMimeTypes.contains(mimeType) &&
                  _supportedExtensions.contains(urlExtension)
              ? urlExtension
              : null);

      if (extension == null) {
        _errorMessage =
            'هذا النوع غير مدعوم. استخدم رابطًا مباشرًا لمستند أو ملف مضغوط.';
        return null;
      }

      final contentLength = response.contentLength ?? 0;
      if (contentLength > _maximumFileSize) {
        _errorMessage = 'حجم الملف أكبر من الحد المسموح وهو 200 ميجابايت.';
        return null;
      }

      var baseName = p.basenameWithoutExtension(candidateName);
      if (baseName.isEmpty) {
        baseName = 'videoedit_${DateTime.now().millisecondsSinceEpoch}';
      }

      final documentsDirectory = await getApplicationDocumentsDirectory();
      final downloadDirectory = Directory(
        p.join(documentsDirectory.path, 'Downloads'),
      );
      await downloadDirectory.create(recursive: true);

      final safeBaseName = _sanitizeFileName(baseName);
      var fileName = '$safeBaseName.$extension';
      outputFile = File(p.join(downloadDirectory.path, fileName));
      if (await outputFile.exists()) {
        fileName =
            '${safeBaseName}_${DateTime.now().millisecondsSinceEpoch}.$extension';
        outputFile = File(p.join(downloadDirectory.path, fileName));
      }

      var receivedBytes = 0;
      sink = outputFile.openWrite();
      await for (final chunk in response.stream) {
        receivedBytes += chunk.length;
        if (receivedBytes > _maximumFileSize) {
          throw const FileSystemException('File exceeds the size limit');
        }
        sink.add(chunk);
        if (contentLength > 0) {
          _downloadProgress = receivedBytes / contentLength;
          notifyListeners();
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (!await outputFile.exists() || await outputFile.length() == 0) {
        throw const FileSystemException('Downloaded file is empty');
      }
      if (!await _matchesExpectedFormat(outputFile, extension)) {
        throw const FormatException(
          'Downloaded content does not match the declared document type',
        );
      }

      _downloadedFilePath = outputFile.path;
      _downloadProgress = 1;
      return DownloadedDocument(
        path: outputFile.path,
        fileName: fileName,
        mimeType: mimeType,
      );
    } catch (error, stackTrace) {
      await sink?.close();
      if (outputFile != null && await outputFile.exists()) {
        await outputFile.delete();
      }
      _errorMessage = _isNetworkError(error)
          ? _offlineMessage
          : 'تعذّر تحميل الملف. تأكد من الرابط ونوع الملف ثم حاول مرة أخرى.';
      debugPrint('Document download failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return null;
    } finally {
      client?.close();
      _isDownloading = false;
      notifyListeners();
    }
  }

  void reset() {
    _isDownloading = false;
    _downloadProgress = 0;
    _errorMessage = null;
    _downloadedFilePath = null;
    notifyListeners();
  }
}
