class Media {
  final int id;
  final String? title;
  final String path;
  final String? thumbnailPath;
  final String type;
  final Map<String, dynamic>? metadataJson;
  final DateTime createdAt;

  Media({
    required this.id,
    this.title,
    required this.path,
    this.thumbnailPath,
    required this.type,
    this.metadataJson,
    required this.createdAt,
  });

  factory Media.fromJson(Map<String, dynamic> json) {
    return Media(
      id: json['id'] as int,
      title: json['title'] as String?,
      path: json['path'] as String,
      thumbnailPath: json['thumbnail_path'] as String?,
      type: json['type'] as String,
      metadataJson: json['metadata_json'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get filename => path.split('/').last;

  String get displayName => (title != null && title!.isNotEmpty) ? title! : filename;

  String fileUrl(String baseUrl) => '$baseUrl/media/$id/file';

  int? get width => metadataJson?['width'] as int?;
  int? get height => metadataJson?['height'] as int?;
  String? get format => metadataJson?['format'] as String?;
}
