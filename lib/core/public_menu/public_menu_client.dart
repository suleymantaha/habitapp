import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:whatsapp_catalog/features/catalog/domain/entities/catalog.dart';

class PublicMenuClient {
  PublicMenuClient({required this.baseUrl});

  final String baseUrl;

  String publicUrlForId(String id) => '$baseUrl/m/$id';

  Future<PublicMenuCreateResponse> createMenu(Catalog catalog) async {
    final uri = Uri.parse('$baseUrl/api/menus');
    final payload = await _catalogPayload(catalog);
    final json = await _requestJson(
      method: 'POST',
      uri: uri,
      headers: {'content-type': 'application/json'},
      body: jsonEncode(payload),
    );
    final id = json['id'];
    final editToken = json['editToken'];
    if (id is! String || editToken is! String) {
      throw StateError('Invalid create response');
    }
    return PublicMenuCreateResponse(id: id, editToken: editToken);
  }

  Future<void> updateMenu({
    required String id,
    required String editToken,
    required Catalog catalog,
  }) async {
    final uri = Uri.parse('$baseUrl/api/menus/$id');
    final payload = await _catalogPayload(catalog);
    await _requestJson(
      method: 'PUT',
      uri: uri,
      headers: {'content-type': 'application/json', 'x-edit-token': editToken},
      body: jsonEncode(payload),
    );
  }

  Future<Map<String, Object?>> _catalogPayload(Catalog catalog) async {
    const maxPhotoBytes = 600 * 1024;
    return <String, Object?>{
      'name': catalog.name,
      'currencyCode': catalog.currencyCode,
      'updatedAtMs': catalog.updatedAt.millisecondsSinceEpoch,
      'items': [
        for (final i in catalog.items)
          {
            'title': i.title,
            'price': i.price,
            'description': i.description,
            'section': i.section,
            'subsection': i.subsection,
            'photoDataUrl': await _photoDataUrl(
              i.photoPath,
              maxBytes: maxPhotoBytes,
            ),
          },
      ],
    };
  }

  Future<String?> _photoDataUrl(
    String? photoPath, {
    required int maxBytes,
  }) async {
    final raw = photoPath?.trim();
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith('data:image/')) return raw;

    final normalizedPath = raw.startsWith('file://')
        ? raw.substring('file://'.length)
        : raw;
    final file = File(normalizedPath);
    if (!file.existsSync()) return null;

    final bytes = await file.readAsBytes();

    if (bytes.lengthInBytes <= maxBytes) {
      final lower = normalizedPath.toLowerCase();
      final mime = lower.endsWith('.png') ? 'image/png' : 'image/jpeg';
      return 'data:$mime;base64,${base64Encode(bytes)}';
    }

    try {
      for (final targetWidth in const [360, 320, 280, 240, 200, 160]) {
        final codec = await ui.instantiateImageCodec(
          bytes,
          targetWidth: targetWidth,
        );
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (data == null) continue;

        final thumbBytes = data.buffer.asUint8List();
        if (thumbBytes.lengthInBytes > maxBytes) continue;
        return 'data:image/png;base64,${base64Encode(thumbBytes)}';
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, Object?>> _requestJson({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    String? body,
  }) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, uri);
      headers.forEach(req.headers.set);
      if (body != null) {
        req.add(utf8.encode(body));
      }
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw HttpException('HTTP ${res.statusCode}: $text', uri: uri);
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map) {
        throw StateError('Invalid JSON');
      }
      return Map<String, Object?>.from(decoded);
    } finally {
      client.close(force: true);
    }
  }
}

class PublicMenuCreateResponse {
  const PublicMenuCreateResponse({required this.id, required this.editToken});

  final String id;
  final String editToken;
}
