import 'package:flutter/material.dart';
import 'package:hnsnap/common/utils/note_formatters.dart';
import 'package:hnsnap/features/notes/domain/entities/note_query.dart';

class NoteFilterSheet extends StatefulWidget {
  const NoteFilterSheet({super.key, required this.initialQuery});

  final NoteQuery initialQuery;

  @override
  State<NoteFilterSheet> createState() => _NoteFilterSheetState();
}

class _NoteFilterSheetState extends State<NoteFilterSheet> {
  late NoteDateFilterScope _scope;
  late NoteAmountFilter _amountFilter;
  late DateTime? _anchorDate;
  late final TextEditingController _keywordController;

  @override
  void initState() {
    super.initState();
    _scope = widget.initialQuery.scope;
    _amountFilter = widget.initialQuery.amountFilter;
    _anchorDate = widget.initialQuery.anchorDate;
    _keywordController = TextEditingController(
      text: widget.initialQuery.keyword,
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _anchorDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _anchorDate = pickedDate;
    });
  }

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('Lọc thư viện ghi chú', style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          Text('Theo thời gian', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          SegmentedButton<NoteDateFilterScope>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: NoteDateFilterScope.all,
                label: Text('Tất cả'),
              ),
              ButtonSegment(
                value: NoteDateFilterScope.year,
                label: Text('Năm'),
              ),
              ButtonSegment(
                value: NoteDateFilterScope.month,
                label: Text('Tháng'),
              ),
              ButtonSegment(
                value: NoteDateFilterScope.day,
                label: Text('Ngày'),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: (selection) {
              setState(() {
                _scope = selection.first;
                if (_scope == NoteDateFilterScope.all) {
                  _anchorDate = null;
                } else {
                  _anchorDate ??= DateTime.now();
                }
              });
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _scope == NoteDateFilterScope.all ? null : _pickDate,
            icon: const Icon(Icons.event_rounded),
            label: Text(
              _scope == NoteDateFilterScope.all
                  ? 'Không giới hạn thời gian'
                  : describeDateSelection(_scope, _anchorDate),
            ),
          ),
          const SizedBox(height: 20),
          Text('Theo dấu tiền', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          SegmentedButton<NoteAmountFilter>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: NoteAmountFilter.all, label: Text('Tất cả')),
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
          const SizedBox(height: 20),
          Text('Từ khóa', style: theme.textTheme.titleSmall),
          const SizedBox(height: 12),
          TextField(
            controller: _keywordController,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Lọc theo ghi chú hoặc kiểu giao dịch',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop(const NoteQuery());
                  },
                  child: const Text('Đặt lại'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
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
                  child: const Text('Áp dụng'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
