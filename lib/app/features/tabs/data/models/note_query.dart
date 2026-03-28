enum NoteDateFilterScope { all, year, month, day }

enum NoteAmountFilter { all, income, expense }

class NoteQuery {
  const NoteQuery({
    this.scope = NoteDateFilterScope.all,
    this.anchorDate,
    this.amountFilter = NoteAmountFilter.all,
    this.keyword = '',
  });

  final NoteDateFilterScope scope;
  final DateTime? anchorDate;
  final NoteAmountFilter amountFilter;
  final String keyword;

  bool get isActive {
    return scope != NoteDateFilterScope.all ||
        amountFilter != NoteAmountFilter.all ||
        keyword.trim().isNotEmpty;
  }

  NoteQuery copyWith({
    NoteDateFilterScope? scope,
    DateTime? anchorDate,
    bool clearAnchorDate = false,
    NoteAmountFilter? amountFilter,
    String? keyword,
  }) {
    return NoteQuery(
      scope: scope ?? this.scope,
      anchorDate: clearAnchorDate ? null : (anchorDate ?? this.anchorDate),
      amountFilter: amountFilter ?? this.amountFilter,
      keyword: keyword ?? this.keyword,
    );
  }
}
