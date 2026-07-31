import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/rss_provider.dart';

class RssScreen extends ConsumerStatefulWidget {
  const RssScreen({super.key});

  @override
  ConsumerState<RssScreen> createState() => _RssScreenState();
}

class _RssScreenState extends ConsumerState<RssScreen> {
  int _feedPage = 1;
  int _homePostPage = 1;
  int? _selectedFeedId;
  int _selectedPostPage = 1;

  @override
  Widget build(BuildContext context) {
    final feeds = ref.watch(rssFeedsProvider(_feedPage));
    final posts = ref.watch(rssPostsProvider((rssId: _selectedFeedId, page: _selectedFeedId == null ? _homePostPage : _selectedPostPage)));
    return Scaffold(
      appBar: AppBar(
        title: const Text('RSS'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: feeds.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorText(error),
        data: (feedPage) => ListView(
          children: [
            ...feedPage.items.map((feed) => ListTile(
              title: Text(feed.name),
              subtitle: Text(feed.rssUrl),
              onTap: () => setState(() {
                _selectedFeedId = feed.id;
                _selectedPostPage = 1;
              }),
            )),
            _Pagination(
              page: feedPage.page,
              totalPages: _pages(feedPage.total, feedPage.pageSize),
              onPrevious: _feedPage > 1 ? () => setState(() => _feedPage--) : null,
              onNext: feedPage.page < _pages(feedPage.total, feedPage.pageSize)
                  ? () => setState(() => _feedPage++)
                  : null,
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                _selectedFeedId == null ? '全部文章' : '指定 Feed 文章',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            posts.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
              error: (error, _) => _ErrorText(error),
              data: (postPage) => Column(
                children: [
                  ...postPage.items.map((post) => ListTile(
                    title: Text(post.title),
                    subtitle: Text('${post.author} · ${_formatTime(post.time)}'),
                    onTap: () => _openPost(post.link),
                  )),
                  _Pagination(
                    page: postPage.page,
                    totalPages: _pages(postPage.total, postPage.pageSize),
                    onPrevious: postPage.page > 1 ? () => setState(() => _changePostPage(postPage.page - 1)) : null,
                    onNext: postPage.page < _pages(postPage.total, postPage.pageSize)
                        ? () => setState(() => _changePostPage(postPage.page + 1))
                        : null,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _changePostPage(int page) {
    if (_selectedFeedId == null) {
      _homePostPage = page;
    } else {
      _selectedPostPage = page;
    }
  }

  Future<void> _refresh() async {
    await ref.read(rssRepositoryProvider).refresh();
    if (!mounted) return;
    setState(() {
      _feedPage = 1;
      _homePostPage = 1;
      _selectedFeedId = null;
      _selectedPostPage = 1;
    });
    ref.invalidate(rssFeedsProvider(_feedPage));
    ref.invalidate(rssPostsProvider((rssId: _selectedFeedId, page: _selectedFeedId == null ? _homePostPage : _selectedPostPage)));
  }

  Future<void> _openPost(String link) async {
    final uri = Uri.tryParse(link);
    if (uri == null || !const {'http', 'https'}.contains(uri.scheme.toLowerCase()) || uri.host.isEmpty) {
      _showMessage('仅支持 HTTP(S) 链接');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showMessage('无法打开链接');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatTime(int timestamp) {
    final milliseconds = timestamp < 100000000000 ? timestamp * 1000 : timestamp;
    return DateFormat('yyyy/MM/dd').format(DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal());
  }

  int _pages(int total, int pageSize) => total == 0 ? 1 : (total / pageSize).ceil();
}

class _Pagination extends StatelessWidget {
  const _Pagination({required this.page, required this.totalPages, this.onPrevious, this.onNext});
  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(tooltip: '上一页', onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
      Text('第 $page / $totalPages 页'),
      IconButton(tooltip: '下一页', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
    ],
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text('加载失败：$error'),
  );
}
