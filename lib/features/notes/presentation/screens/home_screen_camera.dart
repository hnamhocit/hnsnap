// ignore_for_file: invalid_use_of_protected_member

part of 'home_screen.dart';

extension on _HomeScreenState {
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

  void _handleMediaOverlayInteractionChanged(bool isInteracting) {
    if (_isLockingPageSwipe == isInteracting || !mounted) {
      return;
    }

    setState(() {
      _isLockingPageSwipe = isInteracting;
    });
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
}
