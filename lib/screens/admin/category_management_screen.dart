import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/category_model.dart';
import '../../providers/category_provider.dart';

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({super.key});

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CategoryProvider>().loadCategories();
    });
  }

  // Converts "My Category Name" → "my-category-name"
  String _toSlug(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');

  Future<void> _showCategoryDialog({CategoryModel? category}) async {
    final nameController =
        TextEditingController(text: category?.name ?? '');
    final slugController =
        TextEditingController(text: category?.slug ?? '');
    final formKey = GlobalKey<FormState>();
    bool autoSlug = category == null; // auto-generate slug for new categories

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(
                  category == null ? 'Add Category' : 'Edit Category'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) {
                        if (autoSlug) {
                          setDialogState(() {
                            slugController.text = _toSlug(val);
                          });
                        }
                      },
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: slugController,
                      decoration: const InputDecoration(
                        labelText: 'Slug (e.g. tech)',
                        border: OutlineInputBorder(),
                        helperText: 'Lowercase, hyphens only',
                      ),
                      onTap: () => setDialogState(() => autoSlug = false),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Slug is required';
                        }
                        if (!RegExp(r'^[a-z0-9-]+$').hasMatch(v.trim())) {
                          return 'Only lowercase letters, numbers and hyphens';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate()) return;
                    Navigator.pop(ctx);

                    final provider = context.read<CategoryProvider>();
                    bool success;

                    if (category == null) {
                      success = await provider.addCategory(
                        nameController.text.trim(),
                        slugController.text.trim(),
                      );
                    } else {
                      success = await provider.editCategory(
                        category.id,
                        nameController.text.trim(),
                        slugController.text.trim(),
                      );
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success
                              ? category == null
                                  ? 'Category added!'
                                  : 'Category updated!'
                              : provider.errorMessage ?? 'Operation failed'),
                          backgroundColor:
                              success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                  child: Text(category == null ? 'Add' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(CategoryModel category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
            'Delete "${category.name}"? Articles in this category will become uncategorised.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success =
          await context.read<CategoryProvider>().removeCategory(category.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success
                ? 'Category deleted'
                : context.read<CategoryProvider>().errorMessage ??
                    'Delete failed'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCategoryDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: provider.isLoading && provider.categories.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : provider.categories.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.category_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('No categories yet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      const Text('Tap + to create your first category'),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                  itemCount: provider.categories.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final cat = provider.categories[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Text(
                          cat.name.isNotEmpty
                              ? cat.name[0].toUpperCase()
                              : '?',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(cat.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      subtitle: Text('/${cat.slug}',
                          style: const TextStyle(
                              fontFamily: 'monospace',
                              color: Colors.grey)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showCategoryDialog(category: cat);
                          } else if (value == 'delete') {
                            _confirmDelete(cat);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'edit', child: Text('Edit')),
                          PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
