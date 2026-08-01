import 'package:flutter/material.dart';

import 'package:cached_network_image/cached_network_image.dart';

import '../../../data/api/api_client.dart';
import '../data/moment_upload.dart';

class MediaPreview extends StatelessWidget {
  const MediaPreview({
    super.key,
    required this.url,
    required this.mediaType,
    this.isLocal = false,
    this.apiBaseUrl = defaultApiBaseUrl,
  });
  final String url;
  final String mediaType;
  final bool isLocal;
  final String apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final child = CachedNetworkImage(
      imageUrl: resolveMomentMediaUrl(apiBaseUrl, url),
      fit: BoxFit.cover,
    );
    return AspectRatio(
      aspectRatio: 1,
      child: mediaType == 'video'
          ? Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_outlined, size: 40),
                  SizedBox(height: 8),
                  Text('视频暂不支持播放'),
                ],
              ),
            )
          : child,
    );
  }
}
