import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:blog_phone/core/theme/memoflow_theme.dart';
import 'package:blog_phone/features/home/home_shell.dart';
import 'package:blog_phone/presentation/widgets/app_scaffold.dart';

void main() {
  testWidgets('renders the app shell with Chinese navigation labels', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: HomeShell()));

    expect(find.byType(HomeShell), findsOneWidget);
    expect(find.text('动态'), findsOneWidget);
    expect(find.text('友链'), findsOneWidget);
    expect(find.text('RSS'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  test('uses the MemoFlow product color palette', () {
    expect(
      MemoFlowTheme.light.scaffoldBackgroundColor,
      const Color(0xFFF5F2ED),
    );
    expect(MemoFlowTheme.dark.scaffoldBackgroundColor, const Color(0xFF242321));
    expect(MemoFlowTheme.light.colorScheme.primary, const Color(0xFFB76045));
  });

  testWidgets('uses keyed bottom navigation below 720 pixels', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(719, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          body: const Text('Content'),
          navigationItems: AppNavigationItem.defaults,
        ),
      ),
    );

    expect(find.byKey(const Key('bottom-navigation')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('uses a 240 pixel side navigation at 720 pixels and above', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(720, 800)),
          child: AppScaffold(
            body: const Text('Content'),
            navigationItems: AppNavigationItem.defaults,
          ),
        ),
      ),
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('bottom-navigation')), findsNothing);
    expect(tester.getSize(find.byType(NavigationRail)).width, 240);
  });

  testWidgets('constrains and centers content within the wide layout', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(1440, 800));

    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          body: const SizedBox(key: Key('content')),
          navigationItems: AppNavigationItem.defaults,
        ),
      ),
    );

    final content = tester.getRect(find.byKey(const Key('content')));
    expect(content.width, 960);
    expect(content.center.dx, 840);
  });

  testWidgets('uses compact layout from actual constraints', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(500, 800));
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScaffold(
          body: Text('Content'),
          navigationItems: AppNavigationItem.defaults,
        ),
      ),
    );

    expect(find.byKey(const Key('bottom-navigation')), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('handles an empty navigation list without an invalid index', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppScaffold(body: Text('Content'), navigationItems: []),
      ),
    );

    expect(find.byKey(const Key('bottom-navigation')), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Content'), findsOneWidget);
  });

  testWidgets('updates currentIndex after a narrow-screen navigation tap', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(719, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          body: const Text('Content'),
          navigationItems: AppNavigationItem.defaults,
        ),
      ),
    );

    await tester.tap(find.text('图片'));
    await tester.pump();

    expect(
      tester
          .widget<BottomNavigationBar>(
            find.byKey(const Key('bottom-navigation')),
          )
          .currentIndex,
      3,
    );
  });

  testWidgets('updates selectedIndex after a wide-screen navigation tap', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: AppScaffold(
          body: const Text('Content'),
          navigationItems: AppNavigationItem.defaults,
        ),
      ),
    );

    await tester.tap(find.text('图片'));
    await tester.pump();

    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      3,
    );
  });

  testWidgets('keeps selected index valid when navigation items shrink', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(719, 800));
    final items = ValueNotifier(AppNavigationItem.defaults);
    addTearDown(items.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<List<AppNavigationItem>>(
          valueListenable: items,
          builder: (context, value, child) =>
              AppScaffold(body: const Text('Content'), navigationItems: value),
        ),
      ),
    );

    await tester.tap(find.text('我的'));
    await tester.pump();
    items.value = AppNavigationItem.defaults.take(2).toList();
    await tester.pump();

    expect(
      tester
          .widget<BottomNavigationBar>(
            find.byKey(const Key('bottom-navigation')),
          )
          .currentIndex,
      1,
    );
  });
}
