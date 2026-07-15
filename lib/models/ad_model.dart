class AdModel {
  final String id;
  final String companyName;
  final String title;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final String targetUrl;
  final int viewsCount;
  final int clicksCount;
  final DateTime? startDate;
  final DateTime? endDate;

  const AdModel({
    required this.id,
    required this.companyName,
    required this.title,
    required this.description,
    this.imageUrl,
    this.videoUrl,
    required this.targetUrl,
    this.viewsCount = 0,
    this.clicksCount = 0,
    this.startDate,
    this.endDate,
  });

  factory AdModel.fromJson(Map<String, dynamic> json) {
    return AdModel(
      id: json['id'] as String,
      companyName: json['company_name'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      imageUrl: json['image_url'],
      videoUrl: json['video_url'],
      targetUrl: json['target_url'] ?? '',
      viewsCount: json['views_count'] is int 
          ? json['views_count'] 
          : int.tryParse(json['views_count']?.toString() ?? '0') ?? 0,
      clicksCount: json['clicks_count'] is int 
          ? json['clicks_count'] 
          : int.tryParse(json['clicks_count']?.toString() ?? '0') ?? 0,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'company_name': companyName,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'video_url': videoUrl,
      'target_url': targetUrl,
      'views_count': viewsCount,
      'clicks_count': clicksCount,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
    };
  }
}
