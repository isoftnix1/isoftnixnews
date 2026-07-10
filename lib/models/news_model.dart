class NewsModel {
  final String id;
  final String title;
  final String content;
  final String? titleEn;
  final String? contentEn;
  final String? titleHi;
  final String? contentHi;
  final String? titleMr;
  final String? contentMr;
  final String? authorId;
  final String? authorName;
  final String? categoryId;
  final String? categoryName;
  final List<String> categoryIds;
  final List<Map<String, dynamic>> categories;
  final String imageUrl;
  final String? videoUrl;
  final String? sourceName;
  final String? sourceUrl;
  final bool isPublished;
  final int viewsCount;
  final int reminderSentCount;
  final String reminderStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? publishedAt;

  const NewsModel({
    required this.id,
    required this.title,
    required this.content,
    this.titleEn,
    this.contentEn,
    this.titleHi,
    this.contentHi,
    this.titleMr,
    this.contentMr,
    this.authorId,
    this.authorName,
    this.categoryId,
    this.categoryName,
    this.categoryIds = const [],
    this.categories = const [],
    required this.imageUrl,
    this.videoUrl,
    this.sourceName,
    this.sourceUrl,
    this.isPublished = true,
    this.viewsCount = 0,
    this.reminderSentCount = 0,
    this.reminderStatus = 'pending',
    this.createdAt,
    this.updatedAt,
    this.publishedAt,
  });

  factory NewsModel.fromJson(Map<String, dynamic> json) {
    return NewsModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? json['description'] ?? '',
      titleEn: json['title_en'] ?? json['titleEn'],
      contentEn: json['content_en'] ?? json['contentEn'],
      titleHi: json['title_hi'] ?? json['titleHi'],
      contentHi: json['content_hi'] ?? json['contentHi'],
      titleMr: json['title_mr'] ?? json['titleMr'],
      contentMr: json['content_mr'] ?? json['contentMr'],
      authorId: json['author_id']?.toString() ?? json['authorId']?.toString(),
      authorName: json['author_name'] ?? json['authorName'] ?? json['author'] ?? 'Admin',
      categoryId: json['category_id']?.toString() ?? json['categoryId']?.toString(),
      categoryName: json['category_name'] ?? json['categoryName'] ?? json['category'] ?? '',
      categoryIds: json['categories'] != null 
          ? (json['categories'] as List).map((c) => c['id']?.toString() ?? '').toList()
          : (json['category_id'] != null ? [json['category_id'].toString()] : []),
      categories: json['categories'] != null 
          ? List<Map<String, dynamic>>.from(json['categories'])
          : [],
      imageUrl: json['image_url'] ?? json['imageUrl'] ?? '',
      videoUrl: json['video_url'] ?? json['videoUrl'],
      sourceName: json['source_name'] ?? json['sourceName'],
      sourceUrl: json['source_url'] ?? json['sourceUrl'],
      isPublished: json['is_published'] is bool
          ? json['is_published']
          : (json['isPublished'] is bool
              ? json['isPublished']
              : (json['is_published']?.toString() == 'true' || json['isPublished']?.toString() == 'true')),
      viewsCount: json['views_count'] ?? json['viewsCount'] ?? 0,
      reminderSentCount: json['reminder_sent_count'] ?? json['reminderSentCount'] ?? 0,
      reminderStatus: json['reminder_status'] ?? json['reminderStatus'] ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
      updatedAt: json['updated_at'] != null 
          ? DateTime.tryParse(json['updated_at'].toString()) 
          : (json['updatedAt'] != null ? DateTime.tryParse(json['updatedAt'].toString()) : null),
      publishedAt: json['published_at'] != null 
          ? DateTime.tryParse(json['published_at'].toString()) 
          : (json['publishedAt'] != null ? DateTime.tryParse(json['publishedAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'title_en': titleEn,
      'content_en': contentEn,
      'title_hi': titleHi,
      'content_hi': contentHi,
      'title_mr': titleMr,
      'content_mr': contentMr,
      'author_id': authorId,
      'author_name': authorName,
      'category_id': categoryIds.isNotEmpty ? categoryIds.first : categoryId,
      'categoryId': categoryIds.isNotEmpty ? categoryIds.first : categoryId, // Backend compatibility
      'category_name': categoryName,
      'categoryName': categoryName,
      'categoryIds': categoryIds,
      'categories': categories,
      'image_url': imageUrl,
      'imageUrl': imageUrl,
      'video_url': videoUrl,
      'videoUrl': videoUrl,
      'source_name': sourceName,
      'sourceName': sourceName,
      'source_url': sourceUrl,
      'sourceUrl': sourceUrl,
      'is_published': isPublished,
      'isPublished': isPublished,
      'views_count': viewsCount,
      'viewsCount': viewsCount,
      'reminder_sent_count': reminderSentCount,
      'reminderSentCount': reminderSentCount,
      'reminder_status': reminderStatus,
      'reminderStatus': reminderStatus,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'published_at': publishedAt?.toIso8601String(),
      'publishedAt': publishedAt?.toIso8601String(),
    };
  }

  NewsModel copyWith({
    String? id,
    String? title,
    String? content,
    String? titleEn,
    String? contentEn,
    String? titleHi,
    String? contentHi,
    String? titleMr,
    String? contentMr,
    String? authorId,
    String? authorName,
    String? categoryId,
    String? categoryName,
    List<String>? categoryIds,
    List<Map<String, dynamic>>? categories,
    String? imageUrl,
    String? videoUrl,
    String? sourceName,
    String? sourceUrl,
    bool? isPublished,
    int? viewsCount,
    int? reminderSentCount,
    String? reminderStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? publishedAt,
  }) {
    return NewsModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      titleEn: titleEn ?? this.titleEn,
      contentEn: contentEn ?? this.contentEn,
      titleHi: titleHi ?? this.titleHi,
      contentHi: contentHi ?? this.contentHi,
      titleMr: titleMr ?? this.titleMr,
      contentMr: contentMr ?? this.contentMr,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      categoryIds: categoryIds ?? this.categoryIds,
      categories: categories ?? this.categories,
      imageUrl: imageUrl ?? this.imageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      isPublished: isPublished ?? this.isPublished,
      viewsCount: viewsCount ?? this.viewsCount,
      reminderSentCount: reminderSentCount ?? this.reminderSentCount,
      reminderStatus: reminderStatus ?? this.reminderStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      publishedAt: publishedAt ?? this.publishedAt,
    );
  }
}
