/// Volunteer driver ZIP coverage loaded from Firestore (`config/transport_coverage`).
class TransportCoverageConfig {
  const TransportCoverageConfig({
    required this.regionName,
    required this.zipPrefixes,
    this.zipCodes = const [],
  });

  final String regionName;
  final List<String> zipPrefixes;
  final List<String> zipCodes;

  static const defaultBayArea = TransportCoverageConfig(
    regionName: 'San Francisco Bay Area',
    zipPrefixes: [
      '940',
      '941',
      '943',
      '944',
      '945',
      '950',
      '951',
    ],
  );

  factory TransportCoverageConfig.fromMap(Map<String, dynamic> data) {
    final prefixes = data['zipPrefixes'];
    final codes = data['zipCodes'];
    return TransportCoverageConfig(
      regionName: (data['regionName'] as String?)?.trim().isNotEmpty == true
          ? (data['regionName'] as String).trim()
          : defaultBayArea.regionName,
      zipPrefixes: prefixes is List
          ? prefixes
              .map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList()
          : defaultBayArea.zipPrefixes,
      zipCodes: codes is List
          ? codes
              .map((value) => normalizeZip(value.toString()))
              .where((value) => value.length == 5)
              .toList()
          : const [],
    );
  }

  static String normalizeZip(String input) =>
      input.replaceAll(RegExp(r'\D'), '');

  static bool isValidZip(String input) => normalizeZip(input).length == 5;

  bool isCovered(String input) {
    final zip = normalizeZip(input);
    if (zip.length != 5) return false;
    if (zipCodes.contains(zip)) return true;
    if (zipPrefixes.isEmpty) return false;
    return zipPrefixes.any(zip.startsWith);
  }
}

/// Back-compat helpers used by ride scheduling UI.
class VolunteerCoverage {
  VolunteerCoverage._();

  static String normalizeZip(String input) =>
      TransportCoverageConfig.normalizeZip(input);

  static bool isValidZip(String input) =>
      TransportCoverageConfig.isValidZip(input);

  static bool isCovered(String input, TransportCoverageConfig config) =>
      config.isCovered(input);
}
