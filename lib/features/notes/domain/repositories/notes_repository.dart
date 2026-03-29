import 'dart:io';

import 'package:hnsnap/features/notes/domain/entities/app_settings.dart';
import 'package:hnsnap/features/notes/domain/entities/note_entry.dart';
import 'package:hnsnap/features/notes/domain/entities/note_query.dart';

abstract interface class NotesRepository {
  Future<NoteEntry> createNote({
    required String mediaSourcePath,
    required NoteMediaType mediaType,
    required String note,
    String? transactionType,
    double? amount,
  });

  Future<List<NoteEntry>> listNotes(NoteQuery query);

  Future<int> deleteExpiredNotes();

  Future<AppSettings> getSettings();

  Future<void> saveSettings(AppSettings settings);

  Future<AppSettings> recordAppOpen();

  Future<List<File>> listBackupFiles();

  Future<File> exportZipBackup();

  Future<int> importBackup(File backupFile);

  Future<void> deleteNote(NoteEntry note);

  Future<NoteEntry> updateNote(
    NoteEntry note, {
    String? replacementMediaSourcePath,
    NoteMediaType? replacementMediaType,
  });
}
