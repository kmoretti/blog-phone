import 'package:flutter/material.dart';

import 'package:blog_phone/core/platform/responsive_layout.dart';

class AppNavigationItem {
  const AppNavigationItem({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;

  static const defaults = <AppNavigationItem>[
    AppNavigationItem(
      label: '动态',
      icon: Icons.dynamic_feed_outlined,
      selectedIcon: Icons.dynamic_feed,
    ),
    AppNavigationItem(
      label: '友链',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
    AppNavigationItem(
      label: 'RSS',
      icon: Icons.rss_feed_outlined,
      selectedIcon: Icons.rss_feed,
    ),
    AppNavigationItem(
      label: '图片',
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
    ),
    AppNavigationItem(
      label: '我的',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];
}

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    required this.body,
    required this.navigationItems,
    this.pages,
    super.key,
  });

  final Widget body;
  final List<AppNavigationItem> navigationItems;
  final List<Widget>? pages;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final isCompact = ResponsiveLayout.isCompact(constraints);
        final hasNavigation = widget.navigationItems.isNotEmpty;
        final selectedIndex = hasNavigation
            ? _selectedIndex.clamp(0, widget.navigationItems.length - 1)
            : 0;
        final selectedBody = widget.pages != null && selectedIndex < widget.pages!.length ? widget.pages![selectedIndex] : widget.body;
        final content = ResponsiveLayout.constrainContent(child: selectedBody);

        return Scaffold(
          body: isCompact || !hasNavigation
              ? content
              : Row(
                  children: [
                    SizedBox(
                      width: 240,
                      child: NavigationRail(
                        selectedIndex: selectedIndex,
                        onDestinationSelected: _select,
                        labelType: NavigationRailLabelType.all,
                        destinations: _destinations,
                      ),
                    ),
                    Expanded(child: content),
                  ],
                ),
          bottomNavigationBar: isCompact && hasNavigation
              ? BottomNavigationBar(
                  key: const Key('bottom-navigation'),
                  currentIndex: selectedIndex,
                  onTap: _select,
                  items: _bottomItems,
                  type: BottomNavigationBarType.fixed,
                )
              : null,
        );
      },
    );
  }

  List<NavigationRailDestination> get _destinations {
    return widget.navigationItems
        .map(
          (item) => NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          ),
        )
        .toList(growable: false);
  }

  List<BottomNavigationBarItem> get _bottomItems {
    return widget.navigationItems
        .map(
          (item) => BottomNavigationBarItem(
            icon: Icon(item.icon),
            activeIcon: Icon(item.selectedIcon),
            label: item.label,
          ),
        )
        .toList(growable: false);
  }

  void _select(int index) {
    if (index < 0 || index >= widget.navigationItems.length) {
      return;
    }
    setState(() => _selectedIndex = index);
  }
}
