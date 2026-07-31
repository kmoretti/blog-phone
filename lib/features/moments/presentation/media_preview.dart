import 'dart:io';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MediaPreview extends StatelessWidget {
  const MediaPreview({
    super.key,
    required this.url,
    required this.mediaType,
    this.isLocal = false,
  });
  final String url;
  final String mediaType;
  final bool isLocal;

  @override
  Widget build(BuildContext context) {
    final child = isLocal
        ? Image.file(File(url), fit: BoxFit.cover)
        : CachedNetworkImage(imageUrl: url, fit: BoxFit.cover);
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
