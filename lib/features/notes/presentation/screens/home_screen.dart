import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:go_router/go_router.dart';
import 'package:hnsnap/app/router/app_route_extras.dart';
import 'package:hnsnap/app/router/app_routes.dart';
import 'package:hnsnap/common/utils/note_formatters.dart';
import 'package:hnsnap/features/engagement/application/services/daily_engagement_service.dart';
import 'package:hnsnap/features/notes/data/repositories/local_notes_repository.dart';
import 'package:hnsnap/features/notes/domain/entities/note_entry.dart';
import 'package:hnsnap/features/notes/domain/entities/note_query.dart';
import 'package:hnsnap/features/notes/domain/repositories/notes_repository.dart';
import 'package:hnsnap/features/notes/presentation/screens/gallery_media_picker_screen.dart';
import 'package:hnsnap/features/notes/presentation/screens/note_catalog_screen.dart';
import 'package:hnsnap/features/notes/presentation/widgets/home_header.dart';
import 'package:hnsnap/features/notes/presentation/widgets/note_compose_body.dart';
import 'package:hnsnap/features/notes/presentation/widgets/note_feed_view.dart';
import 'package:hnsnap/features/notes/presentation/widgets/note_media_view.dart';
import 'package:hnsnap/features/notes/presentation/widgets/note_shared_widgets.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final NotesRepository _notesRepository = LocalNotesRepository();
  final DailyEngagementService _dailyEngagementService =
      DailyEngagementService.instance;
  final PageController _feedPageController = PageController();
  final TextEditingController _captionController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  final TextEditingController _priceController = TextEditingController();
  final FocusNode _priceFocusNode = FocusNode();

  CameraController? _cameraController;
  Future<void>? _initializeCameraFuture;
  List<CameraDescription> _cameras = const [];
  int _currentCameraIndex = 0;
  bool _isSwitchingCamera = false;
  bool _isSavingNote = false;
  bool _isLoadingNotes = true;
  bool _isDeletingCurrentNote = false;
  bool _isDownloadingCurrentNote = false;
  bool _isSharingCurrentNote = false;
  bool _isLockingPageSwipe = false;
  AppLifecycleState _appLifecycleState = AppLifecycleState.resumed;
  String? _errorMessage;
  XFile? _selectedMedia;
  NoteMediaType? _selectedMediaType;
  bool _shouldMirrorSelectedImage = false;
  List<NoteEntry> _notes = const [];
  int _currentPageIndex = 0;
  int _currentFeedIndex = 0;
  int _streakCount = 0;
  NoteEntry? _editingNote;
  Future<void>? _engagementSyncFuture;

  bool get _isPostMode => _selectedMedia != null && _selectedMediaType != null;
  bool get _isOnComposePage => _currentPageIndex == 0;
  bool get _shouldKeepCameraActive =>
      _appLifecycleState == AppLifecycleState.resumed &&
      _isOnComposePage &&
      !_isPostMode;
  bool get _hasStoredNotes => _notes.isNotEmpty;
  bool get _isEditingMode => _editingNote != null;
  bool get _isRunningNoteAction =>
      _isDeletingCurrentNote ||
      _isDownloadingCurrentNote ||
      _isSharingCurrentNote;
  bool get _isSelectedVideo => _selectedMediaType?.isVideo ?? false;

  NoteEntry? get _currentFeedNote {
    if (_notes.isEmpty || _isOnComposePage) {
      return null;
    }

    final index = _normalizeFeedIndex(_currentFeedIndex, _notes.length);
    return _notes[index];
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCameraActivity();
    unawaited(_syncEngagement());
    _loadNotes();
  }

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

  Future<void> _ensureCameraReady() async {
    if (!_shouldKeepCameraActive) {
      return;
    }

    if (_cameraController != null || _initializeCameraFuture != null) {
      return;
    }

    try {
      if (_cameras.isEmpty) {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          if (!mounted) {
            return;
          }

          setState(() {
            _errorMessage = 'Không tìm thấy camera nào trên thiết bị.';
          });
          return;
        }

        _cameras = cameras;
      }

      final camera = _cameraController?.description ?? _findInitialCamera();
      await _activateCamera(camera);
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Không mở được camera: ${error.description ?? error.code}';
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = 'Đã có lỗi khi khởi tạo camera.';
      });
    }
  }

  CameraDescription _findInitialCamera() {
    final backCameraIndex = _cameras.indexWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
    );

    if (backCameraIndex >= 0) {
      _currentCameraIndex = backCameraIndex;
      return _cameras[backCameraIndex];
    }

    _currentCameraIndex = 0;
    return _cameras.first;
  }

  Future<void> _activateCamera(CameraDescription camera) async {
    final previousController = _cameraController;
    final cameraIndex = _cameras.indexOf(camera);

    if (mounted) {
      setState(() {
        _cameraController = null;
        _initializeCameraFuture = null;
        _errorMessage = null;
      });
    }

    await previousController?.dispose();

    final result = await _createBestAvailableController(camera);

    if (!mounted || !_shouldKeepCameraActive) {
      await result.controller.dispose();
      return;
    }

    setState(() {
      _cameraController = result.controller;
      _initializeCameraFuture = result.initializeFuture;
      _currentCameraIndex = cameraIndex >= 0
          ? cameraIndex
          : _currentCameraIndex;
      _errorMessage = null;
    });
  }

  Future<
    ({
      CameraController controller,
      Future<void> initializeFuture,
      ResolutionPreset preset,
    })
  >
  _createBestAvailableController(CameraDescription camera) async {
    const presets = [
      ResolutionPreset.high,
      ResolutionPreset.medium,
      ResolutionPreset.low,
    ];

    CameraException? lastError;

    for (final preset in presets) {
      final controller = CameraController(camera, preset, enableAudio: false);

      try {
        final initializeFuture = controller.initialize();
        await initializeFuture;

        return (
          controller: controller,
          initializeFuture: initializeFuture,
          preset: preset,
        );
      } on CameraException catch (error) {
        lastError = error;
        await controller.dispose();
      }
    }

    throw lastError ??
        CameraException(
          'cameraInitializationFailed',
          'Không tìm được mức độ phân giải phù hợp cho thiết bị.',
        );
  }

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera) {
      return;
    }

    if (_cameras.length < 2) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thiết bị này chỉ có một camera.')),
      );
      return;
    }

    final nextCameraIndex = (_currentCameraIndex + 1) % _cameras.length;
    final nextCamera = _cameras[nextCameraIndex];

    try {
      setState(() {
        _isSwitchingCamera = true;
      });
      await _activateCamera(nextCamera);
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không đổi được camera: ${error.description ?? error.code}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSwitchingCamera = false;
        });
      }
    }
  }

  Future<void> _pickFromGallery() async {
    final result = await context.pushNamed<GalleryMediaPickerResult>(
      AppRoutes.gallery,
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      _selectedMedia = XFile(result.file.path);
      _selectedMediaType = result.mediaType;
      _shouldMirrorSelectedImage = false;
      _errorMessage = null;
    });

    await _syncCameraActivity();
  }

  Future<void> _takePicture() async {
    final controller = _cameraController;
    final initializeFuture = _initializeCameraFuture;

    if (controller == null || initializeFuture == null) {
      return;
    }

    try {
      await initializeFuture;
      final image = await controller.takePicture();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedMedia = image;
        _selectedMediaType = NoteMediaType.image;
        _shouldMirrorSelectedImage =
            controller.description.lensDirection == CameraLensDirection.front;
      });
      await _syncCameraActivity();
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Không chụp được ảnh: ${error.description ?? error.code}',
          ),
        ),
      );
    }
  }

  void _clearComposerState() {
    _selectedMedia = null;
    _selectedMediaType = null;
    _captionController.clear();
    _priceController.clear();
    _shouldMirrorSelectedImage = false;
    _editingNote = null;
  }

  void _cancelPostMode() {
    setState(_clearComposerState);
    _captionFocusNode.unfocus();
    _priceFocusNode.unfocus();
    _syncCameraActivity();
  }

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

  void _focusCaption() {
    if (!_isPostMode) {
      return;
    }

    FocusScope.of(context).requestFocus(_captionFocusNode);
  }

  void _focusPrice() {
    if (!_isPostMode) {
      return;
    }

    FocusScope.of(context).requestFocus(_priceFocusNode);
  }

  Future<void> _openCropEditor() async {
    if (!_isPostMode) {
      return;
    }

    FocusScope.of(context).unfocus();

    if (_isSelectedVideo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Video hiện chưa hỗ trợ crop.')),
      );
      return;
    }

    final selectedMedia = _selectedMedia;
    if (selectedMedia == null) {
      return;
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final croppedImage = await ImageCropper().cropImage(
      sourcePath: selectedMedia.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Chọn vùng hiển thị',
          toolbarColor: theme.scaffoldBackgroundColor,
          toolbarWidgetColor: theme.colorScheme.onSurface,
          backgroundColor: colorScheme.surface,
          activeControlsWidgetColor: theme.colorScheme.primary,
          dimmedLayerColor: colorScheme.scrim.withValues(alpha: 0.72),
          cropFrameColor: theme.colorScheme.primary,
          cropGridColor: colorScheme.onSurface.withValues(alpha: 0.22),
          showCropGrid: true,
          hideBottomControls: false,
          lockAspectRatio: true,
          initAspectRatio: CropAspectRatioPreset.square,
        ),
        IOSUiSettings(
          title: 'Chọn vùng hiển thị',
          doneButtonTitle: 'Xong',
          cancelButtonTitle: 'Hủy',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
          rotateButtonsHidden: true,
          resetButtonHidden: false,
        ),
      ],
    );

    if (!mounted || croppedImage == null) {
      return;
    }

    setState(() {
      _selectedMedia = XFile(croppedImage.path);
      _selectedMediaType = NoteMediaType.image;
      _shouldMirrorSelectedImage = false;
    });
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

    final action = await showModalBottomSheet<_StoredNoteAction>(
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

    final confirmed = await showDialog<bool>(
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

  void _handleMediaOverlayInteractionChanged(bool isInteracting) {
    if (_isLockingPageSwipe == isInteracting || !mounted) {
      return;
    }

    setState(() {
      _isLockingPageSwipe = isInteracting;
    });
  }

  Widget _buildPreviewSurface(ThemeData theme) {
    if (_selectedMedia != null && _selectedMediaType != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(48),
        ),
        child: NoteMediaView(
          mediaPath: _selectedMedia!.path,
          mediaType: _selectedMediaType!,
          borderRadius: BorderRadius.circular(48),
          isActive: _isOnComposePage,
          mirrorHorizontally: _shouldMirrorSelectedImage,
          autoplay: _selectedMediaType!.isVideo,
          allowTapToToggle: _selectedMediaType!.isVideo,
          onOverlayInteractionChanged: _handleMediaOverlayInteractionChanged,
          errorLabel: 'Không đọc được media vừa chọn.',
        ),
      );
    }

    final initializeFuture = _initializeCameraFuture;
    final controller = _cameraController;

    if (_errorMessage != null) {
      return _buildStatusCard(theme, _errorMessage!);
    }

    if (initializeFuture == null || controller == null) {
      return _buildLoadingCard(theme);
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoadingCard(theme);
        }

        if (snapshot.hasError) {
          return _buildStatusCard(
            theme,
            'Không thể hiển thị camera: ${snapshot.error}',
          );
        }

        return DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(48),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(48),
            child: Builder(
              builder: (context) {
                final previewSize = controller.value.previewSize;
                if (previewSize == null) {
                  return _buildLoadingCard(theme);
                }

                return SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: previewSize.height,
                      height: previewSize.width,
                      child: CameraPreview(controller),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingCard(ThemeData theme) {
    return NoteSkeletonBox(
      borderRadius: BorderRadius.circular(48),
      baseColor: theme.colorScheme.surfaceContainerHighest,
      highlightColor: theme.colorScheme.surfaceContainerHigh,
    );
  }

  Widget _buildStatusCard(ThemeData theme, String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(48),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStoredNotePage(ThemeData theme, NoteEntry note, int noteIndex) {
    final colorScheme = theme.colorScheme;
    final isActive = !_isOnComposePage && _currentFeedIndex == noteIndex;

    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: NoteFeedView(
              note: note,
              isActive: isActive,
              onOverlayInteractionChanged:
                  _handleMediaOverlayInteractionChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_currentFeedIndex + 1}/${_notes.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    NoteBottomCircleActionButton(
                      icon: LucideIcons.grid2x2,
                      onPressed: _openCatalogPage,
                      color: colorScheme.primary,
                      tooltip: 'Mở thư viện ghi chú',
                    ),
                    NoteCaptureButton(
                      onPressed: _jumpToComposePage,
                      color: colorScheme.primary,
                      iconColor: colorScheme.onPrimary,
                      icon: LucideIcons.camera,
                      size: 82,
                      iconSize: 32,
                    ),
                    NoteBottomCircleActionButton(
                      icon: LucideIcons.circleEllipsis,
                      onPressed: _isRunningNoteAction
                          ? null
                          : _openCurrentNoteActions,
                      color: colorScheme.primary,
                      tooltip: 'Thao tác ghi chú',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleVerticalPageChanged(int pageIndex) {
    setState(() {
      _currentPageIndex = pageIndex;
      if (pageIndex > 0) {
        _currentFeedIndex = _normalizeFeedIndex(pageIndex - 1, _notes.length);
      }
    });

    _syncCameraActivity();
  }

  Future<void> _syncCameraActivity() async {
    if (_shouldKeepCameraActive) {
      await _ensureCameraReady();
      return;
    }

    final controller = _cameraController;
    if (controller == null && _initializeCameraFuture == null) {
      return;
    }

    if (mounted) {
      setState(() {
        _cameraController = null;
        _initializeCameraFuture = null;
      });
    }

    await controller?.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycleState = state;

    if (state == AppLifecycleState.resumed) {
      _syncCameraActivity();
      unawaited(_syncEngagement());
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _syncCameraActivity();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _captionController.dispose();
    _captionFocusNode.dispose();
    _priceController.dispose();
    _priceFocusNode.dispose();
    _feedPageController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalPages = _notes.length + 1;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: HomeHeader(
        onSettingsPressed: () => _openSettingsScreen(),
        streakCount: _streakCount,
      ),
      body: _isLoadingNotes
          ? const _HomeScreenSkeleton()
          : PageView.builder(
              controller: _feedPageController,
              scrollDirection: Axis.vertical,
              physics: _isLockingPageSwipe
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
              itemCount: totalPages,
              onPageChanged: _handleVerticalPageChanged,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return NoteComposeBody(
                    preview: _buildPreviewSurface(theme),
                    isPostMode: _isPostMode,
                    isEditingMode: _isEditingMode,
                    hasStoredNotes: _hasStoredNotes,
                    isSavingNote: _isSavingNote,
                    isSwitchingCamera: _isSwitchingCamera,
                    isSelectedMediaVideo: _isSelectedVideo,
                    captionController: _captionController,
                    captionFocusNode: _captionFocusNode,
                    priceController: _priceController,
                    priceFocusNode: _priceFocusNode,
                    onFocusCaption: _focusCaption,
                    onFocusPrice: _focusPrice,
                    onCancelOrPick: _isPostMode
                        ? (_isEditingMode ? _pickFromGallery : _cancelPostMode)
                        : _pickFromGallery,
                    onCancelEditing: _cancelPostMode,
                    onCaptureOrSubmit: _isPostMode ? _submitPost : _takePicture,
                    onCropOrSwitch: _isPostMode
                        ? _openCropEditor
                        : _switchCamera,
                    onOpenFirstNote: _jumpToFirstNotePage,
                  );
                }

                final note = _notes[index - 1];
                return _buildStoredNotePage(theme, note, index - 1);
              },
            ),
    );
  }
}

enum _StoredNoteAction { edit, delete, download, share }

class _HomeScreenSkeleton extends StatelessWidget {
  const _HomeScreenSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  NoteSkeletonBox(borderRadius: BorderRadius.circular(48)),
                  const SizedBox(height: 24),
                  NoteSkeletonBox(
                    width: 148,
                    height: 44,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 12),
                  NoteSkeletonBox(
                    width: 116,
                    height: 44,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: const [
                NoteSkeletonBox(width: 52, height: 52, shape: BoxShape.circle),
                NoteSkeletonBox(width: 82, height: 82, shape: BoxShape.circle),
                NoteSkeletonBox(width: 52, height: 52, shape: BoxShape.circle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
