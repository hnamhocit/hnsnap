enum NoteMediaType {
  image,
  video;

  bool get isImage => this == NoteMediaType.image;
  bool get isVideo => this == NoteMediaType.video;

  static NoteMediaType fromStorageValue(Object? value) {
    return switch (value) {
      'video' => NoteMediaType.video,
      _ => NoteMediaType.image,
    };
  }
}

class NoteEntry {
  const NoteEntry({
    this.id,
    required this.mediaPath,
    this.mediaType = NoteMediaType.image,
    required this.note,
    this.transactionType,
    this.amount,
    required this.createdAt,
  });

  final int? id;
  final String mediaPath;
  final NoteMediaType mediaType;
  final String note;
  final String? transactionType;
  final double? amount;
  final DateTime createdAt;

  String get imagePath => mediaPath;

  NoteEntry copyWith({
    int? id,
    String? mediaPath,
    NoteMediaType? mediaType,
    String? note,
    String? transactionType,
    double? amount,
    DateTime? createdAt,
  }) {
    return NoteEntry(
      id: id ?? this.id,
      mediaPath: mediaPath ?? this.mediaPath,
      mediaType: mediaType ?? this.mediaType,
      note: note ?? this.note,
      transactionType: transactionType ?? this.transactionType,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'image_path': mediaPath,
      'media_type': mediaType.name,
      'note': note,
      'transaction_type': transactionType,
      'amount': amount,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  factory NoteEntry.fromMap(Map<String, Object?> map) {
    return NoteEntry(
      id: map['id'] as int?,
      mediaPath: map['image_path']! as String,
      mediaType: NoteMediaType.fromStorageValue(map['media_type']),
      note: map['note']! as String,
      transactionType: map['transaction_type'] as String?,
      amount: (map['amount'] as num?)?.toDouble(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at']! as int),
    );
  }
}
