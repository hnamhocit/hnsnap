import 'dart:convert';
import 'dart:io';

import 'package:hnsnap/features/engagement/domain/entities/quote_entry.dart';

class QuoteRemoteSource {
  static final Uri _quotesUri = Uri.parse('https://zenquotes.io/api/quotes');

  Future<List<QuoteEntry>> fetchQuotes() async {
    final httpClient = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8);

    try {
      final request = await httpClient.getUrl(_quotesUri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const [];
      }

      final responseBody = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(responseBody);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                QuoteEntry.fromZenQuotesMap(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.content.trim().isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    } finally {
      httpClient.close(force: true);
    }
  }
}
