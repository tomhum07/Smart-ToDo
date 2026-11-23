import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/note_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/note_provider.dart';

/// Màn hình Soạn thảo Ghi chú đa phương tiện: 7 màu thẻ, ưu tiên & đính kèm NHIỀU ảnh.
class NoteEditorScreen extends StatefulWidget {
  final NoteModel? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _picker = ImagePicker();

  late String _colorHex;
  late String _category;
  late int _priority;
  late List<String> _localImagePaths;
  late List<String> _remoteImageUrls;
  String? _validationError;
  bool _isSaving = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleController.text = n?.title ?? '';
    _contentController.text = n?.content ?? '';
    _colorHex = n?.colorHex ?? AppColors.noteColorHexes.first;
    _category = n?.category ?? AppColors.defaultCategories.first;
    _priority = n?.priority ?? 1;
    _localImagePaths = List<String>.from(n?.localImagePaths ?? const []);
    _remoteImageUrls = List<String>.from(n?.remoteImageUrls ?? const []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Chọn nhiều ảnh cùng lúc từ thư viện và thêm vào danh sách ảnh của ghi chú.
  Future<void> _pickMultipleImages() async {
    final pickedFiles = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1280,
    );
    if (pickedFiles.isEmpty) return;
    setState(() {
      for (final file in pickedFiles) {
        if (!_localImagePaths.contains(file.path)) {
          _localImagePaths.add(file.path);
        }
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _validationError = 'Vui lòng nhập tiêu đề ghi chú.');
      return;
    }

    setState(() {
      _validationError = null;
      _isSaving = true;
    });

    final auth = context.read<AuthProvider>();
    final noteProvider = context.read<NoteProvider>();

    try {
      await noteProvider.saveNote(
        existing: widget.note,
        userId: auth.effectiveUserId,
        title: title,
        content: _contentController.text.trim(),
        colorHex: _colorHex,
        priority: _priority,
        category: _category,
        localImagePaths: _localImagePaths,
        remoteImageUrls: _remoteImageUrls,
      );
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);
    final validLocalPaths =
        _localImagePaths.where((p) => File(p).existsSync()).toList();
    final totalCount = validLocalPaths.length +
        (validLocalPaths.isEmpty ? _remoteImageUrls.length : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa ghi chú' : 'Ghi chú mới'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ShadCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Tiêu đề *', style: shadTheme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _titleController,
                    placeholder: const Text('VD: Ghi chú ôn thi Flutter'),
                  ),
                  const SizedBox(height: 14),
                  Text('Nội dung', style: shadTheme.textTheme.small),
                  const SizedBox(height: 6),
                  ShadInput(
                    controller: _contentController,
                    placeholder: const Text('Viết nội dung ghi chú tại đây...'),
                    maxLines: 6,
                  ),
                  const SizedBox(height: 16),
                  Text('Màu sắc thẻ', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: AppColors.noteColorHexes.map((hex) {
                      final isSelected = _colorHex == hex;
                      return GestureDetector(
                        onTap: () => setState(() => _colorHex = hex),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: AppColors.fromHex(hex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? shadTheme.colorScheme.primary
                                  : Colors.grey.shade400,
                              width: isSelected ? 3 : 1,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  LucideIcons.check,
                                  size: 16,
                                  color: Colors.black87,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Danh mục', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: AppColors.defaultCategories.map((cat) {
                      return ChoiceChip(
                        label: Text(cat),
                        selected: _category == cat,
                        onSelected: (_) => setState(() => _category = cat),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Mức độ ưu tiên', style: shadTheme.textTheme.small),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [2, 1, 0].map((p) {
                      return ChoiceChip(
                        label: Text(AppColors.priorityLabel(p)),
                        selected: _priority == p,
                        avatar: CircleAvatar(
                          radius: 5,
                          backgroundColor: AppColors.priorityColor(p),
                        ),
                        onSelected: (_) => setState(() => _priority = p),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ảnh đính kèm ($totalCount)',
                        style: shadTheme.textTheme.small,
                      ),
                      if (totalCount > 0)
                        ShadButton.ghost(
                          onPressed: () => setState(() {
                            _localImagePaths.clear();
                            _remoteImageUrls.clear();
                          }),
                          child: const Text('Xóa tất cả'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (validLocalPaths.isNotEmpty) ...[
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: validLocalPaths.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final path = validLocalPaths[index];
                          return _ImagePreviewTile(
                            image: Image.file(File(path), fit: BoxFit.cover),
                            onRemove: () => setState(
                              () => _localImagePaths.remove(path),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else if (_remoteImageUrls.isNotEmpty) ...[
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _remoteImageUrls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final url = _remoteImageUrls[index];
                          return _ImagePreviewTile(
                            image: CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                            ),
                            onRemove: () => setState(
                              () => _remoteImageUrls.remove(url),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  ShadButton.outline(
                    onPressed: _pickMultipleImages,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.imagePlus, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          totalCount > 0
                              ? 'Thêm ảnh khác từ thư viện'
                              : 'Chọn ảnh từ thư viện (nhiều ảnh)',
                        ),
                      ],
                    ),
                  ),
                  if (_validationError != null) ...[
                    const SizedBox(height: 14),
                    ShadAlert.destructive(
                      icon: const Icon(LucideIcons.circleAlert),
                      title: const Text('Thiếu thông tin'),
                      description: Text(_validationError!),
                    ),
                  ],
                  const SizedBox(height: 20),
                  ShadButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_isEditing ? 'Lưu ghi chú' : 'Tạo ghi chú'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImagePreviewTile extends StatelessWidget {
  final Widget image;
  final VoidCallback onRemove;

  const _ImagePreviewTile({
    required this.image,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(width: 120, height: 120, child: image),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.x,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
