// album
import 'media.dart';

class Album {
  final int id;
  final String name;
  final DateTime createdAt;
  final List<Media> media;

  Album({
    required this.id,
    required this.name,
    required this.createdAt,
    this.media = const [],
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as int,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      media: (json['media'] as List<dynamic>?)
              ?.map((m) => Media.fromJson(m as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
