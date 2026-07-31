import 'dart:convert';

import 'package:flutter/material.dart';

import 'moment_extension.dart';

const momentExtensionTypes = <String, String>{
  'github': 'GitHub 仓库',
  'website': '网站链接',
  'location': '位置',
  'music': '音乐',
  'tweet': '推文',
};

String buildMomentExtensionJson({required String type, required Map<String, dynamic> values}) {
  return jsonEncode({'type': type, 'payload': values});
}

class MomentExtensionDraft {
  MomentExtensionDraft({required this.type, Map<String, dynamic>? values, this.rawJson, this.isAdvanced = false})
      : values = Map<String, dynamic>.from(values ?? const {});

  final String type;
  final Map<String, dynamic> values;
  final String? rawJson;
  final bool isAdvanced;

  factory MomentExtensionDraft.fromJsonString(String? input) {
    final raw = input?.trim() ?? '';
    if (raw.isEmpty) return MomentExtensionDraft(type: 'github');
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['type'] is! String || decoded['payload'] is! Map) {
        return MomentExtensionDraft(type: '', rawJson: raw, isAdvanced: true);
      }
      final type = decoded['type'] as String;
      final payload = Map<String, dynamic>.from(decoded['payload'] as Map);
      if (!momentExtensionTypes.containsKey(type) || _validate(type, payload).isNotEmpty) {
        return MomentExtensionDraft(type: type, values: payload, rawJson: raw, isAdvanced: true);
      }
      return MomentExtensionDraft(type: type, values: payload);
    } catch (_) {
      return MomentExtensionDraft(type: '', rawJson: raw, isAdvanced: true);
    }
  }

  List<String> validate() {
    if (isAdvanced) return rawJson == null || rawJson!.trim().isEmpty ? ['高级 JSON 不能为空'] : _validJson(rawJson!);
    return _validate(type, values);
  }

  String toJsonString() {
    if (isAdvanced && rawJson != null) return rawJson!;
    return buildMomentExtensionJson(type: type, values: values);
  }

  static List<String> _validJson(String raw) {
    try {
      final value = jsonDecode(raw);
      return value is Map && value['type'] is String && value['payload'] is Map ? const [] : ['高级 JSON 必须是包含 type 和 payload 的对象'];
    } catch (_) {
      return ['高级 JSON 格式无效'];
    }
  }

  static List<String> _validate(String type, Map<String, dynamic> values) {
    final errors = <String>[];
    void required(String key, String label) {
      final value = values[key];
      if (value is! String || value.trim().isEmpty) errors.add('$label不能为空');
    }
    void url(String key, String label) {
      required(key, label);
      final value = values[key];
      if (value is String && value.trim().isNotEmpty && !isHttpUrl(value)) errors.add('$label必须是 HTTP(S) 地址');
    }
    switch (type) {
      case 'github':
        url('repo_url', '仓库地址');
      case 'website':
        required('title', '标题');
        url('site', '网站地址');
      case 'location':
        required('placeholder', '位置名称');
        _coordinate(values, 'latitude', '纬度', -90, 90, errors);
        _coordinate(values, 'longitude', '经度', -180, 180, errors);
      case 'music':
        url('url', '音乐地址');
      case 'tweet':
        url('url', '推文地址');
        required('username', '用户名');
        required('status_id', '状态 ID');
      default:
        errors.add('不支持的卡片类型');
    }
    return errors;
  }

  static void _coordinate(Map<String, dynamic> values, String key, String label, double min, double max, List<String> errors) {
    final value = values[key];
    final number = value is num ? value.toDouble() : double.tryParse('$value');
    if (number == null || !number.isFinite) {
      errors.add('$label必须是有限数字');
    } else if (number < min || number > max) {
      errors.add('$label超出范围');
    }
  }
}

