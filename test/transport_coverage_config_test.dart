import 'package:care_signal/transport_coverage_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransportCoverageConfig', () {
    test('normalizes ZIP input', () {
      expect(TransportCoverageConfig.normalizeZip('94102-1234'), '941021234');
      expect(TransportCoverageConfig.normalizeZip(' 94 102 '), '94102');
    });

    test('validates five-digit ZIPs', () {
      expect(TransportCoverageConfig.isValidZip('94102'), isTrue);
      expect(TransportCoverageConfig.isValidZip('9410'), isFalse);
      expect(TransportCoverageConfig.isValidZip(''), isFalse);
    });

    test('matches Bay Area prefixes by default', () {
      const config = TransportCoverageConfig.defaultBayArea;
      expect(config.isCovered('94102'), isTrue);
      expect(config.isCovered('95112'), isTrue);
      expect(config.isCovered('90210'), isFalse);
    });

    test('matches explicit zip codes from Firestore map', () {
      final config = TransportCoverageConfig.fromMap({
        'regionName': 'Test Region',
        'zipPrefixes': ['94'],
        'zipCodes': ['90210'],
      });
      expect(config.regionName, 'Test Region');
      expect(config.isCovered('90210'), isTrue);
      expect(config.isCovered('94102'), isTrue);
      expect(config.isCovered('12345'), isFalse);
    });

    test('falls back when region name missing', () {
      final config = TransportCoverageConfig.fromMap({
        'zipPrefixes': ['940'],
      });
      expect(config.regionName, TransportCoverageConfig.defaultBayArea.regionName);
    });
  });

  group('VolunteerCoverage', () {
    test('delegates to config', () {
      const config = TransportCoverageConfig(
        regionName: 'Demo',
        zipPrefixes: ['123'],
      );
      expect(VolunteerCoverage.isCovered('12345', config), isTrue);
      expect(VolunteerCoverage.isCovered('99999', config), isFalse);
    });
  });
}
