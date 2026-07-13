import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/ad_model.dart';
import '../../services/ad_service.dart';
import 'ad_analytics_dialog.dart';

class AdManagementScreen extends StatefulWidget {
  const AdManagementScreen({super.key});

  @override
  State<AdManagementScreen> createState() => _AdManagementScreenState();
}

class _AdManagementScreenState extends State<AdManagementScreen> {
  final AdService _adService = AdService();
  List<AdModel> _ads = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAds();
  }

  Future<void> _fetchAds() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final ads = await _adService.getActiveAds();
      setState(() {
        _ads = ads;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showAddAdModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddAdBottomSheet(),
    ).then((_) {
      // Refresh list after closing
      _fetchAds();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Ads', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAdModal,
        icon: const Icon(Icons.add),
        label: const Text('New Ad'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : _ads.isEmpty
                  ? const Center(child: Text('No active ads found.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _ads.length,
                      itemBuilder: (context, index) {
                        final ad = _ads[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => AdAnalyticsDialog.show(context, ad),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade900,
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    bottomLeft: Radius.circular(16),
                                  ),
                                  image: ad.imageUrl != null && ad.imageUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: CachedNetworkImageProvider(ad.imageUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: ad.imageUrl == null && ad.videoUrl != null
                                    ? const Icon(Icons.videocam, color: Colors.white, size: 40)
                                    : null,
                              ),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ad.companyName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        ad.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (ad.description.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          ad.description,
                                          style: const TextStyle(color: Colors.grey),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Delete Ad?'),
                                      content: const Text('Are you sure you want to delete this ad?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, true),
                                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true) {
                                    try {
                                      await _adService.deleteAd(ad.id);
                                      _fetchAds();
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                                      }
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                        ));
                      },
                    ),
    );
  }
}

class _AddAdBottomSheet extends StatefulWidget {
  const _AddAdBottomSheet();

  @override
  State<_AddAdBottomSheet> createState() => _AddAdBottomSheetState();
}

class _AddAdBottomSheetState extends State<_AddAdBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _companyController = TextEditingController();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _urlController = TextEditingController();
  
  File? _selectedImage;
  File? _selectedVideo;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();
  final AdService _adService = AdService();

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _selectedVideo = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideo = File(video.path);
        _selectedImage = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null && _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select an image or video')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _adService.addAd(
        companyName: _companyController.text,
        title: _titleController.text,
        description: _descController.text,
        targetUrl: _urlController.text,
        imageFile: _selectedImage,
        videoFile: _selectedVideo,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ad created successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Create Advertisement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _companyController,
                  decoration: const InputDecoration(labelText: 'Company Name', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Ad Title', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description (Optional)', border: OutlineInputBorder()),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _urlController,
                  decoration: const InputDecoration(labelText: 'Target URL', border: OutlineInputBorder()),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickImage,
                        icon: const Icon(Icons.image),
                        label: Text(_selectedImage != null ? 'Image Selected' : 'Pick Image'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedImage != null ? Colors.green : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _pickVideo,
                        icon: const Icon(Icons.videocam),
                        label: Text(_selectedVideo != null ? 'Video Selected' : 'Pick Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedVideo != null ? Colors.green : null,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Upload & Create Ad', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
