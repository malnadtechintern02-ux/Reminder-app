import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/category.dart';
import '../../../reminders/presentation/providers/reminder_list_provider.dart';
import '../../../../core/utils/ui_helpers.dart';

class ManageCategoriesSheet extends ConsumerWidget {
  const ManageCategoriesSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const ManageCategoriesSheet(),
    );
  }

  static const List<String> availableColors = [
    '#4A90E2', // Blue
    '#50E3C2', // Teal
    '#F5A623', // Orange
    '#E056FD', // Purple
    '#68D391', // Green
    '#F56565', // Red
    '#ED64A6', // Pink
    '#ECC94B', // Yellow
    '#667EEA', // Indigo
    '#38B2AC', // Cyan
    '#9F7AEA', // Violet
    '#718096', // Slate
  ];

  static const List<Map<String, dynamic>> availableIcons = [
    {'name': 'work', 'icon': Icons.work_rounded},
    {'name': 'folder', 'icon': Icons.folder_rounded},
    {'name': 'home', 'icon': Icons.home_rounded},
    {'name': 'fitness', 'icon': Icons.fitness_center_rounded},
    {'name': 'health', 'icon': Icons.favorite_rounded},
    {'name': 'shopping', 'icon': Icons.shopping_cart_rounded},
    {'name': 'school', 'icon': Icons.school_rounded},
    {'name': 'book', 'icon': Icons.book_rounded},
    {'name': 'lightbulb', 'icon': Icons.lightbulb_rounded},
    {'name': 'flight', 'icon': Icons.flight_rounded},
    {'name': 'directions_car', 'icon': Icons.directions_car_rounded},
    {'name': 'restaurant', 'icon': Icons.restaurant_rounded},
    {'name': 'sports_esports', 'icon': Icons.sports_esports_rounded},
    {'name': 'attach_money', 'icon': Icons.attach_money_rounded},
  ];

  void _showAddEditDialog(BuildContext context, WidgetRef ref, [Category? category]) {
    final isEdit = category != null;
    final nameController = TextEditingController(text: category?.name ?? '');
    String selectedColor = category?.color ?? availableColors.first;
    String selectedIcon = category?.icon ?? 'folder';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.cardColor,
            title: Text(isEdit ? 'Edit Category' : 'New Category'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Finance, Fitness...',
                      filled: true,
                      fillColor: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Choose Color', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableColors.map((hex) {
                      final c = parseHexColor(hex);
                      final isSelected = selectedColor.toUpperCase() == hex.toUpperCase();
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = hex),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2.5,
                            ),
                            boxShadow: isSelected
                                ? [BoxShadow(color: c.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 1)]
                                : null,
                          ),
                          child: isSelected ? const Icon(Icons.check, size: 18, color: Colors.white) : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text('Choose Icon', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableIcons.map((item) {
                      final name = item['name'] as String;
                      final icon = item['icon'] as IconData;
                      final isSelected = selectedIcon == name;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedIcon = name),
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? theme.primaryColor : Colors.transparent,
                            ),
                          ),
                          child: Icon(
                            icon,
                            size: 20,
                            color: isSelected ? Colors.white : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final repo = ref.read(categoryRepositoryProvider);
                  if (isEdit) {
                    final updated = Category(
                      id: category.id,
                      name: name,
                      icon: selectedIcon,
                      color: selectedColor,
                    );
                    await repo.updateCategory(updated);
                  } else {
                    final newCat = Category(
                      id: const Uuid().v4(),
                      name: name,
                      icon: selectedIcon,
                      color: selectedColor,
                    );
                    await repo.addCategory(newCat);
                  }

                  ref.invalidate(categoriesFutureProvider);
                  if (context.mounted) {
                    Navigator.of(ctx).pop();
                  }
                },
                child: Text(isEdit ? 'Save' : 'Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, Category category) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text('Reminders in this category will not be deleted, but will become uncategorized.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
              ref.invalidate(categoriesFutureProvider);
              if (context.mounted) {
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(categoriesFutureProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Row(
                  children: [
                    const Icon(Icons.category_rounded, size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Manage Categories',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_circle_rounded),
                      color: theme.primaryColor,
                      tooltip: 'Add Category',
                      onPressed: () => _showAddEditDialog(context, ref),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: categoriesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, s) => Center(child: Text('Error loading categories: $e')),
                  data: (categories) {
                    if (categories.isEmpty) {
                      return const Center(child: Text('No categories created yet.'));
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: categories.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
                      itemBuilder: (context, index) {
                        final cat = categories[index];
                        final color = parseHexColor(cat.color);
                        final icon = getCategoryIcon(cat.icon);

                        return ListTile(
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(icon, color: color, size: 20),
                          ),
                          title: Text(
                            cat.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _showAddEditDialog(context, ref, cat),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 20, color: theme.colorScheme.error),
                                onPressed: () => _confirmDelete(context, ref, cat),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
