import 'package:hnsnap/features/notes/domain/repositories/notes_repository.dart';

class NoteCatalogRouteExtra {
  const NoteCatalogRouteExtra({
    required this.notesRepository,
    this.initialSelectedNoteId,
  });

  final NotesRepository notesRepository;
  final int? initialSelectedNoteId;
}

class SettingsRouteExtra {
  const SettingsRouteExtra({required this.notesRepository});

  final NotesRepository notesRepository;
}
