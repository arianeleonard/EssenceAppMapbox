import 'package:app/access/stations/data/station_geometry_data.dart';
import 'package:app/access/stations/data/station_properties_data.dart';
import 'package:json_annotation/json_annotation.dart';

part 'station_feature_data.g.dart';

@JsonSerializable()
final class StationFeatureData {
  final String type;
  final StationGeometryData geometry;
  final StationPropertiesData properties;

  const StationFeatureData({
    required this.type,
    required this.geometry,
    required this.properties,
  });

  factory StationFeatureData.fromJson(Map<String, dynamic> json) =>
      _$StationFeatureDataFromJson(json);

  Map<String, dynamic> toJson() => _$StationFeatureDataToJson(this);
}
