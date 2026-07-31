import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/images_provider.dart';

class ImagesScreen extends ConsumerWidget {
  const ImagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('图片资源'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(imagesPageProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ref.watch(imagesPageProvider).when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (page) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(imagesPageProvider),
          child: ListView(
            children: page.items.map((image) => ListTile(
              leading: CachedNetworkImage(imageUrl: image.url, width: 56, height: 56, fit: BoxFit.cover),
              title: Text(image.name),
              subtitle: Text(image.status),
              onTap: () => showDialog(
                context: context,
                builder: (_) => Dialog(child: CachedNetworkImage(imageUrl: image.url, fit: BoxFit.contain)),
              ),
            )).toList(),
          ),
        ),
      ),
    );
  }
}
