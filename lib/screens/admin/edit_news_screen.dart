import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/news_provider.dart';

class EditNewsScreen extends StatefulWidget {
  const EditNewsScreen({super.key});

  @override
  State<EditNewsScreen> createState() => _EditNewsScreenState();
}

class _EditNewsScreenState extends State<EditNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _selectedCategoryId;

  File? _selectedImage;
  File? _selectedVideo;
  bool _isSubmitting = false;
  bool _initialized = false;

  NewsModel? _news;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialized) return;
      _initialized = true;

      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is NewsModel) {
        _news = args;
        _titleController.text = _news!.title;
        _contentController.text = _news!.content;
        _selectedCategoryId = _news!.categoryId;
        setState(() {});
      }

      final newsProvider = context.read<NewsProvider>();
      if (newsProvider.categories.isEmpty) {
        newsProvider.loadCategories();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedVideo = File(pickedFile.path));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _news == null) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final provider = context.read<NewsProvider>();
    await provider.updateNews(
      NewsModel(
        id: _news!.id,
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        imageUrl: _news!.imageUrl,
        videoUrl: _news!.videoUrl,
        categoryId: _selectedCategoryId,
        authorName: _news!.authorName,
        createdAt: _news!.createdAt,
        updatedAt: DateTime.now(),
      ),
      imageFile: _selectedImage,
      videoFile: _selectedVideo,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final dropdownCategories =
        provider.categories.where((cat) => cat.id != 'all').toList();

    if (_news == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit News')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Edit News')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contentController,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Content'),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: dropdownCategories.any((c) => c.id == _selectedCategoryId)
                  ? _selectedCategoryId
                  : null,
              hint: const Text('Select Category'),
              items: dropdownCategories
                  .map((cat) => DropdownMenuItem(
                        value: cat.id,
                        child: Text(cat.name),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedCategoryId = value),
              validator: (value) => value == null ? 'Required' : null,
              decoration: const InputDecoration(labelText: 'Category'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(
                        _selectedImage == null ? 'Change Image' : 'Image Selected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _selectedImage == null ? Colors.blueGrey : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.video_library),
                    label: Text(
                        _selectedVideo == null ? 'Change Video' : 'Video Selected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          _selectedVideo == null ? Colors.blueGrey : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New image: ${_selectedImage!.path.split('/').last.split('\\').last}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => setState(() => _selectedImage = null),
                    ),
                  ],
                ),
              ),
            if (_selectedVideo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'New video: ${_selectedVideo!.path.split('/').last.split('\\').last}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      onPressed: () => setState(() => _selectedVideo = null),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Update News'),
            ),
          ],
        ),
      ),
    );
  }
}
