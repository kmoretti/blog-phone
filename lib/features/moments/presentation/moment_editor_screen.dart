import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../data/moments_api.dart';
import '../data/moments_provider.dart';
import 'moment_extension.dart';

class MomentEditorScreen extends ConsumerStatefulWidget {
  const MomentEditorScreen({super.key, this.moment});
  final MomentDto? moment;
  @override
  ConsumerState<MomentEditorScreen> createState() => _MomentEditorScreenState();
}

class _MomentEditorScreenState extends ConsumerState<MomentEditorScreen> {
  final controller = TextEditingController();
  final tagsController = TextEditingController();
  final pinnedOrderController = TextEditingController();
  final extensionController = TextEditingController();
  final messageLinkController = TextEditingController();
  final paths = <String>[];
  String status = 'visible';
  bool isAd = false;

  @override
  void initState() {
    super.initState();
    final moment = widget.moment;
    if (moment != null) {
      controller.text = moment.content;
      tagsController.text = moment.tags;
      pinnedOrderController.text = moment.pinnedOrder.toString();
      extensionController.text = moment.extension;
      messageLinkController.text = moment.messageLink;
      status = moment.status;
      isAd = moment.isAd == 1;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.moment == null ? '发布动态' : '编辑动态')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(labelText: '正文'),
          ),
          TextField(
            controller: tagsController,
            decoration: const InputDecoration(labelText: '标签'),
          ),
          TextField(
            controller: pinnedOrderController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: '置顶顺序'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('广告'),
            value: isAd,
            onChanged: (value) => setState(() => isAd = value),
          ),
          TextField(
            controller: extensionController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Extension'),
          ),
          TextField(
            controller: messageLinkController,
            decoration: const InputDecoration(labelText: '来源链接'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final file = await FilePicker.platform.pickFiles(type: FileType.media);
                  if (file != null && file.files.single.path != null) {
                    setState(() => paths.add(file.files.single.path!));
                  }
                },
                icon: const Icon(Icons.attach_file),
              ),
              IconButton(
                onPressed: () async {
                  final file = await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (file != null) setState(() => paths.add(file.path));
                },
                icon: const Icon(Icons.photo_library),
              ),
              IconButton(
                onPressed: () async {
                  final file = await ImagePicker().pickImage(source: ImageSource.camera);
                  if (file != null) setState(() => paths.add(file.path));
                },
                icon: const Icon(Icons.camera_alt),
              ),
            ],
          ),
          if (paths.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView(children: paths.map(Text.new).toList()),
            ),
          if (widget.moment != null)
            DropdownButtonFormField<String>(
              initialValue: status,
              decoration: const InputDecoration(labelText: '状态'),
              items: const [
                DropdownMenuItem(value: 'visible', child: Text('发布')),
                DropdownMenuItem(value: 'hidden', child: Text('隐藏')),
                DropdownMenuItem(value: 'deleted', child: Text('删除')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => status = value);
              },
            ),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.moment == null ? '保存' : '更新'),
          ),
          if (widget.moment != null)
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref.read(momentsRepositoryProvider).api.delete(widget.moment!.id);
                if (!mounted) return;
                navigator.pop();
              },
              child: const Text('删除动态'),
            ),
        ],
      ),
    ),
  );

  Future<void> _submit() async {
    final pinnedOrder = int.tryParse(pinnedOrderController.text.trim());
    if (pinnedOrder == null || pinnedOrder < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('置顶顺序必须是非负整数')));
      return;
    }
    final link = messageLinkController.text.trim();
    if (link.isNotEmpty && !isHttpUrl(link)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('来源链接必须是 HTTP(S) 地址')));
      return;
    }
    final navigator = Navigator.of(context);
    final repository = ref.read(momentsRepositoryProvider);
    final moment = widget.moment;
    if (moment == null) {
      await repository.save(
        CreateMomentPayload(
          content: controller.text,
          tags: tagsController.text,
          pinnedOrder: pinnedOrder,
          isAd: isAd ? 1 : 0,
          extension: extensionController.text,
          messageLink: link,
          media: paths.map((filePath) => CreateMediaPayload(
            mediaUrl: filePath,
            mediaType: _mediaType(filePath),
            isLocal: 1,
            name: path.basename(filePath),
          )).toList(),
        ),
      );
    } else {
      await repository.api.update(
        moment.id,
        UpdateMomentPayload(
          content: controller.text,
          status: status,
          tags: tagsController.text,
          pinnedOrder: pinnedOrder,
          isAd: isAd ? 1 : 0,
          extension: extensionController.text,
          messageLink: link,
        ),
      );
    }
    if (!mounted) return;
    navigator.pop();
  }

  @override
  void dispose() {
    controller.dispose();
    tagsController.dispose();
    pinnedOrderController.dispose();
    extensionController.dispose();
    messageLinkController.dispose();
    super.dispose();
  }
}

int validatePinnedOrder(String value) {
  final parsed = int.tryParse(value.trim());
  if (parsed == null || parsed < 0) throw const FormatException('pinned_order must be a non-negative integer');
  return parsed;
}

String _mediaType(String filePath) {
  final extension = path.extension(filePath).toLowerCase();
  return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(extension) ? 'video' : 'image';
}
