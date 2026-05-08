import 'dart:convert';

import 'package:app/access/stations/data/station_feature_data.dart';
import 'package:app/access/stations/data/stations_geojson_data.dart';
import 'package:flutter_test/flutter_test.dart';

const _singleFeatureJson = '''
{
  "type": "FeatureCollection",
  "metadata": {
    "generated_at": "2026-05-04T15:50:02.245795Z",
    "excel_url": "/data/stations-mock.xlsx",
    "total_stations": 1,
    "excel_size_bytes": 1024
  },
  "features": [
    {
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [-73.5673, 45.5017]
      },
      "properties": {
        "Name": "Station Shell Test",
        "brand": "Shell",
        "Status": "En opération",
        "Address": "1234 rue Sainte-Catherine, Montréal",
        "PostalCode": "H3A 1A1",
        "Region": "Montréal",
        "Prices": [
          { "GasType": "Régulier", "Price": "172.9¢", "IsAvailable": true },
          { "GasType": "Super", "Price": "198.9¢", "IsAvailable": true },
          { "GasType": "Diesel", "Price": "210.9¢", "IsAvailable": false }
        ]
      }
    }
  ]
}
''';

void main() {
  group('StationsGeoJsonData deserialization', () {
    late StationsGeoJsonData data;

    setUp(() {
      final map = jsonDecode(_singleFeatureJson) as Map<String, dynamic>;
      data = StationsGeoJsonData.fromJson(map);
    });

    test('parses metadata', () {
      expect(data.metadata.totalStations, 1);
      expect(data.metadata.generatedAt, '2026-05-04T15:50:02.245795Z');
    });

    test('parses feature count', () {
      expect(data.features, hasLength(1));
    });

    test('parses station name', () {
      expect(data.features.first.properties.name, 'Station Shell Test');
    });

    test('parses brand', () {
      expect(data.features.first.properties.brand, 'Shell');
    });

    test('parses address', () {
      expect(
        data.features.first.properties.address,
        '1234 rue Sainte-Catherine, Montréal',
      );
    });

    test('parses coordinates', () {
      final geometry = data.features.first.geometry;
      expect(geometry.longitude, closeTo(-73.5673, 0.0001));
      expect(geometry.latitude, closeTo(45.5017, 0.0001));
    });

    test('parses prices', () {
      final prices = data.features.first.properties.prices;
      expect(prices, hasLength(3));
      expect(prices[0].gasType, 'Régulier');
      expect(prices[0].price, '172.9¢');
      expect(prices[0].isAvailable, isTrue);
      expect(prices[2].isAvailable, isFalse);
    });
  });

  group('StationFeatureData deserialization', () {
    test('fromJson round-trips correctly', () {
      final map = jsonDecode(_singleFeatureJson) as Map<String, dynamic>;
      final geoJson = StationsGeoJsonData.fromJson(map);
      final feature = geoJson.features.first;
      final roundTripped = StationFeatureData.fromJson(feature.toJson());
      expect(roundTripped.properties.name, feature.properties.name);
      expect(roundTripped.geometry.longitude, feature.geometry.longitude);
    });
  });
}
