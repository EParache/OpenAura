// api service
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/media.dart';
import '../models/album.dart';


class ApiService {
  final String baseUrl;
  final http.Client _client = http.Client();

  ApiService({required this.baseUrl});

  void dispose() {
    _client.close();
  }

  dynamic _safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return {'detail': 'Error del servidor'};
    }
  }

  // ── Media ────────────────────────────────────────────────────────────────

  Future<List<Media>> getMedia({int skip = 0, int limit = 100, String? query, String? type}) async {
    final params = <String, String>{
      'skip': '$skip',
      'limit': '$limit',
    };
    if (query != null && query.isNotEmpty) {
      params['q'] = query;
    }
    if (type != null && type.isNotEmpty) {
      params['type'] = type;
    }
    final uri = Uri.parse('$baseUrl/media').replace(queryParameters: params);
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => Media.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Error al cargar media: ${response.statusCode}');
  }

  Future<Media> getMediaById(int id) async {
    final response = await _client.get(Uri.parse('$baseUrl/media/$id'));
    if (response.statusCode == 200) {
      return Media.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Error al cargar archivo: ${response.statusCode}');
  }

  Future<Media> updateMedia(int id, {String? title, String? filename, DateTime? createdAt}) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (filename != null) body['filename'] = filename;
    if (createdAt != null) body['created_at'] = createdAt.toIso8601String();
    final response = await _client.put(
      Uri.parse('$baseUrl/media/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode == 200) {
      return Media.fromJson(_safeJsonDecode(response.body) as Map<String, dynamic>);
    }
    final detail =
        (_safeJsonDecode(response.body) as Map<String, dynamic>)['detail'] ?? 'Error desconocido';
    throw Exception(detail);
  }

  Future<Map<String, dynamic>> regenerateThumbnails() async {
    final response = await _client.post(Uri.parse('$baseUrl/regenerate-thumbnails'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al regenerar miniaturas');
  }

  Future<void> deleteMedia(int id) async {
    final response = await _client.delete(Uri.parse('$baseUrl/media/$id'));
    if (response.statusCode == 200) return;
    final detail =
        (_safeJsonDecode(response.body) as Map<String, dynamic>)['detail'] ?? 'Error desconocido';
    throw Exception(detail);
  }

  Future<Map<String, dynamic>> getHostInfo() async {
    final response = await _client.get(Uri.parse('$baseUrl/host-info'));
    if (response.statusCode == 200) {
      return _safeJsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('No se pudo conectar al servidor');
  }

  // ── Escaneo ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> scanDirectory(String path) async {
    final uri = Uri.parse('$baseUrl/scan').replace(
      queryParameters: {'path': path},
    );
    final response = await _client.post(uri);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al escanear: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> rescan() async {
    final response = await _client.post(Uri.parse('$baseUrl/rescan'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Error al re-escanear: ${response.statusCode}');
  }

  // ── Álbumes ──────────────────────────────────────────────────────────────

  Future<List<Album>> getAlbums({int skip = 0, int limit = 100}) async {
    final uri = Uri.parse('$baseUrl/albums').replace(
      queryParameters: {'skip': '$skip', 'limit': '$limit'},
    );
    final response = await _client.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((j) => Album.fromJson(j as Map<String, dynamic>)).toList();
    }
    throw Exception('Error al cargar álbumes: ${response.statusCode}');
  }

  Future<Album> getAlbum(int id) async {
    final response = await _client.get(Uri.parse('$baseUrl/albums/$id'));
    if (response.statusCode == 200) {
      return Album.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    throw Exception('Error al cargar álbum: ${response.statusCode}');
  }

  Future<Album> createAlbum(String name) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/albums'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 201) {
      return Album.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final detail =
        (jsonDecode(response.body) as Map<String, dynamic>)['detail'] ?? 'Error desconocido';
    throw Exception(detail);
  }

  Future<Album> updateAlbum(int id, String name) async {
    final response = await _client.put(
      Uri.parse('$baseUrl/albums/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name}),
    );
    if (response.statusCode == 200) {
      return Album.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final detail =
        (jsonDecode(response.body) as Map<String, dynamic>)['detail'] ?? 'Error desconocido';
    throw Exception(detail);
  }

  Future<void> deleteAlbum(int id) async {
    final response = await _client.delete(Uri.parse('$baseUrl/albums/$id'));
    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Error al eliminar álbum: ${response.statusCode}');
    }
  }

  Future<Album> addMediaToAlbum(int albumId, int mediaId) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/albums/$albumId/media/$mediaId'),
    );
    if (response.statusCode == 200) {
      return Album.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final detail =
        (jsonDecode(response.body) as Map<String, dynamic>)['detail'] ?? 'Error desconocido';
    throw Exception(detail);
  }

  Future<Album> removeMediaFromAlbum(int albumId, int mediaId) async {
    final response = await _client.delete(
      Uri.parse('$baseUrl/albums/$albumId/media/$mediaId'),
    );
    if (response.statusCode == 200) {
      return Album.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    }
    final detail =
        (jsonDecode(response.body) as Map<String, dynamic>)['detail'] ?? 'Error desconocido';
    throw Exception(detail);
  }
}
