/// Formats dates for dashboard-friendly presentation.
class DateTimeFormatter {
  /// Formats the timestamp for the dashboard, or a placeholder when absent.
  static String asDashboardLabel(DateTime? value) {
    if (value == null) {
      return 'No samples yet';
    }

    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}
