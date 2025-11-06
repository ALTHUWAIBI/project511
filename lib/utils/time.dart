/// Time utilities for SQLite (milliseconds since epoch)
int nowMillis() {
  return DateTime.now().toUtc().millisecondsSinceEpoch;
}

/// Safe date conversion - handles Timestamp, int (epoch ms), String, DateTime
DateTime? safeDateFromDynamic(dynamic timestamp) {
  if (timestamp == null) return null;
  if (timestamp is DateTime) return timestamp;
  if (timestamp is int) {
    // Assume milliseconds since epoch
    return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
  }
  if (timestamp is String) {
    try {
      return DateTime.parse(timestamp);
    } catch (_) {
      return null;
    }
  }
  // Handle Firestore Timestamp shim if available
  try {
    if (timestamp.toString().contains('Timestamp')) {
      // Try to extract milliseconds
      final str = timestamp.toString();
      final match = RegExp(r'(\d+)').firstMatch(str);
      if (match != null) {
        final ms = int.tryParse(match.group(1)!);
        if (ms != null) {
          return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        }
      }
    }
  } catch (_) {
    // Ignore
  }
  return null;
}
