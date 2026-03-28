import 'dart:convert';
import 'dart:io';

import 'package:hnsnap/app/features/tabs/data/models/quote_entry.dart';
import 'package:hnsnap/app/features/tabs/data/sources/quote_remote_source.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class QuoteRepository {
  QuoteRepository({QuoteRemoteSource? remoteSource})
    : _remoteSource = remoteSource ?? QuoteRemoteSource();

  static const _cacheFileName = 'quotes_cache.json';
  static const _cacheRefreshInterval = Duration(hours: 1);

  static const List<QuoteEntry> _fallbackQuotes = [
    QuoteEntry(
      content: 'Một ngày gọn gàng bắt đầu từ một lần mở app thật nhỏ.',
      author: 'hnsnap',
      source: 'local',
    ),
    QuoteEntry(
      content: 'Ghi lại một chút hôm nay để mai nhìn lại thấy rõ hơn.',
      author: 'hnsnap',
      source: 'local',
    ),
    QuoteEntry(
      content: 'Tiến độ không cần lớn, chỉ cần đều.',
      author: 'hnsnap',
      source: 'local',
    ),
    QuoteEntry(
      content: 'Một note nhỏ hôm nay vẫn hơn một ý tưởng để mai.',
      author: 'hnsnap',
      source: 'local',
    ),
    QuoteEntry(
      content: 'Bạn không cần hoàn hảo, chỉ cần quay lại đúng hẹn.',
      author: 'hnsnap',
      source: 'local',
    ),
    QuoteEntry(
      content: 'Kỷ luật nhỏ mỗi ngày thường mạnh hơn hứng lên ngắn hạn.',
      author: 'hnsnap',
      source: 'local',
    ),
    QuoteEntry(
      content: '7 giờ sáng là một điểm bắt đầu đẹp để giữ nhịp cho cả ngày.',
      author: 'hnsnap',
      source: 'local',
    ),
    QuoteEntry(
      content: 'Điều đáng giá nhất là sự liên tục, không phải tốc độ.',
      author: 'hnsnap',
      source: 'local',
    ),
  ];

  final QuoteRemoteSource _remoteSource;

  Future<List<QuoteEntry>> getQuotesForSchedule({required int count}) async {
    final cacheSnapshot = await _readCacheSnapshot();

    if (_shouldRefresh(cacheSnapshot.cachedAt)) {
      final remoteQuotes = _dedupeQuotes(await _remoteSource.fetchQuotes());
      if (remoteQuotes.isNotEmpty) {
        await _writeCacheSnapshot(
          cachedAt: DateTime.now(),
          quotes: remoteQuotes,
        );
        return _fillToCount(remoteQuotes, count);
      }
    }

    if (cacheSnapshot.quotes.isNotEmpty) {
      return _fillToCount(cacheSnapshot.quotes, count);
    }

    return _fillToCount(_fallbackQuotes, count);
  }

  Future<({DateTime? cachedAt, List<QuoteEntry> quotes})>
  _readCacheSnapshot() async {
    try {
      final cacheFile = await _getCacheFile();
      if (!await cacheFile.exists()) {
        return (cachedAt: null, quotes: const <QuoteEntry>[]);
      }

      final raw = await cacheFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return (cachedAt: null, quotes: const <QuoteEntry>[]);
      }

      final cachedAtRaw = decoded['cachedAt'] as String?;
      final quotesPayload = decoded['quotes'];
      final quotes = quotesPayload is List
          ? quotesPayload
                .whereType<Map>()
                .map(
                  (item) =>
                      QuoteEntry.fromJsonMap(Map<String, dynamic>.from(item)),
                )
                .where((item) => item.content.trim().isNotEmpty)
                .toList(growable: false)
          : const <QuoteEntry>[];

      return (
        cachedAt: cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw),
        quotes: quotes,
      );
    } catch (_) {
      return (cachedAt: null, quotes: const <QuoteEntry>[]);
    }
  }

  Future<void> _writeCacheSnapshot({
    required DateTime cachedAt,
    required List<QuoteEntry> quotes,
  }) async {
    final cacheFile = await _getCacheFile();
    final payload = {
      'cachedAt': cachedAt.toIso8601String(),
      'quotes': quotes.map((item) => item.toJsonMap()).toList(growable: false),
    };
    await cacheFile.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<File> _getCacheFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File(path.join(directory.path, _cacheFileName));
  }

  bool _shouldRefresh(DateTime? cachedAt) {
    if (cachedAt == null) {
      return true;
    }

    return DateTime.now().difference(cachedAt) >= _cacheRefreshInterval;
  }

  List<QuoteEntry> _dedupeQuotes(List<QuoteEntry> quotes) {
    final seenKeys = <String>{};
    final results = <QuoteEntry>[];

    for (final quote in quotes) {
      final key =
          '${quote.content.trim().toLowerCase()}|${quote.author.trim().toLowerCase()}';
      if (!seenKeys.add(key)) {
        continue;
      }

      results.add(quote);
    }

    return results;
  }

  List<QuoteEntry> _fillToCount(List<QuoteEntry> source, int count) {
    final merged = _dedupeQuotes([...source, ..._fallbackQuotes]);
    if (merged.isEmpty || count <= 0) {
      return const [];
    }

    if (merged.length >= count) {
      return merged.take(count).toList(growable: false);
    }

    final results = <QuoteEntry>[];
    for (var index = 0; index < count; index += 1) {
      results.add(merged[index % merged.length]);
    }
    return results;
  }
}
