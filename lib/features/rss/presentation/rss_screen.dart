import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/rss_provider.dart';

class RssScreen extends ConsumerWidget {
  const RssScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(appBar: AppBar(title: const Text('RSS'), actions: [IconButton(onPressed: () async { await ref.read(rssRepositoryProvider).refresh(); ref.invalidate(rssFeedsProvider); ref.invalidate(rssPostsProvider); }, icon: const Icon(Icons.refresh))]), body: ref.watch(rssFeedsProvider).when(loading: () => const Center(child: CircularProgressIndicator()), error: (e, _) => Center(child: Text('$e')), data: (feeds) => ListView(children: [...feeds.items.map((feed) => ListTile(title: Text(feed.name), subtitle: Text(feed.rssUrl), onTap: () => _showPosts(context, ref, feed.id))), const Divider(), ..._posts(ref)])));
  List<Widget> _posts(WidgetRef ref) => ref.watch(rssPostsProvider(null)).when(loading: () => const [LinearProgressIndicator()], error: (e, _) => [Text('$e')], data: (page) => page.items.map((post) => ListTile(title: Text(post.title), subtitle: Text(post.author))).toList());
  Future<void> _showPosts(BuildContext context, WidgetRef ref, int id) async { final page = await ref.read(rssPostsProvider(id).future); if (!context.mounted) return; showModalBottomSheet(context: context, builder: (_) => ListView(children: page.items.map((post) => ListTile(title: Text(post.title), subtitle: Text(post.description))).toList())); }
}
