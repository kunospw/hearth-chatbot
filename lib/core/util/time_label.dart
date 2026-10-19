/// Relative time labels used in chat rows: "2m ago", "3h ago", "Yesterday",
/// a weekday within the last week, otherwise "Oct 9".
String timeLabel(DateTime when, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final diff = n.difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(when.year, when.month, when.day);
  final days = today.difference(day).inDays;
  if (days == 0) return '${diff.inHours}h ago';
  if (days == 1) return 'Yesterday';
  if (days < 7) return _weekdays[when.weekday - 1];
  return '${_months[when.month - 1]} ${when.day}';
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
