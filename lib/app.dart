import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/memoflow_theme.dart';
import 'features/auth/login_screen.dart';
import 'features/home/home_shell.dart';
import 'state/auth/auth_provider.dart';
import 'state/settings/settings_provider.dart';

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  StreamSubscription<List<ConnectivityResult>>? _networkSubscription;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(authProvider.notifier).restore();
      _networkSubscription = NetworkRefreshStartup(
        stream: Connectivity().onConnectivityChanged,
        onOnline: ref.read(networkCoordinatorProvider).refresh,
      ).start();
    });
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    return MaterialApp(
      title: 'blog-api',
      theme: MemoFlowTheme.light,
      darkTheme: MemoFlowTheme.dark,
      home: _homeFor(state),
    );
  }

  Widget _homeFor(AuthState state) {
    if (state is AuthenticatedState || state is GuestState) {
      return const HomeShell();
    }
    if (state is ErrorState) {
      return LoginScreen(errorMessage: state.message);
    }
    if (state is LoginState) {
      return const LoginScreen();
    }
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
