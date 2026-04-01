import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hnsnap/common/utils/note_formatters.dart';
import 'package:hnsnap/features/notes/domain/entities/note_query.dart';
import 'package:hnsnap/features/notes/domain/repositories/notes_repository.dart';

class NoteFilterScreen extends StatefulWidget {
  const NoteFilterScreen({
    super.key,
    required this.initialQuery,
    required this.notesRepository,
  });

  final NoteQuery initialQuery;
  final NotesRepository notesRepository;

  @override
  State<NoteFilterScreen> createState() => _NoteFilterScreenState();
}

class _NoteFilterScreenState extends State<NoteFilterScreen> {
  // Trạng thái bộ lọc
  late NoteDateFilterScope _scope;
  late NoteAmountFilter _amountFilter;
  late DateTime? _anchorDate;
  late final TextEditingController _keywordController;

  // Trạng thái Calendar
  late DateTime _currentMonthDate;
  Map<DateTime, List<String>> _dailyImages = {};
  bool _isLoadingImages = false;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialQuery.scope;
    _amountFilter = widget.initialQuery.amountFilter;
    _anchorDate = widget.initialQuery.anchorDate;
    _keywordController = TextEditingController(
      text: widget.initialQuery.keyword,
    );

    final baseDate = _anchorDate ?? DateTime.now();
    _currentMonthDate = DateTime(baseDate.year, baseDate.month);

    _loadMonthlyImages();
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  Future<void> _loadMonthlyImages() async {
    setState(() {
      _isLoadingImages = true;
    });

    try {
      final query = NoteQuery(
        scope: NoteDateFilterScope.month,
        anchorDate: _currentMonthDate,
      );
      final notes = await widget.notesRepository.listNotes(query);

      if (!mounted) return;

      final Map<DateTime, List<String>> dailyMap = {};
      for (final note in notes) {
        if (note.mediaType.isImage) {
          final day = DateTime(
            note.createdAt.year,
            note.createdAt.month,
            note.createdAt.day,
          );
          dailyMap.putIfAbsent(day, () => []).add(note.mediaPath);
        }
      }

      setState(() {
        _dailyImages = dailyMap;
        _isLoadingImages = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingImages = false;
        });
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonthDate = DateTime(
        _currentMonthDate.year,
        _currentMonthDate.month + offset,
      );

      if (_scope == NoteDateFilterScope.month) {
        _anchorDate = _currentMonthDate;
      } else if (_scope == NoteDateFilterScope.year) {
        _anchorDate = _currentMonthDate;
      }
    });
    _loadMonthlyImages();
  }

  void _onDaySelected(DateTime date) {
    setState(() {
      if (_scope == NoteDateFilterScope.day &&
          _anchorDate != null &&
          _anchorDate!.isAtSameMomentAs(date)) {
        // Toggle selected day off -> select month level
        _scope = NoteDateFilterScope.month;
        _anchorDate = _currentMonthDate;
      } else {
        _scope = NoteDateFilterScope.day;
        _anchorDate = date;
      }
    });
  }

  int get _daysInMonth =>
      DateUtils.getDaysInMonth(_currentMonthDate.year, _currentMonthDate.month);

  int get _firstDayOffset {
    final firstDay = DateTime(
      _currentMonthDate.year,
      _currentMonthDate.month,
      1,
    );
    // Chủ nhật = 0, Thứ 2 = 1
    // Trong Flutter, weekday của Thứ 2 = 1, Chủ nhật = 7.
    // Đổi lại sao cho Chủ nhật = 0
    return firstDay.weekday % 7;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lọc thư viện ghi chú'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(const NoteQuery());
            },
            child: const Text('Đặt lại'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calendar Title
                    Text('Theo thời gian', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _buildCalendarHeader(),
                    _buildWeekDays(context),
                    _buildCalendarGrid(),

                    const SizedBox(height: 24),
                    Text('Theo dấu tiền', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    SegmentedButton<NoteAmountFilter>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: NoteAmountFilter.all,
                          label: Text('Tất cả'),
                        ),
                        ButtonSegment(
                          value: NoteAmountFilter.income,
                          label: Text('Tiền vào'),
                        ),
                        ButtonSegment(
                          value: NoteAmountFilter.expense,
                          label: Text('Tiền ra'),
                        ),
                      ],
                      selected: {_amountFilter},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _amountFilter = selection.first;
                        });
                      },
                    ),

                    const SizedBox(height: 24),
                    Text('Từ khóa', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _keywordController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        hintText: 'Lọc theo ghi chú hoặc kiểu giao dịch',
                        prefixIcon: Icon(Icons.search_rounded),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            // Nút áp dụng
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop(
                      NoteQuery(
                        scope: _scope,
                        anchorDate: _scope == NoteDateFilterScope.all
                            ? null
                            : (_anchorDate ?? DateTime.now()),
                        amountFilter: _amountFilter,
                        keyword: _keywordController.text.trim(),
                      ),
                    );
                  },
                  child: Text(
                    _scope == NoteDateFilterScope.all
                        ? 'Áp dụng toàn bộ thời gian'
                        : 'Áp dụng: ${describeDateSelection(_scope, _anchorDate)}',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _changeMonth(-1),
        ),
        Text(
          'Tháng ${_currentMonthDate.month}, ${_currentMonthDate.year}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () => _changeMonth(1),
        ),
      ],
    );
  }

  Widget _buildWeekDays(BuildContext context) {
    final days = ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: days
            .map(
              (day) => Text(
                day,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
        crossAxisSpacing: 6.0,
        mainAxisSpacing: 6.0,
      ),
      itemCount: _daysInMonth + _firstDayOffset,
      itemBuilder: (context, index) {
        if (index < _firstDayOffset) {
          return const SizedBox.shrink();
        }

        final day = index - _firstDayOffset + 1;
        final date = DateTime(
          _currentMonthDate.year,
          _currentMonthDate.month,
          day,
        );
        final images = _dailyImages[date] ?? [];

        final isSelected =
            _scope == NoteDateFilterScope.day &&
            _anchorDate != null &&
            _anchorDate!.year == date.year &&
            _anchorDate!.month == date.month &&
            _anchorDate!.day == date.day;

        return GestureDetector(
          onTap: () => _onDaySelected(date),
          child: Container(
            decoration: BoxDecoration(
              color: images.isEmpty
                  ? Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (images.isEmpty
                          ? Theme.of(context).colorScheme.outlineVariant
                          : Colors.transparent),
                width: isSelected ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildDayBackground(images),
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: images.isNotEmpty
                          ? Colors.black54
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: images.isNotEmpty
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                if (images.length > 2)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+${images.length - 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDayBackground(List<String> images) {
    if (images.isEmpty) {
      return const SizedBox.shrink();
    }

    if (images.length == 1) {
      return _buildImage(images[0]);
    }

    if (images.length == 2) {
      return Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: FractionallySizedBox(
              widthFactor: 0.7,
              heightFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildImage(images[0]),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: FractionallySizedBox(
              widthFactor: 0.7,
              heightFactor: 0.7,
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                clipBehavior: Clip.antiAlias,
                child: _buildImage(images[1]),
              ),
            ),
          ),
        ],
      );
    }

    return _buildImage(images[0]);
  }

  Widget _buildImage(String path) {
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: const Icon(
          Icons.image_not_supported,
          size: 16,
          color: Colors.grey,
        ),
      ),
    );
  }
}
