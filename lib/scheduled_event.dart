class ScheduledEvent {
  const ScheduledEvent({
    required this.id,
    required this.monthAbbrev,
    required this.day,
    required this.title,
    required this.isOnline,
    required this.timeDisplay,
    required this.familiesSignedUp,
  });

  final String id;
  final String monthAbbrev;
  final String day;
  final String title;
  final bool isOnline;
  final String timeDisplay;
  final int familiesSignedUp;
}
