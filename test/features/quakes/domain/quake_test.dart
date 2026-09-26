import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bursa_zemin/features/quakes/domain/quake.dart';

void main() {
  group('Quake model and parser tests', () {
    test(
        'parses real AFAD fixture (test/fixtures/afad_sample.json) successfully',
        () {
      final file = File('test/fixtures/afad_sample.json');
      expect(file.existsSync(), isTrue,
          reason: 'test/fixtures/afad_sample.json must exist');

      final rawJson = file.readAsStringSync();
      final quakes = Quake.parseList(rawJson);

      expect(quakes.length, equals(62),
          reason: 'Fixture should contain exactly 62 earthquake records');

      // Test first record
      final first = quakes.first;
      expect(first.eventId, equals('727025'));
      expect(first.location, equals('Sındırgı (Balıkesir)'));
      expect(first.latitude, equals(39.13517));
      expect(first.longitude, equals(28.27383));
      expect(first.depth, equals(7.0));
      expect(first.magnitude, equals(2.2));
      expect(first.type, equals('ML'));
      expect(first.country, equals('Türkiye'));
      expect(first.province, equals('Balıkesir'));
      expect(first.district, equals('Sındırgı'));
      expect(first.neighborhood, equals('Yüreğil'));
      expect(first.date, equals(DateTime.parse('2026-08-27T00:45:11')));
      expect(first.rms, equals(0.88));
      expect(first.isEventUpdate, isFalse);
      expect(first.coordinates.latitude, equals(39.13517));
      expect(first.coordinates.longitude, equals(28.27383));

      // Test a record with null neighborhood (Marmara Denizi)
      final seaQuake = quakes.firstWhere((q) => q.neighborhood == null);
      expect(seaQuake.location, contains('Marmara'));
      expect(seaQuake.neighborhood, isNull);
    });

    test('parses empty list correctly', () {
      final quakes = Quake.parseList('[]');
      expect(quakes, isEmpty);
    });

    test('throws QuakeParseException on non-list JSON', () {
      expect(
        () => Quake.parseList('{"status": 400, "message": "error"}'),
        throwsA(isA<QuakeParseException>()),
      );
    });

    test('throws QuakeParseException on invalid JSON syntax', () {
      expect(
        () => Quake.parseList('not a json string'),
        throwsA(isA<QuakeParseException>()),
      );
    });

    test('throws QuakeParseException on missing required fields', () {
      expect(
        () => Quake.fromJson({
          'eventID': '123',
          'location': 'Test',
          // missing latitude, longitude, magnitude, etc.
        }),
        throwsA(isA<QuakeParseException>()),
      );
    });

    test('handles numeric types gracefully if passed as numbers or strings',
        () {
      final quake = Quake.fromJson({
        'eventID': 999999, // int instead of string
        'location': 'Test Location',
        'latitude': 40.19, // num instead of string
        'longitude': 29.06,
        'depth': 10,
        'magnitude': 3.5,
        'type': 'Mw',
        'date': '2026-09-20T12:00:00',
      });

      expect(quake.eventId, equals('999999'));
      expect(quake.latitude, equals(40.19));
      expect(quake.longitude, equals(29.06));
      expect(quake.depth, equals(10.0));
      expect(quake.magnitude, equals(3.5));
      expect(quake.type, equals('Mw'));
    });
  });
}
