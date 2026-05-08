import 'dart:convert';

import 'package:app/access/stations/data/stations_geojson_data.dart';
import 'package:app/access/stations/stations_repository.dart';

/// Mocked implementation of [StationsRepository] for use in development.
final class StationsMockedRepository implements StationsRepository {
  static const _mockJson = '''
{
  "type": "FeatureCollection",
  "metadata": {
    "generated_at": "2026-05-04T12:00:00.000000Z",
    "excel_url": "/data/stations-mock.xlsx",
    "total_stations": 5,
    "excel_size_bytes": 1024
  },
  "features": [
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [-73.5673, 45.5017] },
      "properties": {
        "Name": "Station Shell Montréal",
        "brand": "Shell",
        "Status": "En opération",
        "Address": "1234 rue Sainte-Catherine, Montréal",
        "PostalCode": "H3A 1A1",
        "Region": "Montréal",
        "Prices": [
          { "GasType": "Régulier", "Price": "172.9¢", "IsAvailable": true },
          { "GasType": "Super", "Price": "198.9¢", "IsAvailable": true },
          { "GasType": "Diesel", "Price": "210.9¢", "IsAvailable": true }
        ]
      }
    },
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [-73.5800, 45.5100] },
      "properties": {
        "Name": "Petro-Canada Centre-ville",
        "brand": "Petro-Canada",
        "Status": "En opération",
        "Address": "500 boul. René-Lévesque O., Montréal",
        "PostalCode": "H2Z 1A7",
        "Region": "Montréal",
        "Prices": [
          { "GasType": "Régulier", "Price": "169.9¢", "IsAvailable": true },
          { "GasType": "Super", "Price": "195.9¢", "IsAvailable": true },
          { "GasType": "Diesel", "Price": "207.9¢", "IsAvailable": false }
        ]
      }
    },
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [-73.5500, 45.4900] },
      "properties": {
        "Name": "Ultramar Vieux-Montréal",
        "brand": "Ultramar",
        "Status": "En opération",
        "Address": "100 rue McGill, Montréal",
        "PostalCode": "H2Y 2E5",
        "Region": "Montréal",
        "Prices": [
          { "GasType": "Régulier", "Price": "175.4¢", "IsAvailable": true },
          { "GasType": "Super", "Price": "201.4¢", "IsAvailable": true },
          { "GasType": "Diesel", "Price": "215.4¢", "IsAvailable": true }
        ]
      }
    },
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [-73.6200, 45.5200] },
      "properties": {
        "Name": "Esso NDG",
        "brand": "Esso",
        "Status": "En opération",
        "Address": "4500 av. Notre-Dame-de-Grâce, Montréal",
        "PostalCode": "H4B 1T1",
        "Region": "Montréal",
        "Prices": [
          { "GasType": "Régulier", "Price": "170.4¢", "IsAvailable": true },
          { "GasType": "Super", "Price": "196.4¢", "IsAvailable": true },
          { "GasType": "Diesel", "Price": "208.4¢", "IsAvailable": true }
        ]
      }
    },
    {
      "type": "Feature",
      "geometry": { "type": "Point", "coordinates": [-73.5400, 45.5500] },
      "properties": {
        "Name": "Couche-Tard Plateau",
        "brand": "Couche-Tard",
        "Status": "En opération",
        "Address": "300 av. du Mont-Royal E., Montréal",
        "PostalCode": "H2T 1P9",
        "Region": "Montréal",
        "Prices": [
          { "GasType": "Régulier", "Price": "168.9¢", "IsAvailable": true },
          { "GasType": "Super", "Price": "193.9¢", "IsAvailable": false },
          { "GasType": "Diesel", "Price": "205.9¢", "IsAvailable": true }
        ]
      }
    }
  ]
}
''';

  @override
  Future<StationsGeoJsonData> getStations() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final jsonMap = jsonDecode(_mockJson) as Map<String, dynamic>;
    return StationsGeoJsonData.fromJson(jsonMap);
  }
}
