import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bursa_zemin/features/quakes/data/afad_client.dart';

void main() {
  group('AfadClient unit tests', () {
    final sampleJson =
        File('test/fixtures/afad_sample.json').readAsStringSync();

    test('successful request fetches and parses quakes list', () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        expect(request.url.queryParameters['minlat'], equals('39.0'));
        expect(request.url.queryParameters['maxlat'], equals('41.0'));
        expect(request.url.queryParameters['minmag'], equals('2.0'));
        return http.Response(sampleJson, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final client = AfadClient(httpClient: mockClient);
      final quakes = await client.fetchEarthquakes();

      expect(quakes.length, equals(62));
      expect(requestCount, equals(1));
      expect(client.cachedQuakes?.length, equals(62));
    });

    test('serves subsequent requests from 10-minute cache without re-fetching',
        () async {
      int requestCount = 0;
      final mockClient = MockClient((request) async {
        requestCount++;
        return http.Response(sampleJson, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      final client = AfadClient(httpClient: mockClient);

      // First call -> hits mock client
      final firstResult = await client.fetchEarthquakes();
      expect(firstResult.length, equals(62));
      expect(requestCount, equals(1));

      // Second call -> returns cached quakes
      final secondResult = await client.fetchEarthquakes();
      expect(secondResult.length, equals(62));
      expect(requestCount, equals(1),
          reason: 'Should return cached result without new HTTP request');

      // Call with forceRefresh = true -> re-fetches
      final refreshedResult = await client.fetchEarthquakes(forceRefresh: true);
      expect(refreshedResult.length, equals(62));
      expect(requestCount, equals(2),
          reason: 'forceRefresh should bypass cache');
    });

    test('throws AfadTimeoutException when request times out', () async {
      final mockClient = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(sampleJson, 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });

      // Client with tiny timeout
      final client = AfadClient(
        httpClient: mockClient,
        timeout: const Duration(milliseconds: 50),
      );

      expect(
        () => client.fetchEarthquakes(),
        throwsA(isA<AfadTimeoutException>()),
      );
    });

    test('throws AfadHttpException on HTTP 500 server error', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final client = AfadClient(httpClient: mockClient);

      expect(
        () => client.fetchEarthquakes(),
        throwsA(isA<AfadHttpException>().having(
          (e) => e.statusCode,
          'statusCode',
          equals(500),
        )),
      );
    });

    test('throws AfadParseException on malformed response body', () async {
      final mockClient = MockClient((request) async {
        return http.Response('{ "not": "a list" }', 200);
      });

      final client = AfadClient(httpClient: mockClient);

      expect(
        () => client.fetchEarthquakes(),
        throwsA(isA<AfadParseException>()),
      );
    });

    test('throws AfadNetworkException on client network error', () async {
      final mockClient = MockClient((request) async {
        throw http.ClientException('Connection reset by peer');
      });

      final client = AfadClient(httpClient: mockClient);

      expect(
        () => client.fetchEarthquakes(),
        throwsA(isA<AfadNetworkException>()),
      );
    });
  });
}
