class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final DateTime? createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? json['title'] ?? '',
      slug: json['slug'] ?? '',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
