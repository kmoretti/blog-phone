import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;

import '../data/moments_api.dart';
import '../data/moments_provider.dart';

class MomentEditorScreen extends ConsumerStatefulWidget {
  const MomentEditorScreen({super.key, this.moment});
  final MomentDto? moment;
  @override
  ConsumerState<MomentEditorScreen> createState() => _MomentEditorScreenState();
}

class _MomentEditorScreenState extends ConsumerState<MomentEditorScreen> {
  final controller = TextEditingController();
  final paths = <String>[];
  String status = 'visible';

  @override
  void initState() {
    super.initState();
    final moment = widget.moment;
    if (moment != null) {
      controller.text = moment.content;
      status = moment.status;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.moment == null ? '发布动态' : '编辑动态')),
    body: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: controller,
            maxLines: 8,
            decoration: const InputDecoration(labelText: '正文'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton(
                onPressed: () async {
                  final file = await FilePicker.platform.pickFiles(
                    type: FileType.media,
                  );
                  if (file != null && file.files.single.path != null) {
                    setState(() => paths.add(file.files.single.path!));
                  }
                },
                icon: const Icon(Icons.attach_file),
              ),
              IconButton(
                onPressed: () async {
                  final file = await ImagePicker().pickImage(
                    source: ImageSource.gallery,
                  );
                  if (file != null) setState(() => paths.add(file.path));
                },
                icon: const Icon(Icons.photo_library),
              ),
              IconButton(
                onPressed: () async {
                  final file = await ImagePicker().pickImage(
                    source: ImageSource.camera,
                  );
                  if (file != null) setState(() => paths.add(file.path));
                },
                icon: const Icon(Icons.camera_alt),
              ),
            ],
          ),
          Expanded(child: ListView(children: paths.map(Text.new).toList())),
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
            onPressed: () async {
              final navigator = Navigator.of(context);
              final repository = ref.read(momentsRepositoryProvider);
              final moment = widget.moment;
              if (moment == null) {
                await repository.save(
                  CreateMomentPayload(
                    content: controller.text,
                    media: paths
                        .map(
                          (filePath) => CreateMediaPayload(
                            mediaUrl: filePath,
                            mediaType: _mediaType(filePath),
                            isLocal: 1,
                            name: path.basename(filePath),
                          ),
                        )
                        .toList(),
                  ),
                );
              } else {
                await repository.api.update(
                  moment.id,
                  UpdateMomentPayload(content: controller.text, status: status),
                );
              }
              if (!mounted) return;
              navigator.pop();
            },
            child: Text(widget.moment == null ? '保存' : '更新'),
          ),
          if (widget.moment != null)
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await ref
                    .read(momentsRepositoryProvider)
                    .api
                    .delete(widget.moment!.id);
                if (!mounted) return;
                navigator.pop();
              },
              child: const Text('删除动态'),
            ),
        ],
      ),
    ),
  );
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

String _mediaType(String filePath) {
  final extension = path.extension(filePath).toLowerCase();
  return ['.mp4', '.mov', '.avi', '.mkv', '.webm'].contains(extension)
      ? 'video'
      : 'image';
}
