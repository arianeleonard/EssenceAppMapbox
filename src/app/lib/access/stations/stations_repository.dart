import 'dart:convert';
import 'dart:io';

import 'package:app/access/stations/data/stations_geojson_data.dart';
import 'package:dio/dio.dart';

/// Interface for the stations repository.
abstract interface class StationsRepository {
  factory StationsRepository(Dio dio, {required String baseUrl}) =
      _StationsRepository;

  /// Fetches all stations from the GeoJSON endpoint.
  Future<StationsGeoJsonData> getStations();
}

/// Implementation of [StationsRepository].
final class _StationsRepository implements StationsRepository {
  final Dio _dio;
  final String _baseUrl;

  _StationsRepository(this._dio, {required String baseUrl})
    : _baseUrl = baseUrl;

  @override
  Future<StationsGeoJsonData> getStations() async {
    final response = await _dio.get<List<int>>(
      '$_baseUrl/stations.geojson.gz',
      options: Options(responseType: ResponseType.bytes),
    );

    final bytes = response.data!;
    final decompressed = GZipCodec().decode(bytes);
    final jsonString = utf8.decode(decompressed);
    final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;

    return StationsGeoJsonData.fromJson(jsonMap);
  }
}
