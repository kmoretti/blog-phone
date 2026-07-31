import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:blog_phone/presentation/widgets/app_scaffold.dart';
import '../moments/presentation/moments_screen.dart';
import '../friends/presentation/friend_links_screen.dart';
import '../rss/presentation/rss_screen.dart';
import '../images/presentation/images_screen.dart';
import '../settings/settings_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) =>
      const ProviderScope(child: _HomeShellContent());
}

class _HomeShellContent extends ConsumerWidget {
  const _HomeShellContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) => AppScaffold(
    navigationItems: AppNavigationItem.defaults,
    body: const MomentsScreen(),
    pages: [const MomentsScreen(), const FriendLinksScreen(), const RssScreen(), const ImagesScreen(), SettingsScreen()], 
  );
}
