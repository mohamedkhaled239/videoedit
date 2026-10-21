import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum DownloadedFileKind { document, audio, video }

class DownloadedDocument {
  const DownloadedDocument({
    required this.path,
    required this.fileName,
    required this.mimeType,
    required this.kind,
  });

  final String path;
  final String fileName;
  final String mimeType;
  final DownloadedFileKind kind;
}

/// نتيجة استخراج رابط الفيديو الفعلي من صفحة ويب.
class _ResolvedMedia {
  const _ResolvedMedia(this.response, this.uri);

  final http.StreamedResponse response;
  final Uri uri;
}

class DocumentDownloadProvider extends ChangeNotifier {
  DocumentDownloadProvider({
    http.Client Function()? clientFactory,
    Future<Directory> Function()? documentsDirectoryProvider,
  }) : _clientFactory = clientFactory ?? http.Client.new,
       _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory;

  static const Duration _networkTimeout = Duration(seconds: 20);

  // الحد الأقصى لحجم الملف حسب النوع.
  static const int _maxDocumentSize = 200 * 1024 * 1024; // 200 MB
  static const int _maxAudioSize = 500 * 1024 * 1024; // 500 MB
  static const int _maxVideoSize = 2 * 1024 * 1024 * 1024; // 2 GB

  // دعم روابط صفحات الفيديو (مش ملفات مباشرة).
  static const String _browserUserAgent =
      'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
  static const int _maxHtmlBytes = 3 * 1024 * 1024; // 3 MB للصفحة فقط
  static const int _maxCandidates = 8;

  static const String _offlineMessage =
      'لا يوجد اتصال بالإنترنت. تأكد من الشبكة ثم حاول مرة أخرى.';

  static const Map<String, String> _mimeExtensions = {
    // Documents
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

    // Audio
    'audio/mpeg': 'mp3',
    'audio/mp3': 'mp3',
    'audio/mp4': 'm4a',
    'audio/x-m4a': 'm4a',
    'audio/aac': 'aac',
    'audio/x-aac': 'aac',
    'audio/wav': 'wav',
    'audio/x-wav': 'wav',
    'audio/wave': 'wav',
    'audio/ogg': 'ogg',
    'application/ogg': 'ogg',
    'audio/flac': 'flac',
    'audio/x-flac': 'flac',

    // Video
    'video/mp4': 'mp4',
    'video/x-m4v': 'm4v',
    'video/quicktime': 'mov',
    'video/webm': 'webm',
    'video/x-matroska': 'mkv',
    'video/x-msvideo': 'avi',
    'video/avi': 'avi',
    'video/3gpp': '3gp',
    'video/mpeg': 'mpeg',
  };

  // عكس الخريطة السابقة: الامتداد -> أول MIME مسجّل له.
  static final Map<String, String> _extensionMimes = () {
    final result = <String, String>{};
    _mimeExtensions.forEach((mime, ext) => result.putIfAbsent(ext, () => mime));
    return result;
  }();

  static const Set<String> _genericBinaryMimeTypes = {
    'application/octet-stream',
    'application/download',
    'application/x-download',
    'binary/octet-stream',
  };

