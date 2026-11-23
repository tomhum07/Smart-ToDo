import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/constants/app_colors.dart';

/// Thanh tìm kiếm + nút Bộ lọc siêu gọn (1 hàng duy nhất), bấm Bộ lọc mở BottomSheet chi tiết.
class FilterBarWidget extends StatelessWidget {
  final TextEditingController searchController;
  final String searchPlaceholder;
  final String selectedCategory;
  final int? selectedPriority;
  final int activeFilterCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<int?> onPriorityChanged;
  final VoidCallback onResetFilters;
  final Widget Function(StateSetter setModalState)? extraSheetBuilder;

  const FilterBarWidget({
    super.key,
    required this.searchController,
    required this.searchPlaceholder,
    required this.selectedCategory,
    required this.selectedPriority,
    required this.activeFilterCount,
    required this.onSearchChanged,
    required this.onCategoryChanged,
    required this.onPriorityChanged,
    required this.onResetFilters,
    this.extraSheetBuilder,
  });

  void _openFilterSheet(BuildContext context) {
    final categories = ['Tất cả', ...AppColors.defaultCategories];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        var currentCategory = selectedCategory;
        var currentPriority = selectedPriority;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final shadTheme = ShadTheme.of(ctx);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Bộ lọc & Sắp xếp', style: shadTheme.textTheme.h4),
                          ShadButton.ghost(
                            onPressed: () {
                              onResetFilters();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Đặt lại'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text('Danh mục', style: shadTheme.textTheme.small),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: categories.map((cat) {
                          return ChoiceChip(
                            label: Text(cat),
                            selected: currentCategory == cat,
                            onSelected: (_) {
                              setModalState(() => currentCategory = cat);
                              onCategoryChanged(cat);
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Text('Mức độ ưu tiên', style: shadTheme.textTheme.small),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _priorityChip(
                            label: 'Tất cả',
                            value: null,
                            selectedValue: currentPriority,
                            onTap: () {
                              setModalState(() => currentPriority = null);
                              onPriorityChanged(null);
                            },
                          ),
                          _priorityChip(
                            label: 'Cao',
                            value: 2,
                            selectedValue: currentPriority,
                            onTap: () {
                              setModalState(() => currentPriority = 2);
                              onPriorityChanged(2);
                            },
                          ),
                          _priorityChip(
                            label: 'Trung bình',
                            value: 1,
                            selectedValue: currentPriority,
                            onTap: () {
                              setModalState(() => currentPriority = 1);
                              onPriorityChanged(1);
                            },
                          ),
                          _priorityChip(
                            label: 'Thấp',
                            value: 0,
                            selectedValue: currentPriority,
                            onTap: () {
                              setModalState(() => currentPriority = 0);
                              onPriorityChanged(0);
                            },
                          ),
                        ],
                      ),
                      if (extraSheetBuilder != null) ...[
                        const SizedBox(height: 16),
                        extraSheetBuilder!(setModalState),
                      ],
                      const SizedBox(height: 20),
                      ShadButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Xong'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _priorityChip({
    required String label,
    required int? value,
    required int? selectedValue,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selectedValue == value,
      avatar: value == null
          ? null
          : CircleAvatar(
              radius: 5,
              backgroundColor: AppColors.priorityColor(value),
            ),
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shadTheme = ShadTheme.of(context);

    return Row(
      children: [
        Expanded(
          child: ShadInput(
            controller: searchController,
            placeholder: Text(searchPlaceholder),
            leading: const Padding(
              padding: EdgeInsets.only(right: 6),
              child: Icon(LucideIcons.search, size: 16),
            ),
            trailing: searchController.text.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      searchController.clear();
                      onSearchChanged('');
                    },
                    child: const Icon(LucideIcons.x, size: 16),
                  )
                : null,
            onChanged: onSearchChanged,
          ),
        ),
        const SizedBox(width: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            ShadButton.outline(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              onPressed: () => _openFilterSheet(context),
              child: const Icon(LucideIcons.slidersHorizontal, size: 18),
            ),
            if (activeFilterCount > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: shadTheme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  child: Center(
                    child: Text(
                      '$activeFilterCount',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: shadTheme.colorScheme.primaryForeground,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
