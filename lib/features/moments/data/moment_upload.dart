import 'package:path/path.dart' as path;

enum MomentUploadTarget {
  local,
  oss;

  String get endpoint => switch (this) {
    MomentUploadTarget.local => 'action/resource/local',
    MomentUploadTarget.oss => 'action/resource/oss',
  };

  bool get isLocal => this == MomentUploadTarget.local;
}

class MomentUploadResult {
  const MomentUploadResult({
    required this.url,
    required this.isLocal,
    this.objectKey,
  });

  final String url;
  final bool isLocal;
  final String? objectKey;
}

const momentUploadMaxBytes = 64 * 1024 * 1024;
const _imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp'};
const _videoExtensions = {'mp4', 'webm'};

String? momentMediaTypeForPath(String filePath) {
  final extension = path
      .extension(filePath)
      .toLowerCase()
      .replaceFirst('.', '');
  if (_imageExtensions.contains(extension)) return 'image';
  if (_videoExtensions.contains(extension)) return 'video';
  return null;
}

String? validateMomentUploadFile(String filePath, int sizeBytes) {
  final extension = path
      .extension(filePath)
      .toLowerCase()
      .replaceFirst('.', '');
  if (!_imageExtensions.contains(extension) &&
      !_videoExtensions.contains(extension)) {
    return '仅支持 PNG、JPG、JPEG、GIF、WEBP、MP4 和 WEBM 文件';
  }
  if (sizeBytes > momentUploadMaxBytes) {
    return '媒体文件不能超过 65 MiB';
  }
  if (sizeBytes < 0) {
    return '媒体文件大小无效';
  }
  return null;
}

String resolveMomentMediaUrl(String apiBaseUrl, String mediaUrl) {
  final value = mediaUrl.trim();
  final uri = Uri.tryParse(value);
  if (uri != null &&
      {'http', 'https'}.contains(uri.scheme.toLowerCase()) &&
      uri.host.isNotEmpty) {
    return value;
  }
  final base = apiBaseUrl
      .trim()
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceFirst(RegExp(r'/api$'), '');
  return '$base/${value.replaceFirst(RegExp(r'^/+'), '')}';
}
