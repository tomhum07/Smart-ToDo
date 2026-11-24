import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/routes/app_routes.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/note_model.dart';
import '../../../providers/note_provider.dart';
import '../../widgets/filter_bar_widget.dart';
import '../../widgets/swipe_to_delete_tile.dart';

/// Tab Ghi chú đa phương tiện: Thanh lọc siêu gọn 1 hàng + OrientationBuilder 2/3 cột.
class NotesTab extends StatefulWidget {
  const NotesTab({super.key});

  @override
  State<NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends State<NotesTab> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BuildContext context, NoteModel note) async {
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (ctx) => ShadDialog.alert(
        title: const Text('Xóa ghi chú?'),
        description: Text('Bạn có chắc muốn xóa ghi chú "${note.title}" không?'),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ShadButton.destructive(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<NoteProvider>().deleteNote(note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteProvider = context.watch<NoteProvider>();
    final notes = noteProvider.filteredNotes;

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: FilterBarWidget(
              searchController: _searchController,
              searchPlaceholder: 'Tìm kiếm ghi chú...',
              selectedCategory: noteProvider.selectedCategory,
              selectedPriority: noteProvider.selectedPriority,
              activeFilterCount: noteProvider.activeFilterCount,
              onSearchChanged: noteProvider.setSearchQuery,
              onCategoryChanged: noteProvider.setCategory,
              onPriorityChanged: noteProvider.setPriority,
              onResetFilters: () {
                _searchController.clear();
                noteProvider.resetFilters();
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: noteProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : notes.isEmpty
                    ? _buildEmptyState(context, noteProvider)
                    : OrientationBuilder(
                        builder: (context, orientation) {
                          final crossAxisCount =
                              orientation == Orientation.landscape ? 3 : 2;
                          return GridView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio:
                                  orientation == Orientation.landscape
                                      ? 1.05
                                      : 0.85,
                            ),
                            itemCount: notes.length,
                            itemBuilder: (context, index) {
                              final note = notes[index];
                              return SwipeToDeleteTile(
                                key: ValueKey('swipe_note_${note.id}'),
                                actionWidth: 72,
                                onDelete: () => _confirmDelete(context, note),
                                child: _NoteGridCard(
                                  note: note,
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.noteEditor,
                                    arguments: note,
                                  ),
                                  onDelete: () => _confirmDelete(context, note),
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'notes_add_btn',
        tooltip: 'Ghi chú mới',
        onPressed: () => Navigator.pushNamed(context, AppRoutes.noteEditor),
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, NoteProvider provider) {
    final hasFilter =
        provider.searchQuery.isNotEmpty || provider.activeFilterCount > 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.stickyNote, size: 48),
            const SizedBox(height: 12),
            Text(
              hasFilter
                  ? 'Không tìm thấy ghi chú phù hợp.'
                  : 'Chưa có ghi chú nào.\nBấm nút + để tạo thẻ ghi chú đầu tiên!',
              textAlign: TextAlign.center,
            ),
            if (hasFilter) ...[
              const SizedBox(height: 12),
              ShadButton.outline(
                onPressed: () {
                  _searchController.clear();
                  provider.resetFilters();
                },
                child: const Text('Xóa bộ lọc'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteGridCard extends StatelessWidget {
  final NoteModel note;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NoteGridCard({
    required this.note,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDefaultWhite = note.colorHex.toUpperCase() == '#FFFFFF';
    final cardBg = isDefaultWhite
        ? (isDark ? const Color(0xFF18181B) : Colors.white)
        : AppColors.fromHex(note.colorHex);
    final textColor = (isDefaultWhite && isDark)
        ? const Color(0xFFFAFAFA)
        : const Color(0xFF18181B);
    final mutedColor = textColor.withValues(alpha: 0.65);
    final priorityColor = AppColors.priorityColor(note.priority);

    return Material(
      color: cardBg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: textColor,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onDelete,
                    child: Icon(
                      LucideIcons.trash2,
                      size: 15,
                      color: mutedColor,
                    ),
                  ),
                ],
              ),
              if (note.hasImages) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 68,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildThumbnail(note),
                        if (note.totalImages > 1)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '+${note.totalImages - 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  note.content.isEmpty ? '(Không có nội dung)' : note.content,
                  maxLines: note.hasImages ? 2 : 5,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: mutedColor),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        AppColors.priorityLabel(note.priority),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: priorityColor,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        DateFormatter.formatEpochDate(note.updatedAt),
                        style: TextStyle(fontSize: 10, color: mutedColor),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(NoteModel n) {
    for (final path in n.localImagePaths) {
      if (File(path).existsSync()) {
        return Image.file(File(path), fit: BoxFit.cover);
      }
    }
    if (n.remoteImageUrls.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: n.remoteImageUrls.first,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => const Icon(LucideIcons.imageOff),
      );
    }
    return const SizedBox.shrink();
  }
}
