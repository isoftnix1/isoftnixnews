class NewsModel {
  final String id;
  final String title;
  final String content;
  final String? authorId;
  final String? authorName;
  final String? categoryId;
  final String? categoryName;
  final String imageUrl;
  final String? videoUrl;
  final bool isPublished;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const NewsModel({
    required this.id,
    required this.title,
    required this.content,
    this.authorId,
    this.authorName,
    this.categoryId,
    this.categoryName,
    required this.imageUrl,
    this.videoUrl,
    this.isPublished = true,
    this.createdAt,
    this.updatedAt,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? json['description'] ?? '',
      authorId: json['author_id']?.toString() ?? json['authorId']?.toString(),
      authorName: json['author_name'] ?? json['authorName'] ?? json['author'] ?? 'Admin',
      categoryId: json['category_id']?.toString() ?? json['categoryId']?.toString(),
      categoryName: json['category_name'] ?? json['categoryName'] ?? json['category'] ?? '',
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      videoUrl: json['video_url'] ?? json['videoUrl'],
      isPublished: json['is_published'] is bool
          ? json['is_published']
          : (json['isPublished'] is bool
              ? json['isPublished']
              : (json['is_published']?.toString() == 'true' || json['isPublished']?.toString() == 'true')),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString()) 
          : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'author_id': authorId,
      'author_name': authorName,
      'category_id': categoryId,
      'categoryId': categoryId, // Backend compatibility
      'category_name': categoryName,
      'categoryName': categoryName,
      'image_url': imageUrl,
      'imageUrl': imageUrl,
      'video_url': videoUrl,
      'videoUrl': videoUrl,
      'is_published': isPublished,
      'isPublished': isPublished,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}