  static const Set<String> _documentExtensions = {
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

  static const Set<String> _audioExtensions = {
    'mp3',
    'm4a',
    'aac',
    'wav',
    'ogg',
    'flac',
  };

  static const Set<String> _videoExtensions = {
    'mp4',
    'm4v',
    'mov',
    'webm',
    'mkv',
    'avi',
    '3gp',
    'mpeg',
  };

  static final Set<String> _supportedExtensions = {
    ..._documentExtensions,
    ..._audioExtensions,
    ..._videoExtensions,
  };

  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _documentsDirectoryProvider;

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

  DownloadedFileKind _kindOf(String extension) {
    if (_audioExtensions.contains(extension)) return DownloadedFileKind.audio;
    if (_videoExtensions.contains(extension)) return DownloadedFileKind.video;
    return DownloadedFileKind.document;
  }

  int _maxSizeFor(DownloadedFileKind kind) {
    switch (kind) {
      case DownloadedFileKind.audio:
        return _maxAudioSize;
      case DownloadedFileKind.video:
        return _maxVideoSize;
      case DownloadedFileKind.document:
        return _maxDocumentSize;
    }
  }

  String _limitLabel(int bytes) {
    const mb = 1024 * 1024;
    const gb = 1024 * mb;
    if (bytes >= gb) return '${bytes ~/ gb} جيجابايت';
    return '${bytes ~/ mb} ميجابايت';
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

  // ---------------------------------------------------------------------------
  // دعم روابط صفحات الفيديو
  // ---------------------------------------------------------------------------

  /// يرسل طلب GET بهيدرز شبيهة بالمتصفح (User-Agent / Referer / Cookie).
  Future<http.StreamedResponse> _send(
    http.Client client,
    Uri uri, {
    Uri? referer,
    String? cookie,
  }) {
    final request = http.Request('GET', uri)
      ..headers['User-Agent'] = _browserUserAgent
      ..headers['Accept'] = '*/*'
      ..headers['Accept-Language'] = 'ar,en;q=0.8';
    if (referer != null) request.headers['Referer'] = referer.toString();
    if (cookie != null && cookie.isNotEmpty) {
      request.headers['Cookie'] = cookie;
    }
    return client.send(request).timeout(_networkTimeout);
  }

  String _mimeOf(http.StreamedResponse response) =>
      (response.headers['content-type'] ?? '')
          .split(';')
          .first
          .trim()
          .toLowerCase();

  bool _isHtmlMime(String mime) =>
      mime == 'text/html' || mime == 'application/xhtml+xml';

  /// اسم الملف من آخر جزء في مسار الصفحة (غالبًا id الفيديو).
  String _pageBaseName(Uri pageUri) {
    final segments = pageUri.pathSegments.where((s) => s.isNotEmpty);
    return segments.isEmpty ? 'video' : segments.last;
  }

  /// يحوّل هيدر set-cookie إلى هيدر Cookie صالح للطلب التالي.
  String? _cookieHeaderFrom(String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return null;
    final pairs = RegExp(
      r'(?:^|,\s*)([A-Za-z0-9_\-.]+=[^;,]*)',
    ).allMatches(setCookie).map((m) => m.group(1)!).toList();
    return pairs.isEmpty ? null : pairs.join('; ');
  }

  Future<String> _readLimitedText(Stream<List<int>> stream) async {
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      bytes.add(chunk);
      if (bytes.length > _maxHtmlBytes) break;
    }
    return utf8.decode(bytes.takeBytes(), allowMalformed: true);
  }

  String? _decodeJsonString(String value) {
    try {
      return jsonDecode('"$value"') as String;
    } catch (_) {
      return value.replaceAll(r'\u002F', '/').replaceAll(r'\/', '/');
    }
  }

  /// يطلّع روابط الفيديو المحتملة من الصفحة بترتيب الأفضلية.
  List<Uri> _extractMediaUris(String html, Uri pageUri) {
    final raw = <String>[];

    // 1) meta tags (og:video ...)
    const metaKeys = {
      'og:video',
      'og:video:url',
      'og:video:secure_url',
      'twitter:player:stream',
    };
    for (final tag in RegExp(
      r'<meta\b[^>]*>',
      caseSensitive: false,
    ).allMatches(html)) {
      final text = tag.group(0)!;
      final key = RegExp(
        r'''(?:property|name)\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(text)?.group(1)?.toLowerCase();
      if (key == null || !metaKeys.contains(key)) continue;
      final content = RegExp(
        r'''content\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(text)?.group(1);
      if (content != null) raw.add(content.replaceAll('&amp;', '&'));
    }

    // 2) JSON مدمج في الصفحة (JSON-LD / hydration data).
    final jsonPatterns = [
      RegExp(
        r'"(?:downloadAddr|playAddr|playUrl|contentUrl|videoUrl|video_url)"'
        r'\s*:\s*"((?:[^"\\]|\\.)*)"',
      ),
      RegExp(r'"(?:UrlList|urlList|url_list)"\s*:\s*\[\s*"((?:[^"\\]|\\.)*)"'),
    ];
    for (final pattern in jsonPatterns) {
      for (final m in pattern.allMatches(html)) {
        final decoded = _decodeJsonString(m.group(1)!);
        if (decoded != null) raw.add(decoded);
      }
    }

    // 3) <video src> / <source src>
    for (final m in RegExp(
      r'''<(?:video|source)\b[^>]*\bsrc\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      raw.add(m.group(1)!.replaceAll('&amp;', '&'));
    }

    final result = <Uri>[];
    final seen = <String>{};
    for (final item in raw) {
      final parsed = Uri.tryParse(item.trim());
      if (parsed == null) continue;
      final absolute = pageUri.resolveUri(parsed);
      if (!const {'http', 'https'}.contains(absolute.scheme) ||
          absolute.host.isEmpty) {
        continue;
      }
      if (seen.add(absolute.toString())) result.add(absolute);
      if (result.length >= _maxCandidates) break;
    }
    return result;
  }

  /// يقرأ صفحة HTML ويجرّب روابط الفيديو المستخرجة منها حتى ينجح أحدها.
  Future<_ResolvedMedia> _resolveFromPage(
    http.Client client,
    Uri pageUri,
    http.StreamedResponse pageResponse,
  ) async {
    final cookie = _cookieHeaderFrom(pageResponse.headers['set-cookie']);
    final html = await _readLimitedText(pageResponse.stream);

    for (final candidate in _extractMediaUris(html, pageUri)) {
      try {
        final response = await _send(
          client,
          candidate,
          referer: pageUri,
          cookie: cookie,
        );
        if (response.statusCode >= 200 &&
            response.statusCode < 300 &&
            !_isHtmlMime(_mimeOf(response))) {
          return _ResolvedMedia(response, candidate);
        }
        await response.stream.drain<void>();
      } catch (_) {
        // جرّب الرابط اللي بعده.
      }
    }
    throw const FormatException('No media URL found in page');
  }

  // ---------------------------------------------------------------------------
  // فحص الـ signatures
  // ---------------------------------------------------------------------------

  /// يتحقق من وجود [signature] بداية من [offset] داخل [bytes].
  bool _hasBytesAt(List<int> bytes, List<int> signature, [int offset = 0]) {
    if (bytes.length < offset + signature.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[offset + index] != signature[index]) return false;
    }
    return true;
  }

  bool _startsWithBytes(List<int> bytes, List<int> signature) =>
      _hasBytesAt(bytes, signature, 0);

  // صيغ MP4 / MOV / 3GP كلها مبنية على ISO BMFF: كلمة ftyp عند البايت 4.
  bool _isIsoBaseMedia(List<int> bytes, {bool allowLegacyMov = false}) {
    if (_hasBytesAt(bytes, 'ftyp'.codeUnits, 4)) return true;
    if (!allowLegacyMov) return false;
    // ملفات QuickTime القديمة قد تبدأ بـ moov / mdat / wide / free / skip.
    const legacyBoxes = ['moov', 'mdat', 'wide', 'free', 'skip', 'pnot'];
    return legacyBoxes.any((box) => _hasBytesAt(bytes, box.codeUnits, 4));
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

        // ---------- Audio ----------
        case 'mp3':
          // ID3 tag أو MPEG frame sync (11 بت مضبوطة).
          if (_startsWithBytes(bytes, const [0x49, 0x44, 0x33])) return true;
          return bytes.length > 1 &&
              bytes[0] == 0xFF &&
              (bytes[1] & 0xE0) == 0xE0;
        case 'aac':
          // ADTS header.
          if (_startsWithBytes(bytes, const [0x49, 0x44, 0x33])) return true;
          return bytes.length > 1 &&
              bytes[0] == 0xFF &&
              (bytes[1] & 0xF6) == 0xF0;
        case 'm4a':
          return _isIsoBaseMedia(bytes);
        case 'wav':
          return _startsWithBytes(bytes, 'RIFF'.codeUnits) &&
              _hasBytesAt(bytes, 'WAVE'.codeUnits, 8);
        case 'ogg':
          return _startsWithBytes(bytes, 'OggS'.codeUnits);
        case 'flac':
          return _startsWithBytes(bytes, 'fLaC'.codeUnits);

        // ---------- Video ----------
        case 'mp4':
        case 'm4v':
        case '3gp':
          return _isIsoBaseMedia(bytes);
        case 'mov':
          return _isIsoBaseMedia(bytes, allowLegacyMov: true);
        case 'webm':
        case 'mkv':
          // EBML header.
          return _startsWithBytes(bytes, const [0x1A, 0x45, 0xDF, 0xA3]);
        case 'avi':
          return _startsWithBytes(bytes, 'RIFF'.codeUnits) &&
              _hasBytesAt(bytes, 'AVI '.codeUnits, 8);
        case 'mpeg':
          return _startsWithBytes(bytes, const [0x00, 0x00, 0x01, 0xBA]) ||
              _startsWithBytes(bytes, const [0x00, 0x00, 0x01, 0xB3]);
      }
      return false;
    } finally {
      await randomAccessFile.close();
    }
  }

  /// Identifies a direct media response that has no filename extension and a
  /// generic API content type such as `application/octet-stream`.
  Future<String?> _detectExtension(File file) async {
    final randomAccessFile = await file.open();
    try {
      final bytes = await randomAccessFile.read(8192);
      if (bytes.length < 4) return null;

      bool at(String value, int offset) =>
          _hasBytesAt(bytes, value.codeUnits, offset);

      if (at('RIFF', 0) && at('WAVE', 8)) return 'wav';
      if (at('RIFF', 0) && at('AVI ', 8)) return 'avi';
      if (at('OggS', 0)) return 'ogg';
      if (at('fLaC', 0)) return 'flac';

      if (at('ftyp', 4)) {
        if (at('M4A ', 8)) return 'm4a';
        if (at('M4V ', 8)) return 'm4v';
        if (at('qt  ', 8)) return 'mov';
        if (at('3gp', 8) || at('3g2', 8)) return '3gp';
        return 'mp4';
      }

      if (_startsWithBytes(bytes, const [0x1A, 0x45, 0xDF, 0xA3])) {
        final header = String.fromCharCodes(bytes.take(128));
        return header.contains('webm') ? 'webm' : 'mkv';
      }
      if (_startsWithBytes(bytes, const [0x00, 0x00, 0x01, 0xBA]) ||
          _startsWithBytes(bytes, const [0x00, 0x00, 0x01, 0xB3])) {
        return 'mpeg';
      }
      if (at('ID3', 0) ||
          (bytes.length > 1 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0)) {
        return 'mp3';
      }
      return null;
    } finally {
      await randomAccessFile.close();
    }
  }

  // ---------------------------------------------------------------------------
  // التحميل
  // ---------------------------------------------------------------------------

  Future<DownloadedDocument?> downloadDocument(String url) async {
    http.Client? client;
    IOSink? sink;
    File? outputFile;

    try {
      final uri = Uri.tryParse(url.trim());
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
      var effectiveUri = uri;
      var response = await _send(client, uri);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('HTTP ${response.statusCode}');
      }

      var mimeType = _mimeOf(response);
      String? pageBaseName;

      // لو الرابط صفحة ويب (مش ملف) نطلّع منها رابط الفيديو الفعلي.
      if (_isHtmlMime(mimeType)) {
        final resolved = await _resolveFromPage(client, uri, response);
        response = resolved.response;
        effectiveUri = resolved.uri;
        mimeType = _mimeOf(response);
        pageBaseName = _pageBaseName(uri); // اسم الملف من id الفيديو
      }

      final dispositionName = _fileNameFromContentDisposition(
        response.headers['content-disposition'],
      );
      final extensionSource = dispositionName?.isNotEmpty == true
          ? dispositionName!
          : p.basename(effectiveUri.path);
      final candidateName = pageBaseName ?? extensionSource;
      final urlExtension = _extensionOf(extensionSource);
      final urlExtensionSupported = _supportedExtensions.contains(urlExtension);

      String? extension = _mimeExtensions[mimeType];

      // لو الامتداد في الرابط مدعوم ونوعه (صوت/فيديو) يطابق نوع الـ MIME
      // نفضّله، لأن بعض السيرفرات ترجع MIME عام مثل audio/mp4 لملفات mp4.
      if (extension != null &&
          urlExtensionSupported &&
          urlExtension != extension &&
          _kindOf(urlExtension) == _kindOf(extension) &&
          _kindOf(extension) != DownloadedFileKind.document &&
          _extensionMimes[urlExtension]?.split('/').first ==
              mimeType.split('/').first) {
        extension = urlExtension;
      }

      // لو الـ MIME عام (octet-stream) نعتمد على الامتداد.
      extension ??=
          (_genericBinaryMimeTypes.contains(mimeType) && urlExtensionSupported)
          ? urlExtension
          : null;

      // لو الـ MIME من نوع audio/* أو video/* غير معروف لكن الامتداد مدعوم.
      extension ??=
          ((mimeType.startsWith('audio/') || mimeType.startsWith('video/')) &&
              urlExtensionSupported &&
              _kindOf(urlExtension) != DownloadedFileKind.document)
          ? urlExtension
          : null;

      // APIs commonly return a binary response without a useful filename.
      // Download it as a temporary file, then recognise its real media type.
      final needsContentDetection =
          extension == null &&
          (mimeType.isEmpty ||
              _genericBinaryMimeTypes.contains(mimeType) ||
              mimeType.startsWith('application/'));
      if (extension == null && !needsContentDetection) {
        _errorMessage =
            'هذا النوع غير مدعوم. استخدم رابطًا مباشرًا لمستند أو ملف صوتي أو فيديو.';
        return null;
      }

      var resolvedExtension = extension;
      final maximumFileSize = resolvedExtension == null
          ? _maxVideoSize
          : _maxSizeFor(_kindOf(resolvedExtension));

      final contentLength = response.contentLength ?? 0;
      if (contentLength > maximumFileSize) {
        _errorMessage =
            'حجم الملف أكبر من الحد المسموح وهو ${_limitLabel(maximumFileSize)}.';
        return null;
      }

      var baseName = p.basenameWithoutExtension(candidateName);
      if (baseName.isEmpty) {
        baseName = 'videoedit_${DateTime.now().millisecondsSinceEpoch}';
      }

      final documentsDirectory = await _documentsDirectoryProvider();
      final downloadDirectory = Directory(
        p.join(documentsDirectory.path, 'Downloads'),
      );
      await downloadDirectory.create(recursive: true);

      final safeBaseName = _sanitizeFileName(baseName);
      var fileName = '$safeBaseName.${resolvedExtension ?? 'part'}';
      outputFile = File(p.join(downloadDirectory.path, fileName));
      if (await outputFile.exists()) {
        fileName =
            '${safeBaseName}_${DateTime.now().millisecondsSinceEpoch}.${resolvedExtension ?? 'part'}';
        outputFile = File(p.join(downloadDirectory.path, fileName));
      }

      var receivedBytes = 0;
      var lastNotifiedProgress = 0.0;
      sink = outputFile.openWrite();
      await for (final chunk in response.stream) {
        receivedBytes += chunk.length;
        if (receivedBytes > maximumFileSize) {
          throw const FileSystemException('File exceeds the size limit');
        }
        sink.add(chunk);
        if (contentLength > 0) {
          _downloadProgress = receivedBytes / contentLength;
          // الفيديوهات كبيرة: نحدّث الواجهة كل 1% فقط بدل كل chunk.
          if (_downloadProgress - lastNotifiedProgress >= 0.01) {
            lastNotifiedProgress = _downloadProgress;
            notifyListeners();
          }
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      if (!await outputFile.exists() || await outputFile.length() == 0) {
        throw const FileSystemException('Downloaded file is empty');
      }
      if (resolvedExtension == null) {
        final detectedExtension = await _detectExtension(outputFile);
        if (detectedExtension == null) {
          throw const FormatException('Unsupported direct media response');
        }
        if (await outputFile.length() >
            _maxSizeFor(_kindOf(detectedExtension))) {
          throw const FileSystemException('File exceeds the size limit');
        }
        resolvedExtension = detectedExtension;
        var finalName = '$safeBaseName.$resolvedExtension';
        var finalFile = File(p.join(downloadDirectory.path, finalName));
        if (await finalFile.exists()) {
          finalName =
              '${safeBaseName}_${DateTime.now().millisecondsSinceEpoch}.$resolvedExtension';
          finalFile = File(p.join(downloadDirectory.path, finalName));
        }
        outputFile = await outputFile.rename(finalFile.path);
        fileName = finalName;
      }
      if (!await _matchesExpectedFormat(outputFile, resolvedExtension)) {
        throw const FormatException(
          'Downloaded content does not match the declared file type',
        );
      }

      _downloadedFilePath = outputFile.path;
      _downloadProgress = 1;
      return DownloadedDocument(
        path: outputFile.path,
        fileName: fileName,
        // لو السيرفر رجّع MIME عام نستخدم MIME المناسب للامتداد.
        mimeType: _genericBinaryMimeTypes.contains(mimeType) || mimeType.isEmpty
            ? (_extensionMimes[resolvedExtension] ?? mimeType)
            : mimeType,
        kind: _kindOf(resolvedExtension),
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
