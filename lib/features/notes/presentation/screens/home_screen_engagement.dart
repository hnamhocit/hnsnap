// ignore_for_file: invalid_use_of_protected_member

part of 'home_screen.dart';

extension on _HomeScreenState {
  Future<void> _syncEngagement() {
    final existingFuture = _engagementSyncFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _runEngagementSync();
    _engagementSyncFuture = future;
    future.whenComplete(() {
      if (identical(_engagementSyncFuture, future)) {
        _engagementSyncFuture = null;
      }
    });
    return future;
  }

  Future<void> _runEngagementSync() async {
    try {
      var settings = await _notesRepository.recordAppOpen();

      if (mounted && _streakCount != settings.streakCount) {
        setState(() {
          _streakCount = settings.streakCount;
        });
      }

      await _dailyEngagementService.ensureInitialized();
      if (!settings.hasShownWelcomeNotification) {
        final didShowWelcomeNotification = await _dailyEngagementService
            .showWelcomeNotification();
        if (didShowWelcomeNotification) {
          settings = settings.copyWith(hasShownWelcomeNotification: true);
          await _notesRepository.saveSettings(settings);
        }
      }
      await _dailyEngagementService.scheduleDailyNotifications(
        streakCount: settings.streakCount,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      final fallbackSettings = await _notesRepository.getSettings();
      if (!mounted || _streakCount == fallbackSettings.streakCount) {
        return;
      }

      setState(() {
        _streakCount = fallbackSettings.streakCount;
      });
    }
  }

  Future<void> _loadNotes({int? jumpToNoteId}) async {
    if (mounted) {
      setState(() {
        _isLoadingNotes = true;
      });
    }

    try {
      final notes = await _notesRepository.listNotes(const NoteQuery());

      if (!mounted) {
        return;
      }

      final targetIndex = _resolveFeedIndex(notes, jumpToNoteId: jumpToNoteId);
      final targetPageIndex = _resolvePageIndex(
        notes: notes,
        targetNoteIndex: targetIndex,
        jumpToNoteId: jumpToNoteId,
      );

      setState(() {
        _notes = notes;
        _currentFeedIndex = targetIndex;
        _currentPageIndex = targetPageIndex;
        _isLoadingNotes = false;
      });

      _syncCameraActivity();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_feedPageController.hasClients) {
          return;
        }

        _feedPageController.jumpToPage(targetPageIndex);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _notes = const [];
        _currentPageIndex = 0;
        _currentFeedIndex = 0;
        _isLoadingNotes = false;
      });

      _syncCameraActivity();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không tải được dữ liệu đã lưu.')),
      );
    }
  }

  int _resolveFeedIndex(List<NoteEntry> notes, {int? jumpToNoteId}) {
    if (notes.isEmpty) {
      return 0;
    }

    if (jumpToNoteId != null) {
      final jumpIndex = notes.indexWhere((note) => note.id == jumpToNoteId);
      if (jumpIndex >= 0) {
        return jumpIndex;
      }
    }

    return _normalizeFeedIndex(_currentFeedIndex, notes.length);
  }

  int _resolvePageIndex({
    required List<NoteEntry> notes,
    required int targetNoteIndex,
    int? jumpToNoteId,
  }) {
    if (notes.isEmpty) {
      return 0;
    }

    if (jumpToNoteId != null) {
      return targetNoteIndex + 1;
    }

    if (_isOnComposePage) {
      return 0;
    }

    return targetNoteIndex + 1;
  }

  int _normalizeFeedIndex(int candidate, int length) {
    if (length <= 0) {
      return 0;
    }

    if (candidate < 0) {
      return 0;
    }

    if (candidate >= length) {
      return length - 1;
    }

    return candidate;
  }

  double? _parseAmount(String rawValue) {
    if (rawValue.trim().isEmpty) {
      return null;
    }

    final normalized = rawValue
        .replaceAll(RegExp(r'[^0-9,.\-+]'), '')
        .replaceAll(',', '');
    if (normalized.isEmpty) {
      return null;
    }

    return double.tryParse(normalized);
  }

  NoteEntry? _findNoteById(int noteId) {
    for (final note in _notes) {
      if (note.id == noteId) {
        return note;
      }
    }

    return null;
  }
}

mixin _HomeScreenEngagementMixin on _HomeScreenState {}
