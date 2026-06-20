import 'dart:io';

/// Reads a gitignored root `.env` when running from a desktop shell (cwd = project).
Future<Map<String, String>?> loadRootOpenAiEnv() async {
  try {
    final file = File('.env');
    if (!file.existsSync()) return null;
    final map = <String, String>{};
    for (final raw in file.readAsLinesSync()) {
      var line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final eq = line.indexOf('=');
      if (eq <= 0) continue;
      final key = line.substring(0, eq).trim();
      var val = line.substring(eq + 1).trim();
      if (val.length >= 2) {
        if ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'"))) {
          val = val.substring(1, val.length - 1);
        }
      }
      map[key] = val;
    }
    return map.isEmpty ? null : map;
  } catch (_) {
    return null;
  }
}
