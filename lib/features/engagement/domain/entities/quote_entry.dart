class QuoteEntry {
  const QuoteEntry({
    required this.content,
    required this.author,
    required this.source,
  });

  final String content;
  final String author;
  final String source;

  String get formattedLine =>
      author.trim().isEmpty ? content : '$content\n- $author';

  Map<String, Object?> toJsonMap() {
    return {'content': content, 'author': author, 'source': source};
  }

  factory QuoteEntry.fromJsonMap(Map<String, dynamic> map) {
    return QuoteEntry(
      content: map['content'] as String? ?? '',
      author: map['author'] as String? ?? '',
      source: map['source'] as String? ?? 'local',
    );
  }

  factory QuoteEntry.fromZenQuotesMap(Map<String, dynamic> map) {
    return QuoteEntry(
      content: map['q'] as String? ?? '',
      author: map['a'] as String? ?? '',
      source: 'zenquotes',
    );
  }
}
