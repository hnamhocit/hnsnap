import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:hnsnap/features/notes/domain/entities/app_settings.dart';
import 'package:hnsnap/features/notes/domain/entities/note_entry.dart';
import 'package:hnsnap/features/notes/domain/entities/note_query.dart';
import 'package:hnsnap/features/notes/domain/repositories/notes_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class LocalNotesRepository implements NotesRepository {
  static const _databaseName = 'hnsnap_notes.db';
  static const _databaseVersion = 5;
  static const _tableNotes = 'notes';
  static const _tableSettings = 'app_settings';
  static const _imagesDirectoryName = 'note_images';
  static const _videosDirectoryName = 'note_videos';
  static const _backupsDirectoryName = 'note_backups';
  static const _backupSchemaVersion = 1;
  static const _backupManifestName = 'backup.json';

  Database? _database;
  Future<Database>? _databaseFuture;

  Future<Database> get database async {
    final existingDatabase = _database;
    if (existingDatabase != null) {
      return existingDatabase;
    }

    final openingDatabase = _databaseFuture;
    if (openingDatabase != null) {
      return openingDatabase;
    }

    final future = _openDatabase();
    _databaseFuture = future;

    try {
      final database = await future;
      _database = database;
      return database;
    } finally {
      _databaseFuture = null;
    }
  }

  @override
  Future<NoteEntry> createNote({
    required String mediaSourcePath,
    required NoteMediaType mediaType,
    required String note,
    String? transactionType,
    double? amount,
  }) async {
    final db = await database;
    final settings = await _readSettings(db);
    final storedMediaPath = await _storeMedia(
      mediaSourcePath,
      mediaType,
      settings: settings,
    );
    final createdAt = DateTime.now();

    final draft = NoteEntry(
      mediaPath: storedMediaPath,
      mediaType: mediaType,
      note: note,
      transactionType: transactionType,
      amount: amount,
      createdAt: createdAt,
    );

    try {
      final id = await db.insert(_tableNotes, draft.toMap());
      return draft.copyWith(id: id);
    } catch (_) {
      await _deleteFileIfExists(storedMediaPath);
      rethrow;
    }
  }

  @override
  Future<List<NoteEntry>> listNotes(NoteQuery query) async {
    final db = await database;
    await _deleteExpiredNotes(db);
    final where = <String>[];
    final whereArgs = <Object?>[];

    final dateRange = _resolveDateRange(query);
    if (dateRange != null) {
      where.add('created_at >= ? AND created_at < ?');
      whereArgs
        ..add(dateRange.$1.millisecondsSinceEpoch)
        ..add(dateRange.$2.millisecondsSinceEpoch);
    }

    switch (query.amountFilter) {
      case NoteAmountFilter.income:
        where.add('amount > 0');
      case NoteAmountFilter.expense:
        where.add('amount < 0');
      case NoteAmountFilter.all:
        break;
    }

    final keyword = query.keyword.trim().toLowerCase();
    if (keyword.isNotEmpty) {
      where.add(
        '(LOWER(note) LIKE ? OR LOWER(COALESCE(transaction_type, \'\')) LIKE ?)',
      );
      final pattern = '%$keyword%';
      whereArgs
        ..add(pattern)
        ..add(pattern);
    }

    final rows = await db.query(
      _tableNotes,
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'created_at DESC, id DESC',
    );

    return rows.map(NoteEntry.fromMap).toList(growable: false);
  }

  @override
  Future<int> deleteExpiredNotes() async {
    final db = await database;
    return _deleteExpiredNotes(db);
  }

  @override
  Future<AppSettings> getSettings() async {
    final db = await database;
    return _readSettings(db);
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    final db = await database;
    await _writeSettings(db, settings);
  }

  @override
  Future<AppSettings> recordAppOpen() async {
    final db = await database;
    final settings = await _readSettings(db);
    final now = DateTime.now();
    final todayKey = _formatDateKey(now);

    if (settings.lastOpenedOn == todayKey) {
      return settings;
    }

    final yesterdayKey = _formatDateKey(
      DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1)),
    );
    final nextStreakCount = settings.lastOpenedOn == yesterdayKey
        ? (settings.streakCount <= 0 ? 1 : settings.streakCount + 1)
        : 1;
    final updatedSettings = settings.copyWith(
      streakCount: nextStreakCount,
      lastOpenedOn: todayKey,
    );

    await _writeSettings(db, updatedSettings);
    return updatedSettings;
  }

  @override
  Future<List<File>> listBackupFiles() async {
    final backupDirectory = await _getBackupDirectory();
    final entities = await backupDirectory.list().toList();
    final files = entities
        .whereType<File>()
        .where((file) {
          final extension = path.extension(file.path).toLowerCase();
          return extension == '.zip' || extension == '.json';
        })
        .toList(growable: false);

    files.sort((left, right) {
      final leftModified = left.statSync().modified;
      final rightModified = right.statSync().modified;
      return rightModified.compareTo(leftModified);
    });

    return files;
  }

  @override
  Future<File> exportZipBackup() async {
    final db = await database;
    final settings = await _readSettings(db);
    final notes = await listNotes(const NoteQuery());
    final archive = Archive();
    final payloadNotes = <Map<String, Object?>>[];

    for (var index = 0; index < notes.length; index += 1) {
      final note = notes[index];
      final mediaFile = File(note.mediaPath);
      if (!await mediaFile.exists()) {
        continue;
      }

      final mediaBytes = await mediaFile.readAsBytes();
      final mediaFileName =
          'media/${index}_${note.createdAt.millisecondsSinceEpoch}${path.extension(note.mediaPath)}';
      archive.addFile(
        ArchiveFile(mediaFileName, mediaBytes.length, mediaBytes),
      );

      payloadNotes.add({
        'mediaType': note.mediaType.name,
        'note': note.note,
        'transactionType': note.transactionType,
        'amount': note.amount,
        'createdAt': note.createdAt.toIso8601String(),
        'mediaFile': mediaFileName,
        'mediaExtension': path.extension(note.mediaPath),
      });
    }

    final payload = {
      'version': _backupSchemaVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': settings.toJsonMap(),
      'notes': payloadNotes,
    };
    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
    archive.addFile(
      ArchiveFile(_backupManifestName, manifestBytes.length, manifestBytes),
    );

    final backupDirectory = await _getBackupDirectory();
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final backupFile = File(
      path.join(backupDirectory.path, 'hnsnap_backup_$timestamp.zip'),
    );

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw const FormatException('Không tạo được file zip backup.');
    }

    await backupFile.writeAsBytes(zipBytes, flush: true);

    return backupFile;
  }

  @override
  Future<int> importBackup(File backupFile) async {
    final extension = path.extension(backupFile.path).toLowerCase();
    if (extension == '.zip') {
      return _importZipBackup(backupFile);
    }

    return _importJsonBackup(backupFile);
  }

  Future<int> _importZipBackup(File backupFile) async {
    final zipBytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(zipBytes);
    ArchiveFile? manifestFile;

    for (final file in archive.files) {
      if (file.name == _backupManifestName) {
        manifestFile = file;
        break;
      }
    }

    if (manifestFile == null) {
      throw const FormatException('Zip backup không có file backup.json.');
    }

    final manifestContent = manifestFile.content;
    final manifestBytes = manifestContent is List<int>
        ? manifestContent
        : List<int>.from(manifestContent as Iterable);
    final decoded = jsonDecode(utf8.decode(manifestBytes));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('backup.json trong zip không hợp lệ.');
    }

    final mediaEntries = <String, ArchiveFile>{};
    for (final file in archive.files) {
      mediaEntries[file.name] = file;
    }

    final db = await database;
    final settingsPayload = decoded['settings'];
    final notesPayload = decoded['notes'];

    if (settingsPayload is Map<String, dynamic>) {
      await _writeSettings(db, AppSettings.fromJsonMap(settingsPayload));
    }

    if (notesPayload is! List) {
      throw const FormatException(
        'Zip backup không có danh sách notes hợp lệ.',
      );
    }

    await _clearAllNotes(db);

    var importedCount = 0;
    for (final item in notesPayload) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final mediaType = NoteMediaType.fromStorageValue(item['mediaType']);
      final mediaFileName = item['mediaFile'] as String?;
      if (mediaFileName == null || mediaFileName.isEmpty) {
        continue;
      }

      final mediaArchiveFile = mediaEntries[mediaFileName];
      if (mediaArchiveFile == null) {
        continue;
      }

      final createdAtRaw = item['createdAt'] as String?;
      final createdAt = createdAtRaw == null
          ? DateTime.now()
          : DateTime.tryParse(createdAtRaw) ?? DateTime.now();
      final mediaExtension = item['mediaExtension'] as String? ?? '';
      final mediaContent = mediaArchiveFile.content;
      final mediaBytes = mediaContent is List<int>
          ? mediaContent
          : List<int>.from(mediaContent as Iterable);
      final storedMediaPath = await _writeImportedMedia(
        mediaBytes: mediaBytes,
        mediaType: mediaType,
        preferredExtension: mediaExtension,
      );

      final note = NoteEntry(
        mediaPath: storedMediaPath,
        mediaType: mediaType,
        note: item['note'] as String? ?? '',
        transactionType: item['transactionType'] as String?,
        amount: (item['amount'] as num?)?.toDouble(),
        createdAt: createdAt,
      );

      await db.insert(_tableNotes, note.toMap());
      importedCount += 1;
    }

    await _deleteExpiredNotes(db);
    return importedCount;
  }

  Future<int> _importJsonBackup(File backupFile) async {
    final raw = await backupFile.readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Backup JSON không đúng định dạng.');
    }

    final db = await database;
    final settingsPayload = decoded['settings'];
    final notesPayload = decoded['notes'];

    if (settingsPayload is Map<String, dynamic>) {
      await _writeSettings(db, AppSettings.fromJsonMap(settingsPayload));
    }

    if (notesPayload is! List) {
      throw const FormatException('Backup không có danh sách notes hợp lệ.');
    }

    await _clearAllNotes(db);

    var importedCount = 0;
    for (final item in notesPayload) {
      if (item is! Map<String, dynamic>) {
        continue;
      }

      final mediaType = NoteMediaType.fromStorageValue(item['mediaType']);
      final mediaBase64 = item['mediaBase64'];
      if (mediaBase64 is! String || mediaBase64.isEmpty) {
        continue;
      }

      final createdAtRaw = item['createdAt'] as String?;
      final createdAt = createdAtRaw == null
          ? DateTime.now()
          : DateTime.tryParse(createdAtRaw) ?? DateTime.now();
      final mediaExtension = item['mediaExtension'] as String? ?? '';
      final mediaBytes = base64Decode(mediaBase64);
      final storedMediaPath = await _writeImportedMedia(
        mediaBytes: mediaBytes,
        mediaType: mediaType,
        preferredExtension: mediaExtension,
      );

      final note = NoteEntry(
        mediaPath: storedMediaPath,
        mediaType: mediaType,
        note: item['note'] as String? ?? '',
        transactionType: item['transactionType'] as String?,
        amount: (item['amount'] as num?)?.toDouble(),
        createdAt: createdAt,
      );

      await db.insert(_tableNotes, note.toMap());
      importedCount += 1;
    }

    await _deleteExpiredNotes(db);
    return importedCount;
  }

  @override
  Future<void> deleteNote(NoteEntry note) async {
    final db = await database;

    if (note.id != null) {
      await db.delete(_tableNotes, where: 'id = ?', whereArgs: [note.id]);
    }

    await _deleteFileIfExists(note.mediaPath);
  }

  @override
  Future<NoteEntry> updateNote(
    NoteEntry note, {
    String? replacementMediaSourcePath,
    NoteMediaType? replacementMediaType,
  }) async {
    final db = await database;

    if (note.id == null) {
      throw ArgumentError('Không thể cập nhật note chưa có id.');
    }

    NoteEntry updatedNote = note;
    String? storedMediaPath;

    final hasReplacementPath =
        replacementMediaSourcePath != null &&
        replacementMediaSourcePath != note.mediaPath;
    final targetMediaType = replacementMediaType ?? note.mediaType;
    final hasReplacementType = targetMediaType != note.mediaType;

    if (hasReplacementPath || hasReplacementType) {
      final sourcePath = replacementMediaSourcePath ?? note.mediaPath;
      final settings = await _readSettings(db);
      storedMediaPath = await _storeMedia(
        sourcePath,
        targetMediaType,
        settings: settings,
      );
      updatedNote = note.copyWith(
        mediaPath: storedMediaPath,
        mediaType: targetMediaType,
      );
    }

    try {
      await db.update(
        _tableNotes,
        updatedNote.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      if (storedMediaPath != null) {
        await _deleteFileIfExists(storedMediaPath);
      }
      rethrow;
    }

    if (storedMediaPath != null) {
      await _deleteFileIfExists(note.mediaPath);
    }

    return updatedNote;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableNotes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            image_path TEXT NOT NULL,
            media_type TEXT NOT NULL DEFAULT 'image',
            note TEXT NOT NULL DEFAULT '',
            transaction_type TEXT,
            amount REAL,
            created_at INTEGER NOT NULL
          )
        ''');
        await _createSettingsTable(db);
        await _seedDefaultSettings(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE $_tableNotes ADD COLUMN media_type TEXT NOT NULL DEFAULT 'image'",
          );
        }
        if (oldVersion < 3) {
          await _createSettingsTable(db);
          await _seedDefaultSettings(db);
        }
        if (oldVersion < 4) {
          final settingsColumns = await _getTableColumns(db, _tableSettings);

          if (!settingsColumns.contains('streak_count')) {
            await db.execute(
              'ALTER TABLE $_tableSettings ADD COLUMN streak_count INTEGER NOT NULL DEFAULT 0',
            );
          }

          if (!settingsColumns.contains('last_opened_on')) {
            await db.execute(
              'ALTER TABLE $_tableSettings ADD COLUMN last_opened_on TEXT',
            );
          }
        }
        if (oldVersion < 5) {
          final settingsColumns = await _getTableColumns(db, _tableSettings);

          if (!settingsColumns.contains('has_shown_welcome_notification')) {
            await db.execute(
              'ALTER TABLE $_tableSettings ADD COLUMN has_shown_welcome_notification INTEGER NOT NULL DEFAULT 0',
            );
          }
        }
      },
    );
  }

  Future<void> _createSettingsTable(Database db) {
    return db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableSettings (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        note_retention_days INTEGER,
        compress_images INTEGER NOT NULL DEFAULT 1,
        compress_videos INTEGER NOT NULL DEFAULT 1,
        streak_count INTEGER NOT NULL DEFAULT 0,
        last_opened_on TEXT,
        has_shown_welcome_notification INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _seedDefaultSettings(Database db) async {
    final rows = await db.query(
      _tableSettings,
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return;
    }

    await db.insert(
      _tableSettings,
      const AppSettings().toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AppSettings> _readSettings(Database db) async {
    await _createSettingsTable(db);
    await _seedDefaultSettings(db);

    final rows = await db.query(
      _tableSettings,
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );

    if (rows.isEmpty) {
      return const AppSettings();
    }

    return AppSettings.fromDatabaseMap(rows.first);
  }

  Future<void> _writeSettings(Database db, AppSettings settings) async {
    await _createSettingsTable(db);
    await db.insert(
      _tableSettings,
      settings.toDatabaseMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Set<String>> _getTableColumns(Database db, String tableName) async {
    final rows = await db.rawQuery('PRAGMA table_info($tableName)');
    return rows
        .map((row) => row['name'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<int> _deleteExpiredNotes(Database db) async {
    final settings = await _readSettings(db);
    final retentionDays = settings.noteRetentionDays;
    if (retentionDays == null) {
      return 0;
    }

    final cutoff = DateTime.now()
        .subtract(Duration(days: retentionDays))
        .millisecondsSinceEpoch;
    final expiredRows = await db.query(
      _tableNotes,
      where: 'created_at < ?',
      whereArgs: [cutoff],
    );

    if (expiredRows.isEmpty) {
      return 0;
    }

    final expiredNotes = expiredRows.map(NoteEntry.fromMap).toList();
    final expiredIds = expiredNotes
        .map((note) => note.id)
        .whereType<int>()
        .toList(growable: false);

    if (expiredIds.isNotEmpty) {
      final placeholders = List.filled(expiredIds.length, '?').join(', ');
      await db.delete(
        _tableNotes,
        where: 'id IN ($placeholders)',
        whereArgs: expiredIds,
      );
    }

    for (final note in expiredNotes) {
      try {
        await _deleteFileIfExists(note.mediaPath);
      } catch (_) {
        // Keep automatic cleanup best-effort so a stale file does not break loading.
      }
    }

    return expiredNotes.length;
  }

  Future<void> _clearAllNotes(Database db) async {
    final rows = await db.query(_tableNotes);
    final notes = rows.map(NoteEntry.fromMap).toList(growable: false);
    await db.delete(_tableNotes);

    for (final note in notes) {
      try {
        await _deleteFileIfExists(note.mediaPath);
      } catch (_) {
        // Keep backup restore cleanup best-effort.
      }
    }
  }

  (DateTime, DateTime)? _resolveDateRange(NoteQuery query) {
    if (query.scope == NoteDateFilterScope.all) {
      return null;
    }

    final anchorDate = query.anchorDate ?? DateTime.now();

    switch (query.scope) {
      case NoteDateFilterScope.year:
        final start = DateTime(anchorDate.year);
        return (start, DateTime(anchorDate.year + 1));
      case NoteDateFilterScope.month:
        final start = DateTime(anchorDate.year, anchorDate.month);
        final end = anchorDate.month == 12
            ? DateTime(anchorDate.year + 1)
            : DateTime(anchorDate.year, anchorDate.month + 1);
        return (start, end);
      case NoteDateFilterScope.day:
        final start = DateTime(
          anchorDate.year,
          anchorDate.month,
          anchorDate.day,
        );
        return (start, start.add(const Duration(days: 1)));
      case NoteDateFilterScope.all:
        return null;
    }
  }

  Future<String> _storeMedia(
    String sourcePath,
    NoteMediaType mediaType, {
    required AppSettings settings,
  }) {
    return switch (mediaType) {
      NoteMediaType.image =>
        settings.compressImages
            ? _storeCompressedImage(sourcePath)
            : _storeImageCopy(sourcePath),
      NoteMediaType.video => _storeVideo(sourcePath),
    };
  }

  Future<String> _storeImageCopy(String sourcePath) async {
    final imagesDirectory = await _ensureMediaDirectory(_imagesDirectoryName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sourcePath);
    final targetPath = path.join(
      imagesDirectory.path,
      'note_$timestamp${extension.isEmpty ? '.jpg' : extension}',
    );

    final copiedFile = await File(sourcePath).copy(targetPath);
    return copiedFile.path;
  }

  Future<String> _storeCompressedImage(String sourcePath) async {
    final imagesDirectory = await _ensureMediaDirectory(_imagesDirectoryName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final targetPath = path.join(imagesDirectory.path, 'note_$timestamp.jpg');

    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      sourcePath,
      targetPath,
      format: CompressFormat.jpeg,
      quality: 82,
      minWidth: 1600,
      minHeight: 1600,
    );

    if (compressedFile != null) {
      return compressedFile.path;
    }

    final copiedFile = await File(sourcePath).copy(targetPath);
    return copiedFile.path;
  }

  Future<String> _storeVideo(String sourcePath) async {
    final videosDirectory = await _ensureMediaDirectory(_videosDirectoryName);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = path.extension(sourcePath);
    final targetPath = path.join(
      videosDirectory.path,
      'note_$timestamp${extension.isEmpty ? '.mp4' : extension}',
    );

    final copiedFile = await File(sourcePath).copy(targetPath);
    return copiedFile.path;
  }

  Future<String> _writeImportedMedia({
    required List<int> mediaBytes,
    required NoteMediaType mediaType,
    required String preferredExtension,
  }) async {
    final directory = await _ensureMediaDirectory(
      mediaType.isVideo ? _videosDirectoryName : _imagesDirectoryName,
    );
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final fallbackExtension = mediaType.isVideo ? '.mp4' : '.jpg';
    final extension = preferredExtension.isEmpty
        ? fallbackExtension
        : preferredExtension;
    final targetPath = path.join(directory.path, 'import_$timestamp$extension');
    final file = File(targetPath);
    await file.writeAsBytes(mediaBytes, flush: true);
    return file.path;
  }

  Future<Directory> _ensureMediaDirectory(String directoryName) async {
    final appDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(appDirectory.path, directoryName));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  Future<Directory> _getBackupDirectory() async {
    final externalDirectory = await getExternalStorageDirectory();
    final baseDirectory =
        externalDirectory ?? await getApplicationDocumentsDirectory();
    final backupDirectory = Directory(
      path.join(baseDirectory.path, _backupsDirectoryName),
    );

    if (!await backupDirectory.exists()) {
      await backupDirectory.create(recursive: true);
    }

    return backupDirectory;
  }

  Future<void> _deleteFileIfExists(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _formatDateKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
