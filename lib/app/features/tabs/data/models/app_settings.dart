enum NoteRetentionPreset {
  days30(30, '30 ngày'),
  days60(60, '60 ngày'),
  days90(90, '90 ngày'),
  days180(180, '180 ngày'),
  forever(null, 'Vĩnh viễn');

  const NoteRetentionPreset(this.days, this.label);

  final int? days;
  final String label;

  static NoteRetentionPreset fromDays(int? days) {
    for (final preset in values) {
      if (preset.days == days) {
        return preset;
      }
    }

    return NoteRetentionPreset.days90;
  }
}

class AppSettings {
  const AppSettings({
    this.noteRetentionDays = 90,
    this.compressImages = true,
    this.compressVideos = true,
    this.streakCount = 0,
    this.lastOpenedOn,
    this.hasShownWelcomeNotification = false,
  });

  final int? noteRetentionDays;
  final bool compressImages;
  final bool compressVideos;
  final int streakCount;
  final String? lastOpenedOn;
  final bool hasShownWelcomeNotification;

  NoteRetentionPreset get retentionPreset =>
      NoteRetentionPreset.fromDays(noteRetentionDays);

  Map<String, Object?> toDatabaseMap() {
    return {
      'id': 1,
      'note_retention_days': noteRetentionDays,
      'compress_images': compressImages ? 1 : 0,
      'compress_videos': compressVideos ? 1 : 0,
      'streak_count': streakCount,
      'last_opened_on': lastOpenedOn,
      'has_shown_welcome_notification': hasShownWelcomeNotification ? 1 : 0,
    };
  }

  Map<String, Object?> toJsonMap() {
    return {
      'noteRetentionDays': noteRetentionDays,
      'compressImages': compressImages,
      'compressVideos': compressVideos,
      'streakCount': streakCount,
      'lastOpenedOn': lastOpenedOn,
      'hasShownWelcomeNotification': hasShownWelcomeNotification,
    };
  }

  AppSettings copyWith({
    int? noteRetentionDays,
    bool clearRetentionDays = false,
    bool? compressImages,
    bool? compressVideos,
    int? streakCount,
    String? lastOpenedOn,
    bool clearLastOpenedOn = false,
    bool? hasShownWelcomeNotification,
  }) {
    return AppSettings(
      noteRetentionDays: clearRetentionDays
          ? null
          : (noteRetentionDays ?? this.noteRetentionDays),
      compressImages: compressImages ?? this.compressImages,
      compressVideos: compressVideos ?? this.compressVideos,
      streakCount: streakCount ?? this.streakCount,
      lastOpenedOn: clearLastOpenedOn
          ? null
          : (lastOpenedOn ?? this.lastOpenedOn),
      hasShownWelcomeNotification:
          hasShownWelcomeNotification ?? this.hasShownWelcomeNotification,
    );
  }

  factory AppSettings.fromDatabaseMap(Map<String, Object?> map) {
    return AppSettings(
      noteRetentionDays: map['note_retention_days'] as int?,
      compressImages: ((map['compress_images'] as num?)?.toInt() ?? 1) != 0,
      compressVideos: ((map['compress_videos'] as num?)?.toInt() ?? 1) != 0,
      streakCount: (map['streak_count'] as num?)?.toInt() ?? 0,
      lastOpenedOn: map['last_opened_on'] as String?,
      hasShownWelcomeNotification:
          ((map['has_shown_welcome_notification'] as num?)?.toInt() ?? 0) != 0,
    );
  }

  factory AppSettings.fromJsonMap(Map<String, dynamic> map) {
    final rawRetention = map['noteRetentionDays'];
    return AppSettings(
      noteRetentionDays: rawRetention is num ? rawRetention.toInt() : null,
      compressImages: map['compressImages'] as bool? ?? true,
      compressVideos: map['compressVideos'] as bool? ?? true,
      streakCount: (map['streakCount'] as num?)?.toInt() ?? 0,
      lastOpenedOn: map['lastOpenedOn'] as String?,
      hasShownWelcomeNotification:
          map['hasShownWelcomeNotification'] as bool? ?? false,
    );
  }
}
