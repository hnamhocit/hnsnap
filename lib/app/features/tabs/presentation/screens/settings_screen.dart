import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:hnsnap/app/features/tabs/data/models/app_settings.dart';
import 'package:hnsnap/app/features/tabs/data/repositories/local_notes_repository.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.notesRepository});

  final LocalNotesRepository notesRepository;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppSettings? _settings;
  List<File> _backupFiles = const [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isExporting = false;
  String? _sharingBackupPath;
  String? _importingBackupPath;
  bool _shouldReloadHome = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await widget.notesRepository.getSettings();
      final backupFiles = await widget.notesRepository.listBackupFiles();

      if (!mounted) {
        return;
      }

      setState(() {
        _settings = settings;
        _backupFiles = backupFiles;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không tải được cài đặt.')));
    }
  }

  Future<void> _saveSettings() async {
    final settings = _settings;
    if (settings == null || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await widget.notesRepository.saveSettings(settings);
      await widget.notesRepository.deleteExpiredNotes();
      _shouldReloadHome = true;

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không lưu được cài đặt.')));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _exportBackup() async {
    if (_isExporting) {
      return;
    }

    setState(() {
      _isExporting = true;
    });

    try {
      final backupFile = await widget.notesRepository.exportZipBackup();
      final backupFiles = await widget.notesRepository.listBackupFiles();

      if (!mounted) {
        return;
      }

      setState(() {
        _backupFiles = backupFiles;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xuất tệp ZIP: ${backupFile.path}')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Không xuất tệp ZIP được.')));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _shareBackup(File backupFile) async {
    if (_sharingBackupPath != null) {
      return;
    }

    setState(() {
      _sharingBackupPath = backupFile.path;
    });

    try {
      await Share.shareXFiles([
        XFile(backupFile.path),
      ], text: 'Bản sao lưu ZIP của hnsnap');
    } finally {
      if (mounted) {
        setState(() {
          _sharingBackupPath = null;
        });
      }
    }
  }

  Future<void> _importBackup(File backupFile) async {
    if (_importingBackupPath != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nhập bản sao lưu này?'),
          content: const Text(
            'Dữ liệu ghi chú hiện tại sẽ bị thay bằng nội dung trong file ZIP này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Nhập'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _importingBackupPath = backupFile.path;
    });

    try {
      final importedCount = await widget.notesRepository.importBackup(
        backupFile,
      );
      _shouldReloadHome = true;
      await _loadData();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã nhập $importedCount ghi chú từ file ZIP.')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không nhập được tệp ZIP này.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _importingBackupPath = null;
        });
      }
    }
  }

  Future<void> _pickAndImportBackup() async {
    if (_importingBackupPath != null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );

    if (!mounted || result == null || result.files.isEmpty) {
      return;
    }

    final selectedPlatformFile = result.files.first;
    File? selectedFile;

    final selectedPath = selectedPlatformFile.path;
    if (selectedPath != null && selectedPath.isNotEmpty) {
      selectedFile = File(selectedPath);
    } else if (selectedPlatformFile.bytes != null) {
      final tempDirectory = await getTemporaryDirectory();
      final safeName = selectedPlatformFile.name.isEmpty
          ? 'import_backup.zip'
          : selectedPlatformFile.name;
      final tempFile = File(path.join(tempDirectory.path, safeName));
      await tempFile.writeAsBytes(selectedPlatformFile.bytes!, flush: true);
      selectedFile = tempFile;
    }

    if (selectedFile == null) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không đọc được tệp ZIP đã chọn.')),
      );
      return;
    }

    await _importBackup(selectedFile);
  }

  Future<void> _deleteBackup(File backupFile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Xóa file sao lưu này?'),
          content: Text(path.basename(backupFile.path)),
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

    if (confirmed != true) {
      return;
    }

    try {
      if (await backupFile.exists()) {
        await backupFile.delete();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _backupFiles = _backupFiles
            .where((file) => file.path != backupFile.path)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã xóa file sao lưu.')));
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không xóa được file sao lưu.')),
      );
    }
  }

  void _updateRetention(NoteRetentionPreset preset) {
    final current = _settings;
    if (current == null) {
      return;
    }

    setState(() {
      _settings = current.copyWith(
        noteRetentionDays: preset.days,
        clearRetentionDays: preset.days == null,
      );
    });
  }

  void _updateCompressImages(bool value) {
    final current = _settings;
    if (current == null) {
      return;
    }

    setState(() {
      _settings = current.copyWith(compressImages: value);
    });
  }

  void _updateCompressVideos(bool value) {
    final current = _settings;
    if (current == null) {
      return;
    }

    setState(() {
      _settings = current.copyWith(compressVideos: value);
    });
  }

  void _close() {
    Navigator.of(context).pop(_shouldReloadHome);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = _settings;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _close();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _close,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('Cài đặt'),
          actions: [
            TextButton(
              onPressed: settings == null || _isSaving ? null : _saveSettings,
              child: Text(_isSaving ? 'Đang lưu...' : 'Lưu'),
            ),
          ],
        ),
        body: _isLoading || settings == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                children: [
                  _SettingsSectionCard(
                    title: 'Tự xóa note cũ',
                    subtitle: 'Chọn thời gian giữ note trước khi app tự dọn.',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: NoteRetentionPreset.values
                          .map((preset) {
                            return ChoiceChip(
                              label: Text(preset.label),
                              selected:
                                  settings.noteRetentionDays == preset.days &&
                                  (preset.days != null ||
                                      settings.noteRetentionDays == null),
                              onSelected: (_) => _updateRetention(preset),
                            );
                          })
                          .toList(growable: false),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSectionCard(
                    title: 'Media mặc định',
                    subtitle:
                        'Ảnh đang áp dụng thật khi lưu mới. Video hiện lưu sẵn cài đặt để nối transcoding tiếp theo.',
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: settings.compressImages,
                          onChanged: _updateCompressImages,
                          title: const Text('Nén ảnh'),
                          subtitle: const Text('Mặc định bật'),
                        ),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          value: settings.compressVideos,
                          onChanged: _updateCompressVideos,
                          title: const Text('Nén video'),
                          subtitle: const Text('Mặc định bật'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsSectionCard(
                    title: 'Sao lưu ZIP',
                    subtitle:
                        'Xuất ra file zip, rồi có thể nhập lại trực tiếp từ Tệp đã tải xuống, bộ nhớ đám mây hoặc bất kỳ file ZIP nào trên máy.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                onPressed: _isExporting ? null : _exportBackup,
                                icon: Icon(
                                  _isExporting
                                      ? Icons.hourglass_top_rounded
                                      : Icons.folder_zip_outlined,
                                ),
                                label: Text(
                                  _isExporting ? 'Đang export...' : 'Xuất ZIP',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _importingBackupPath != null
                                    ? null
                                    : _pickAndImportBackup,
                                icon: const Icon(Icons.download_rounded),
                                label: const Text('Nhập ZIP'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Bản sao lưu đã xuất trên máy này',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        if (_backupFiles.isEmpty)
                          Text(
                            'Chưa có file sao lưu nào.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          )
                        else
                          ..._backupFiles.map((file) {
                            final fileName = path.basename(file.path);
                            final extension = path
                                .extension(file.path)
                                .toLowerCase();
                            final modified = file.statSync().modified;
                            final isImporting =
                                _importingBackupPath == file.path;
                            final isSharing = _sharingBackupPath == file.path;

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                title: Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${extension.toUpperCase().replaceAll('.', '')} • ${modified.day.toString().padLeft(2, '0')}/${modified.month.toString().padLeft(2, '0')}/${modified.year} ${modified.hour.toString().padLeft(2, '0')}:${modified.minute.toString().padLeft(2, '0')}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Chia sẻ file sao lưu',
                                      onPressed: isSharing
                                          ? null
                                          : () => _shareBackup(file),
                                      icon: Icon(
                                        isSharing
                                            ? Icons.hourglass_top_rounded
                                            : Icons.ios_share_rounded,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Xóa file sao lưu',
                                      onPressed: isImporting
                                          ? null
                                          : () => _deleteBackup(file),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                    if (isImporting)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _SettingsSectionCard extends StatelessWidget {
  const _SettingsSectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
