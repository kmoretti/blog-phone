import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../../../data/api/api_exception.dart';
import '../data/moments_api.dart';
import '../data/moments_provider.dart';
import 'moment_extension.dart';
import 'moment_extension_editor.dart';

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
  final extensionEditorKey = GlobalKey<MomentExtensionEditorState>();
  final messageLinkController = TextEditingController();
  final paths = <String>[];
  final mediaEntries = <MomentMediaEntry>[];
  final deletedMediaIds = <int>{};
  final removedMediaEntries = <MomentMediaEntry>[];
  String status = 'visible';
  bool isAd = false;
  bool isSaving = false;

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
      mediaEntries.addAll(moment.media.map(MomentMediaEntry.fromDto));
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
          MomentExtensionEditor(
            key: extensionEditorKey,
            controller: extensionController,
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
              IconButton(
                tooltip: '外链图片',
                onPressed: () => _addExternalMedia('image'),
                icon: const Icon(Icons.image_outlined),
              ),
              IconButton(
                tooltip: '外链视频',
                onPressed: () => _addExternalMedia('video'),
                icon: const Icon(Icons.video_library_outlined),
              ),
            ],
          ),
          if (paths.isNotEmpty)
            SizedBox(
              height: 96,
              child: ListView(children: paths.map(Text.new).toList()),
            ),
          if (mediaEntries.isNotEmpty)
            SizedBox(
              height: 140,
              child: ListView.builder(
                itemCount: mediaEntries.length,
                itemBuilder: (context, index) {
                  final entry = mediaEntries[index];
                  return ListTile(
                    dense: true,
                    leading: Icon(entry.mediaType == 'video' ? Icons.videocam : Icons.image),
                    title: Text(entry.url, maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _removeMedia(entry),
                    ),
                  );
                },
              ),
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
            onPressed: isSaving ? null : _submit,
            child: isSaving
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(widget.moment == null ? '保存' : '更新'),
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

  Future<void> _addExternalMedia(String mediaType) async {
    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(mediaType == 'video' ? '添加外链视频' : '添加外链图片'),
        content: TextField(
          controller: urlController,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'URL'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, urlController.text), child: const Text('添加')),
        ],
      ),
    );
    urlController.dispose();
    if (!mounted || url == null) return;
    try {
      final payload = buildExternalMediaPayload(url, mediaType);
      setState(() => mediaEntries.add(MomentMediaEntry(
        url: payload.mediaUrl,
        mediaType: payload.mediaType,
        isExisting: false,
      )));
    } on FormatException catch (error) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  void _removeMedia(MomentMediaEntry entry) {
    setState(() {
      if (entry.isExisting && entry.id != null) {
        deletedMediaIds.add(entry.id!);
        removedMediaEntries.add(entry);
      }
      mediaEntries.remove(entry);
    });
  }

  Future<void> _submit() async {
    if (isSaving) return;
    final extensionErrors = extensionEditorKey.currentState?.validateAndSync() ?? const <String>[];
    if (extensionErrors.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(extensionErrors.join('；'))));
      return;
    }
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
    setState(() => isSaving = true);
    final navigator = Navigator.of(context);
    final repository = ref.read(momentsRepositoryProvider);
    final moment = widget.moment;
    final localMedia = paths.map((filePath) => CreateMediaPayload(
      mediaUrl: filePath,
      mediaType: _mediaType(filePath),
      isLocal: 1,
      name: path.basename(filePath),
    ));
    final externalMedia = mediaEntries
        .where((entry) => !entry.isExisting)
        .map((entry) => entry.toPayload())
        .toList();
    final removedEntries = List<MomentMediaEntry>.from(removedMediaEntries);
    try {
      if (moment == null) {
        await repository.save(
          CreateMomentPayload(
            content: controller.text,
            tags: tagsController.text,
            pinnedOrder: pinnedOrder,
            isAd: isAd ? 1 : 0,
            extension: extensionController.text,
            messageLink: link,
            media: [...localMedia, ...externalMedia],
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
        for (final mediaId in deletedMediaIds) {
          await repository.api.deleteMedia(mediaId);
        }
        for (final media in externalMedia) {
          await repository.api.createMedia(moment.id, media);
        }
      }
      if (!mounted) return;
      navigator.pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        isSaving = false;
        if (removedEntries.isNotEmpty) {
          mediaEntries.addAll(removedEntries.where((entry) => !mediaEntries.contains(entry)));
          deletedMediaIds.removeAll(removedEntries.map((entry) => entry.id!));
          removedMediaEntries.removeWhere(removedEntries.contains);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    }
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
