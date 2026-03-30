// ignore_for_file: invalid_use_of_protected_member

part of 'home_screen.dart';

extension on _HomeScreenState {
  Future<void> _submitPost() async {
    if (!_isPostMode || !mounted || _selectedMedia == null || _isSavingNote) {
      return;
    }

    final rawAmount = _priceController.text.trim();
    final amount = _parseAmount(rawAmount);
    if (rawAmount.isNotEmpty && amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Số tiền chưa đúng định dạng.')),
      );
      return;
    }

    setState(() {
      _isSavingNote = true;
    });

    try {
      final draftNote = _captionController.text.trim();
      final editingNote = _editingNote;

      if (editingNote != null) {
        final updatedNote = await _notesRepository.updateNote(
          editingNote.copyWith(note: draftNote, amount: amount),
          replacementMediaSourcePath:
              _selectedMedia!.path == editingNote.mediaPath
              ? null
              : _selectedMedia!.path,
          replacementMediaType: _selectedMediaType,
        );

        if (!mounted) {
          return;
        }

        _captionFocusNode.unfocus();
        _priceFocusNode.unfocus();

        setState(_clearComposerState);
        await _loadNotes(jumpToNoteId: updatedNote.id);

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Đã cập nhật ghi chú.')));
      } else {
        final savedNote = await _notesRepository.createNote(
          mediaSourcePath: _selectedMedia!.path,
          mediaType: _selectedMediaType!,
          note: draftNote,
          amount: amount,
        );

        if (!mounted) {
          return;
        }

        _captionFocusNode.unfocus();
        _priceFocusNode.unfocus();

        setState(_clearComposerState);
        await _loadNotes(jumpToNoteId: savedNote.id);

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã lưu ghi chú vào máy.')),
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditingMode
                ? 'Không cập nhật được ghi chú.'
                : 'Không lưu được ghi chú.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingNote = false;
        });
      }
    }
  }

  Future<void> _jumpToComposePage() async {
    FocusScope.of(context).unfocus();
    await _animateToPage(0);
  }

  Future<void> _jumpToFirstNotePage() async {
    FocusScope.of(context).unfocus();

    if (_notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có ghi chú nào được lưu.')),
      );
      return;
    }

    await _jumpToNotePageByIndex(0);
  }

  Future<void> _animateToPage(int pageIndex) async {
    if (!_feedPageController.hasClients) {
      setState(() {
        _currentPageIndex = pageIndex;
        if (pageIndex > 0) {
          _currentFeedIndex = _normalizeFeedIndex(pageIndex - 1, _notes.length);
        }
      });
      return;
    }

    await _feedPageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _jumpToNotePageByIndex(int noteIndex) async {
    if (_notes.isEmpty) {
      return;
    }

    final normalizedIndex = _normalizeFeedIndex(noteIndex, _notes.length);
    await _animateToPage(normalizedIndex + 1);
  }

  Future<void> _openCatalogPage() async {
    if (_notes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có ghi chú nào để xem trong thư viện.'),
        ),
      );
      return;
    }

    final result = await context.pushNamed<NoteCatalogResult>(
      AppRoutes.noteCatalog,
      extra: NoteCatalogRouteExtra(
        notesRepository: _notesRepository,
        initialSelectedNoteId: _currentFeedNote?.id,
      ),
    );

    if (!mounted || result == null || result.noteId == null) {
      return;
    }

    final note = _findNoteById(result.noteId!);
    if (note == null) {
      await _loadNotes(jumpToNoteId: result.noteId);
      return;
    }

    switch (result.action) {
      case NoteCatalogAction.open:
        final targetIndex = _notes.indexWhere(
          (item) => item.id == result.noteId,
        );
        if (targetIndex >= 0) {
          await _jumpToNotePageByIndex(targetIndex);
        }
        break;
      case NoteCatalogAction.edit:
        await _startEditingNote(note);
        break;
      case NoteCatalogAction.delete:
        await _deleteNote(note);
        break;
      case NoteCatalogAction.download:
        await _downloadNote(note);
        break;
      case NoteCatalogAction.share:
        await _shareNote(note);
        break;
    }
  }

  Future<void> _openCurrentNoteActions() async {
    if (_isRunningNoteAction || _currentFeedNote == null) {
      return;
    }

    final action = await _showStoredNoteActionsSheet();
    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case _StoredNoteAction.edit:
        await _startEditingCurrentNote();
        break;
      case _StoredNoteAction.delete:
        await _deleteCurrentNote();
        break;
      case _StoredNoteAction.download:
        await _downloadCurrentNote();
        break;
      case _StoredNoteAction.share:
        await _shareCurrentNote();
        break;
    }
  }

  Future<_StoredNoteAction?> _showStoredNoteActionsSheet() {
    return showModalBottomSheet<_StoredNoteAction>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.squarePen),
                title: const Text('Sửa'),
                onTap: () => Navigator.of(context).pop(_StoredNoteAction.edit),
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash2),
                title: const Text('Xóa'),
                onTap: () =>
                    Navigator.of(context).pop(_StoredNoteAction.delete),
              ),
              ListTile(
                leading: const Icon(LucideIcons.download),
                title: const Text('Tải xuống'),
                onTap: () =>
                    Navigator.of(context).pop(_StoredNoteAction.download),
              ),
              ListTile(
                leading: const Icon(LucideIcons.share2),
                title: const Text('Chia sẻ'),
                onTap: () => Navigator.of(context).pop(_StoredNoteAction.share),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _startEditingCurrentNote() async {
    final note = _currentFeedNote;
    if (note == null) {
      return;
    }

    await _startEditingNote(note);
  }

  Future<void> _startEditingNote(NoteEntry note) async {
    final targetIndex = _notes.indexWhere((item) => item.id == note.id);
    if (targetIndex >= 0) {
      _currentFeedIndex = targetIndex;
    }

    setState(() {
      _editingNote = note;
      _selectedMedia = XFile(note.mediaPath);
      _selectedMediaType = note.mediaType;
      _shouldMirrorSelectedImage = false;
      _captionController.text = note.note;
      _priceController.text = note.amount == null
          ? ''
          : formatAmount(note.amount!);
    });

    await _syncCameraActivity();
    await _jumpToComposePage();
  }

  Future<void> _deleteCurrentNote() async {
    final note = _currentFeedNote;
    if (note == null || _isDeletingCurrentNote) {
      return;
    }

    await _deleteNote(note);
  }

  Future<void> _deleteNote(NoteEntry note) async {
    if (_isDeletingCurrentNote) {
      return;
    }

    final confirmed = await _confirmDeleteNote();
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _isDeletingCurrentNote = true;
    });

    try {
      await _notesRepository.deleteNote(note);
      await _loadNotes();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa ghi chú.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không xóa được ghi chú.')));
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingCurrentNote = false;
        });
      }
    }
  }

  Future<bool?> _confirmDeleteNote() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa ghi chú này?'),
          content: const Text(
            'Ảnh hoặc video đã lưu trong app và dữ liệu SQLite của ghi chú này sẽ bị xóa.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadCurrentNote() async {
    final note = _currentFeedNote;
    if (note == null || _isDownloadingCurrentNote) {
      return;
    }

    await _downloadNote(note);
  }

  Future<void> _shareCurrentNote() async {
    final note = _currentFeedNote;
    if (note == null || _isSharingCurrentNote) {
      return;
    }

    await _shareNote(note);
  }

  Future<void> _downloadNote(NoteEntry note) async {
    if (_isDownloadingCurrentNote) {
      return;
    }

    setState(() {
      _isDownloadingCurrentNote = true;
    });

    try {
      final success = note.mediaType.isVideo
          ? await GallerySaver.saveVideo(note.mediaPath, albumName: 'HNSnap')
          : await GallerySaver.saveImage(note.mediaPath, albumName: 'HNSnap');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success == true
                ? (note.mediaType.isVideo
                      ? 'Đã lưu video vào thư viện ảnh.'
                      : 'Đã lưu ảnh vào thư viện ảnh.')
                : (note.mediaType.isVideo
                      ? 'Không lưu video vào thư viện ảnh được.'
                      : 'Không lưu ảnh vào thư viện ảnh được.'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            note.mediaType.isVideo
                ? 'Không lưu video vào thư viện ảnh được.'
                : 'Không lưu ảnh vào thư viện ảnh được.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingCurrentNote = false;
        });
      }
    }
  }

  Future<void> _shareNote(NoteEntry note) async {
    if (_isSharingCurrentNote) {
      return;
    }

    setState(() {
      _isSharingCurrentNote = true;
    });

    try {
      final shareText = [
        if (note.note.trim().isNotEmpty) note.note.trim(),
        if (note.amount != null) formatAmount(note.amount!),
      ].join('\n');

      await Share.shareXFiles([
        XFile(note.mediaPath),
      ], text: shareText.isEmpty ? null : shareText);
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            note.mediaType.isVideo
                ? 'Không chia sẻ video được.'
                : 'Không chia sẻ ảnh được.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSharingCurrentNote = false;
        });
      }
    }
  }

  Future<void> _openSettingsScreen() async {
    final shouldReload = await context.pushNamed<bool>(
      AppRoutes.settings,
      extra: SettingsRouteExtra(notesRepository: _notesRepository),
    );

    if (!mounted || shouldReload != true) {
      return;
    }

    await _loadNotes();
    await _syncEngagement();
  }
}
