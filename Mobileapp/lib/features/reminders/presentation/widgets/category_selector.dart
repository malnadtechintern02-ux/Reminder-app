import 'package:flutter/material.dart';
import '../../../categories/domain/entities/category.dart';
import '../../../../core/utils/ui_helpers.dart';

class CategorySelector extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final ValueChanged<String> onCategorySelected;

  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Category',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              final isSelected = category.id == selectedCategoryId;
              final categoryColor = parseHexColor(category.color);
              final categoryIcon = getCategoryIcon(category.icon);

              return GestureDetector(
                onTap: () => onCategorySelected(category.id),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? categoryColor.withOpacity(0.18)
                        : theme.colorScheme.onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? categoryColor
                          : theme.colorScheme.outline.withOpacity(0.2),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        categoryIcon,
                        size: 18,
                        color: isSelected ? categoryColor : theme.textTheme.bodyMedium?.color,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        category.name,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: isSelected ? categoryColor : theme.textTheme.bodyLarge?.color,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
