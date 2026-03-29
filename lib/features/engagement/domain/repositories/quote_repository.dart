import 'package:hnsnap/features/engagement/domain/entities/quote_entry.dart';

abstract interface class QuoteRepository {
  Future<List<QuoteEntry>> getQuotesForSchedule({required int count});
}
