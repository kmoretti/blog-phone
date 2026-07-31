import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api/api_exception.dart';
import '../../data/models/auth_models.dart';
import '../../state/auth/auth_provider.dart';
import '../../state/settings/settings_provider.dart';

abstract interface class TurnstileTokenProvider {
  Future<String?> acquireToken({required String siteKey});
}

class UnconfiguredTurnstileTokenProvider implements TurnstileTokenProvider {
  const UnconfiguredTurnstileTokenProvider();

  @override
  Future<String?> acquireToken({required String siteKey}) async => null;
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.errorMessage,
    this.turnstileTokenProvider = const UnconfiguredTurnstileTokenProvider(),
  });

  final String? errorMessage;
  final TurnstileTokenProvider turnstileTokenProvider;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serverController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  String _turnstileToken = '';
  TurnstileConfig _turnstile = const TurnstileConfig(
    enabled: false,
    siteKey: '',
  );
  String? _configError;

  @override
  void dispose() {
    _serverController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    ref.listen(serverUrlProvider, (_, next) {
      next.whenData((value) {
        if (value != null && _serverController.text.isEmpty) {
          _serverController.text = value;
        }
      });
    });
    final errorMessage = state is ErrorState
        ? state.message
        : widget.errorMessage;
    return Scaffold(
      appBar: AppBar(title: const Text('登录')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  key: const Key('server-url-field'),
                  controller: _serverController,
                  decoration: const InputDecoration(labelText: '服务器地址'),
                  validator: _serverValidator,
                  keyboardType: TextInputType.url,
                ),
                TextFormField(
                  key: const Key('username-field'),
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: '用户名'),
                  validator: _required('请输入用户名'),
                ),
                TextFormField(
                  key: const Key('password-field'),
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: '密码'),
                  obscureText: true,
                  validator: _required('请输入密码'),
                ),
                if (_turnstile.enabled)
                  _TurnstileRegion(
                    siteKey: _turnstile.siteKey,
                    token: _turnstileToken,
                    onTokenChanged: (value) =>
                        setState(() => _turnstileToken = value),
                  ),
                if (_configError != null)
                  Text(_configError!, key: const Key('turnstile-error')),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('login-button'),
                  onPressed: state is LoadingState ? null : _login,
                  child: const Text('登录'),
                ),
                TextButton(
                  key: const Key('guest-button'),
                  onPressed: () =>
                      ref.read(authProvider.notifier).continueAsGuest(),
                  child: const Text('游客进入'),
                ),
                if (errorMessage != null)
                  Text(errorMessage, key: const Key('login-error')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _serverValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入服务器地址';
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return '请输入有效的服务器地址';
    return null;
  }

  String? Function(String?) _required(String message) => (value) {
    return value == null || value.trim().isEmpty ? message : null;
  };

  String _configErrorMessage(ApiException error) {
    if (error.isNetworkError || error.isTimeout) {
      return '无法连接服务器，请检查网络连接和服务器地址';
    }
    if (error.statusCode == 404 || error.code == 404) {
      return '服务器不支持验证配置接口，请确认 API 地址填写的是根域名';
    }
    return '验证配置加载失败：${error.message}';
  }

  Future<bool> _loadVerifyConfig(String server) async {
    try {
      final config = await ref
          .read(authRepositoryProvider)
          .getVerifyConfig(server);
      if (!mounted) return false;
      setState(() {
        _turnstile = config.turnstile;
        _configError = null;
      });
      return true;
    } on ApiException catch (error) {
      if (mounted) setState(() => _configError = _configErrorMessage(error));
      return false;
    } catch (error) {
      if (mounted) setState(() => _configError = '验证配置加载失败：$error');
      return false;
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    final server = _serverController.text.trim();
    if (!await _loadVerifyConfig(server) || !mounted) return;
    if (_turnstile.enabled) {
      final token = await widget.turnstileTokenProvider.acquireToken(
        siteKey: _turnstile.siteKey,
      );
      if (!mounted) return;
      if (token == null || token.trim().isEmpty) {
        setState(() => _configError = '请完成安全验证');
        return;
      }
      _turnstileToken = token;
    }
    await ref
        .read(authProvider.notifier)
        .login(
          baseUrl: server,
          username: _usernameController.text.trim(),
          password: _passwordController.text,
          turnstileToken: _turnstileToken,
        );
  }
}

class _TurnstileRegion extends StatelessWidget {
  const _TurnstileRegion({
    required this.siteKey,
    required this.token,
    required this.onTokenChanged,
  });

  final String siteKey;
  final String token;
  final ValueChanged<String> onTokenChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('turnstile-region'),
      children: [
        const Text('需要完成安全验证'),
        TextFormField(
          key: const Key('turnstile-token-field'),
          decoration: const InputDecoration(labelText: '验证令牌'),
          initialValue: token,
          onChanged: onTokenChanged,
        ),
      ],
    );
  }
}
