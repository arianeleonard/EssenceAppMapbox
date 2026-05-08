import 'package:app/access/stations/data/station_feature_data.dart';
import 'package:app/access/stations/data/stations_metadata_data.dart';
import 'package:json_annotation/json_annotation.dart';

part 'stations_geojson_data.g.dart';

@JsonSerializable()
final class StationsGeoJsonData {
  final String type;
  final StationsMetadataData metadata;
  final List<StationFeatureData> features;

  const StationsGeoJsonData({
    required this.type,
    required this.metadata,
    required this.features,
  });

  factory StationsGeoJsonData.fromJson(Map<String, dynamic> json) =>
      _$StationsGeoJsonDataFromJson(json);

  Map<String, dynamic> toJson() => _$StationsGeoJsonDataToJson(this);
}
