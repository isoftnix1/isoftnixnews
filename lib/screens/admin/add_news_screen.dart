import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/news_model.dart';
import '../../providers/news_provider.dart';
import '../../services/media_service.dart';
import '../user/news_details_screen.dart';

class AddNewsScreen extends StatefulWidget {
  const AddNewsScreen({super.key});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleEnController = TextEditingController();
  final _contentEnController = TextEditingController();
  final _titleHiController = TextEditingController();
  final _contentHiController = TextEditingController();
  final _titleMrController = TextEditingController();
  final _contentMrController = TextEditingController();
  final _sourceNameController = TextEditingController();
  final _sourceUrlController = TextEditingController();
  List<String> _selectedCategoryIds = [];

  File? _selectedImage;
  File? _selectedVideo;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newsProvider = context.read<NewsProvider>();
      if (newsProvider.categories.isEmpty) {
        newsProvider.loadCategories();
      }
    });
  }

  @override
  void dispose() {
    _titleEnController.dispose();
    _contentEnController.dispose();
    _titleHiController.dispose();
    _contentHiController.dispose();
    _titleMrController.dispose();
    _contentMrController.dispose();
    _sourceNameController.dispose();
    _sourceUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _pickVideo() async {
    final pickedFile = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedVideo = File(pickedFile.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one category')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    File? finalImage = _selectedImage;
    File? finalVideo = _selectedVideo;

    if (_selectedImage != null) {
      _showProgressDialog('Optimizing image...');
      final result = await MediaService.processImage(_selectedImage!);
      if (!mounted) return;
      Navigator.pop(context); // Close dialog

      if (!result.success) {
        setState(() => _isSubmitting = false);
        _showErrorDialog(result.errorMessage!);
        return;
      }
      finalImage = result.file;
    }

    if (_selectedVideo != null) {
      _showProgressDialog('Compressing video...', isVideo: true);
      final result = await MediaService.processVideo(_selectedVideo!);
      if (!mounted) return;
      Navigator.pop(context); // Close dialog

      if (!result.success) {
        setState(() => _isSubmitting = false);
        _showErrorDialog(result.errorMessage!);
        return;
      }
      finalVideo = result.file;
    }

    _showProgressDialog('Uploading...');
    final provider = context.read<NewsProvider>();
    try {
      await provider.addNews(
        NewsModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleEnController.text.trim(),
          content: _contentEnController.text.trim(),
          titleEn: _titleEnController.text.trim(),
          contentEn: _contentEnController.text.trim(),
          titleHi: _titleHiController.text.trim(),
          contentHi: _contentHiController.text.trim(),
          titleMr: _titleMrController.text.trim(),
          contentMr: _contentMrController.text.trim(),
          sourceName: _sourceNameController.text.trim().isNotEmpty ? _sourceNameController.text.trim() : null,
          sourceUrl: _sourceUrlController.text.trim().isNotEmpty ? _sourceUrlController.text.trim() : null,
          imageUrl: '',
          videoUrl: null,
          categoryIds: _selectedCategoryIds,
          authorName: 'Admin',
          createdAt: DateTime.now(),
        ),
        imageFile: finalImage,
        videoFile: finalVideo,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close dialog
      setState(() => _isSubmitting = false);
      _showErrorDialog('Upload failed. Please try again.');
      return;
    }

    if (!mounted) return;
    Navigator.pop(context); // Close Uploading dialog
    setState(() => _isSubmitting = false);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('News created and notifications successfully sent to all users!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
    
    Navigator.pop(context); // Close Add Screen
  }

  void _showProgressDialog(String message, {bool isVideo = false}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
          actions: isVideo && message.contains('Compressing')
              ? [
                  TextButton(
                    onPressed: () {
                      MediaService.cancelVideoCompression();
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ]
              : null,
        );
      },
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NewsProvider>();
    final dropdownCategories = provider.categories.where((cat) => cat.id != 'all').toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Add News')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildLanguageSection('English', _titleEnController, _contentEnController),
            const SizedBox(height: 16),
            _buildLanguageSection('Hindi (हिन्दी)', _titleHiController, _contentHiController),
            const SizedBox(height: 16),
            _buildLanguageSection('Marathi (मराठी)', _titleMrController, _contentMrController),
            const SizedBox(height: 12),
            _buildCategorySelector(dropdownCategories),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image),
                    label: Text(_selectedImage == null ? 'Select Image' : 'Image Selected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _selectedImage == null ? Colors.blueGrey : Colors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.video_library),
                    label: Text(_selectedVideo == null ? 'Select Video' : 'Video Selected'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _selectedVideo == null ? Colors.blueGrey : Colors.green,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedImage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Image: ${_selectedImage!.path.split('/').last}')),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
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
                    Expanded(child: Text('Video: ${_selectedVideo!.path.split('/').last}')),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.red),
                      onPressed: () => setState(() => _selectedVideo = null),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Original Source (Optional)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sourceNameController,
              decoration: const InputDecoration(
                labelText: 'Source Name',
                hintText: 'e.g. Indian Express',
              ),
              validator: (value) {
                if (_sourceUrlController.text.trim().isNotEmpty && (value == null || value.trim().isEmpty)) {
                  return 'Source Name is required when Source URL is provided';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _sourceUrlController,
              decoration: const InputDecoration(
                labelText: 'Source URL',
                hintText: 'e.g. https://indianexpress.com/...',
              ),
              keyboardType: TextInputType.url,
              validator: (value) {
                if (_sourceNameController.text.trim().isNotEmpty && (value == null || value.trim().isEmpty)) {
                  return 'Source URL is required when Source Name is provided';
                }
                if (value != null && value.trim().isNotEmpty) {
                  final uri = Uri.tryParse(value.trim());
                  if (uri == null || (!uri.isScheme('http') && !uri.isScheme('https'))) {
                    return 'Please enter a valid HTTP/HTTPS URL';
                  }
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _previewNews,
                    child: const Text('Preview News'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save News'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _previewNews() {
    // Show a preview using the English content as the baseline.
    // If English is empty, try Hindi or Marathi.
    final title = _titleEnController.text.trim().isNotEmpty 
        ? _titleEnController.text.trim() 
        : (_titleHiController.text.trim().isNotEmpty 
            ? _titleHiController.text.trim() 
            : _titleMrController.text.trim());
            
    final content = _contentEnController.text.trim().isNotEmpty 
        ? _contentEnController.text.trim() 
        : (_contentHiController.text.trim().isNotEmpty 
            ? _contentHiController.text.trim() 
            : _contentMrController.text.trim());

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter at least a title and content to preview.')),
      );
      return;
    }

    final dummyNews = NewsModel(
      id: 'preview',
      title: title,
      content: content,
      imageUrl: _selectedImage?.path ?? '',
      videoUrl: _selectedVideo?.path, // Note: video preview from file might not work out of the box in network player, but image will fallback or show broken.
      categoryIds: _selectedCategoryIds,
      categoryName: 'Preview Category',
      authorName: 'Admin',
      createdAt: DateTime.now(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewsDetailsScreen(news: dummyNews),
      ),
    );
  }

  Widget _buildLanguageSection(
    String title,
    TextEditingController titleController,
    TextEditingController contentController,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Title'),
          validator: (value) => value!.isEmpty ? 'Required' : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: contentController,
          maxLines: 5,
          decoration: const InputDecoration(labelText: 'Content'),
          validator: (value) => value!.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildCategorySelector(List<dynamic> availableCategories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Categories *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            if (_selectedCategoryIds.isEmpty)
              const Text('(Required)', style: TextStyle(color: Colors.red, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _selectedCategoryIds.map((id) {
            final matched = availableCategories.where((c) => c.id == id);
            if (matched.isEmpty) return const SizedBox.shrink();
            final cat = matched.first;
            return Chip(
              label: Text(cat.name),
              deleteIcon: const Icon(Icons.close, size: 18),
              onDeleted: () {
                setState(() {
                  _selectedCategoryIds.remove(id);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => _showCategoryPicker(availableCategories),
          icon: const Icon(Icons.add),
          label: const Text('Add Category'),
        ),
      ],
    );
  }

  void _showCategoryPicker(List<dynamic> availableCategories) {
    // Create a local copy of selected IDs to manage state inside the dialog
    final localSelectedIds = List<String>.from(_selectedCategoryIds);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              maxChildSize: 0.9,
              minChildSize: 0.4,
              builder: (_, scrollController) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Select Categories',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedCategoryIds = List.from(localSelectedIds);
                              });
                              Navigator.pop(context);
                            },
                            child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        controller: scrollController,
                        itemCount: availableCategories.length,
                        itemBuilder: (context, index) {
                          final cat = availableCategories[index];
                          final isSelected = localSelectedIds.contains(cat.id);
                          return CheckboxListTile(
                            title: Text(cat.name),
                            value: isSelected,
                            onChanged: (bool? checked) {
                              setModalState(() {
                                if (checked == true) {
                                  localSelectedIds.add(cat.id);
                                } else {
                                  localSelectedIds.remove(cat.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
