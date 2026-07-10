import 'dart:convert';

class NotificationModel {
  final String id;
  final String? userId;
  final String title;
  final String body;
  final Map<String, dynamic>? data;
  final bool isRead;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    this.userId,
    required this.title,
    required this.body,
    this.data,
    this.isRead = false,
    this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedData;
    if (json['data'] != null) {
      if (json['data'] is Map) {
        parsedData = Map<String, dynamic>.from(json['data'] as Map);
      } else if (json['data'] is String) {
        try {
          parsedData = jsonDecode(json['data'] as String) as Map<String, dynamic>;
        } catch (_) {}
      }
    }

    return NotificationModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? json['userId']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      data: parsedData,
      isRead: json['is_read'] is bool
          ? json['is_read']
          : (json['isRead'] is bool
              ? json['isRead']
              : (json['is_read']?.toString() == 'true' || json['isRead']?.toString() == 'true')),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : (json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) : null),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'body': body,
      'data': data,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