class MomentExtensionEditor extends StatefulWidget {
  const MomentExtensionEditor({super.key, required this.controller, this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  @override
  MomentExtensionEditorState createState() => MomentExtensionEditorState();
}

class MomentExtensionEditorState extends State<MomentExtensionEditor> {
  late MomentExtensionDraft draft;
  final fieldControllers = <String, TextEditingController>{};
  late final TextEditingController advancedController;
  String? error;
  bool editing = false;

  @override
  void initState() {
    super.initState();
    draft = MomentExtensionDraft.fromJsonString(widget.controller.text);
    editing = widget.controller.text.trim().isNotEmpty && draft.type.isNotEmpty;
    advancedController = TextEditingController(text: draft.rawJson ?? '');
    _loadFields();
  }

  void _loadFields() {
    for (final controller in fieldControllers.values) {
      controller.dispose();
    }
    fieldControllers.clear();
    for (final key in _fieldsFor(draft.type)) {
      fieldControllers[key] = TextEditingController(text: '${draft.values[key] ?? ''}');
    }
  }

  List<String> _fieldsFor(String type) => switch (type) {
        'github' => ['repo_url'],
        'website' => ['title', 'site'],
        'location' => ['placeholder', 'latitude', 'longitude'],
        'music' => ['url', 'title', 'artist'],
        'tweet' => ['url', 'username', 'status_id', 'text'],
        _ => const [],
      };

  void _selectType(String? type) {
    if (type == null) return;
    setState(() {
      draft = MomentExtensionDraft(type: type, values: draft.values);
      editing = true;
      error = null;
      _loadFields();
    });
  }

  void _startEditing() {
    setState(() {
      editing = true;
      error = null;
      advancedController.text = draft.rawJson ?? advancedController.text;
      _loadFields();
    });
  }

  void _startAdvancedEditing() {
    setState(() {
      editing = true;
      draft = MomentExtensionDraft(type: '', rawJson: advancedController.text, isAdvanced: true);
      error = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      editing = false;
      draft = MomentExtensionDraft.fromJsonString(widget.controller.text);
      error = null;
      _loadFields();
    });
  }

  List<String> _validateDraft() {
    final values = Map<String, dynamic>.from(draft.values);
    for (final entry in fieldControllers.entries) {
      final value = entry.value.text.trim();
      if (value.isEmpty) {
        values.remove(entry.key);
      } else {
        values[entry.key] = entry.key == 'latitude' || entry.key == 'longitude' ? double.tryParse(value) ?? value : value;
      }
    }
    draft = MomentExtensionDraft(type: draft.type, values: values);
    return draft.validate();
  }

  List<String> validateAndSync() {
    if (!editing) return const [];
    if (draft.isAdvanced) {
      draft = MomentExtensionDraft(type: '', rawJson: advancedController.text.trim(), isAdvanced: true);
    } else {
      _validateDraft();
    }
    final errors = draft.validate();
    if (errors.isEmpty) _publish(draft.toJsonString());
    if (mounted) setState(() => error = errors.isEmpty ? null : errors.join('；'));
    return errors;
  }

  void _save() {
    final errors = validateAndSync();
    if (errors.isEmpty && mounted) setState(() => editing = false);
  }

  void _publish(String value) {
    widget.controller.text = value;
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    if (!editing) {
      final extension = MomentExtension.fromJsonString(widget.controller.text);
      if (draft.isAdvanced && draft.rawJson != null && draft.rawJson != widget.controller.text.trim()) {
        draft = MomentExtensionDraft.fromJsonString(widget.controller.text);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (extension == null || !extension.isKnown)
            Text(extension != null && !extension.isKnown ? '未知卡片类型，已保留原始 JSON。可在高级编辑中修改。' : '暂无卡片'),
          if (extension != null && extension.isKnown) MomentExtensionCard(extension: extension),
          TextButton(onPressed: _startEditing, child: Text(draft.isAdvanced ? '继续编辑' : '添加卡片')),
          TextButton(onPressed: _startAdvancedEditing, child: const Text('高级编辑')),
        ],
      );
    }
    if (draft.isAdvanced) return _buildAdvanced();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: momentExtensionTypes.containsKey(draft.type) ? draft.type : null,
              decoration: const InputDecoration(labelText: 'Extension 卡片类型'),
              items: momentExtensionTypes.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
              onChanged: _selectType,
            ),
            ...fieldControllers.entries.map((entry) => TextField(controller: entry.value, decoration: InputDecoration(labelText: _label(entry.key)), keyboardType: entry.key == 'latitude' || entry.key == 'longitude' ? TextInputType.number : TextInputType.text)),
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Row(
              children: [
                FilledButton(onPressed: _save, child: const Text('保存卡片')),
                TextButton(onPressed: _cancelEditing, child: const Text('取消')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvanced() {
    advancedController.text = draft.rawJson ?? advancedController.text;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('未知卡片类型，已保留原始 JSON。可在高级编辑中修改。'),
            TextField(controller: advancedController, maxLines: 6, decoration: const InputDecoration(labelText: '高级 JSON')),
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            Row(
              children: [
                FilledButton(onPressed: () {
                  final next = MomentExtensionDraft(type: '', rawJson: advancedController.text.trim(), isAdvanced: true);
                  final errors = next.validate();
                  setState(() { draft = next; error = errors.isEmpty ? null : errors.join('；'); });
                  if (errors.isEmpty) {
                    _publish(next.toJsonString());
                    setState(() => editing = false);
                  }
                }, child: const Text('保留高级 JSON')),
                TextButton(onPressed: _cancelEditing, child: const Text('取消')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _label(String key) => const {'repo_url': '仓库地址', 'title': '标题', 'site': '网站地址', 'placeholder': '位置名称', 'latitude': '纬度', 'longitude': '经度', 'url': '地址', 'artist': '艺术家', 'username': '用户名', 'status_id': '状态 ID', 'text': '正文'}[key] ?? key;

  @override
  void dispose() {
    for (final controller in fieldControllers.values) {
      controller.dispose();
    }
    advancedController.dispose();
    super.dispose();
  }
}
