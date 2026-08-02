const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats a date as "Jul 17, 2026" without pulling in the intl package.
String formatDate(DateTime date) => '${_months[date.month - 1]} ${date.day}, ${date.year}';
