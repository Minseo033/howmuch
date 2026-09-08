import 'dart:convert';

import 'package:howmuch/core/network/api_client.dart';
import 'package:howmuch/features/store/store_model.dart';
import 'package:http/http.dart' as http;

/// An unavailable bounds endpoint must not erase stores already loaded from
/// the server. The caller applies viewport and user filters to either source.
Future<List<Store>> loadHomeMapStores({
  required Map<String, double> bounds,
  required List<Store> cachedStores,
  Future<http.Response> Function(Uri)? request,
  Duration timeout = const Duration(seconds: 5),
}) async {
  try {
    final uri = ApiClient.uri('/api/stores/bounds', {
      for (final entry in bounds.entries) entry.key: '${entry.value}',
    });
    final response =
        await (request ??
                (uri) =>
                    ApiClient.get(uri, headers: ApiClient.jsonHeaders()))(uri)
            .timeout(timeout);
    if (response.statusCode == 200) {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! List) throw const FormatException('Invalid store list');
      return decoded
          .map((item) => Store.fromJson(Map<String, dynamic>.from(item as Map)))
          .where((store) => store.hasValidCoordinates)
          .toList();
    }
  } catch (_) {
    // Transport errors, timeouts, and malformed responses share the same
    // fallback as HTTP errors. A valid empty list above remains empty.
  }
  return cachedStores.where((store) => store.hasValidCoordinates).toList();
}
