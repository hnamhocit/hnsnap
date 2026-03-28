import 'package:hnsnap/app/features/tabs/data/models/note_query.dart';

String formatDateTime(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(value.year, value.month, value.day);
  final difference = today.difference(target).inDays;
  final time = '${_twoDigits(value.hour)}:${_twoDigits(value.minute)}';

  if (difference == 0) {
    return 'Hôm nay $time';
  }

  if (difference == 1) {
    return 'Hôm qua $time';
  }

  return '${_twoDigits(value.day)}/${_twoDigits(value.month)}/${value.year} $time';
}

String formatAmount(double amount) {
  final absolute = amount.abs();
  final formatted = absolute % 1 == 0
      ? _formatWholeNumber(absolute.toInt())
      : _formatDecimalNumber(absolute);
  return amount >= 0 ? formatted : '-$formatted';
}

String describeDateFilter(NoteQuery query) {
  final anchor = query.anchorDate ?? DateTime.now();

  switch (query.scope) {
    case NoteDateFilterScope.year:
      return 'Năm ${anchor.year}';
    case NoteDateFilterScope.month:
      return 'Tháng ${_twoDigits(anchor.month)}/${anchor.year}';
    case NoteDateFilterScope.day:
      return 'Ngày ${_twoDigits(anchor.day)}/${_twoDigits(anchor.month)}/${anchor.year}';
    case NoteDateFilterScope.all:
      return 'Tất cả';
  }
}

String describeDateSelection(NoteDateFilterScope scope, DateTime? anchorDate) {
  final date = anchorDate ?? DateTime.now();

  switch (scope) {
    case NoteDateFilterScope.year:
      return 'Đang chọn năm ${date.year}';
    case NoteDateFilterScope.month:
      return 'Đang chọn tháng ${_twoDigits(date.month)}/${date.year}';
    case NoteDateFilterScope.day:
      return 'Đang chọn ngày ${_twoDigits(date.day)}/${_twoDigits(date.month)}/${date.year}';
    case NoteDateFilterScope.all:
      return 'Không giới hạn thời gian';
  }
}

String _formatWholeNumber(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();

  for (var index = 0; index < digits.length; index++) {
    buffer.write(digits[index]);
    final remaining = digits.length - index - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }

  return buffer.toString();
}

String _formatDecimalNumber(double value) {
  final parts = value.toStringAsFixed(2).split('.');
  final whole = _formatWholeNumber(int.parse(parts.first));
  final fraction = parts.last == '00' ? '' : '.${parts.last}';
  return '$whole$fraction';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}
