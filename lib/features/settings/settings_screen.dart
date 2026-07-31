import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/auth/auth_provider.dart';
import '../../state/settings/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _serverController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _serverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final savedUrl = ref.watch(serverUrlProvider);
    savedUrl.whenData((value) {
      if (value != null && _serverController.text.isEmpty) {
        _serverController.text = value;
      }
    });
    final sessionUrl = state is AuthenticatedState ? state.session.baseUrl : null;

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Form(
            key: _formKey,
            child: TextFormField(
              key: const Key('settings-server-url-field'),
              controller: _serverController,
              decoration: const InputDecoration(
                labelText: '下次登录默认服务器地址',
              ),
              keyboardType: TextInputType.url,
              validator: _validateUrl,
            ),
          ),
          if (sessionUrl != null) ...[
            const SizedBox(height: 16),
            Text('当前会话地址：$sessionUrl', key: const Key('session-base-url')),
            const SizedBox(height: 4),
            const Text('修改默认地址不会影响当前已登录会话。'),
          ],
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('save-server-url-button'),
            onPressed: _saving ? null : _save,
            child: const Text('保存默认地址'),
          ),
          OutlinedButton(
            key: const Key('network-refresh-button'),
            onPressed: () {
              ref.read(networkCoordinatorProvider).refresh();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已触发联网刷新')),
              );
            },
            child: const Text('联网刷新'),
          ),
        ],
      ),
    );
  }

  String? _validateUrl(String? value) {
    final text = value?.trim() ?? '';
    final uri = Uri.tryParse(text);
    if (text.isEmpty || uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return '请输入有效的服务器地址';
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await ref.read(authProvider.notifier).saveServerUrl(_serverController.text);
    ref.invalidate(serverUrlProvider);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已保存')),
      );
    }
  }
}
