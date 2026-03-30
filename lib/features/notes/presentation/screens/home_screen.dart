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

part 'home_screen_camera.dart';
part 'home_screen_engagement.dart';
part 'home_screen_note_actions.dart';
part 'home_screen_view.dart';

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
