import 'package:json_annotation/json_annotation.dart';

part 'station_geometry_data.g.dart';

@JsonSerializable()
final class StationGeometryData {
  final String type;
  final List<double> coordinates;

  const StationGeometryData({required this.type, required this.coordinates});

  double get longitude => coordinates[0];
  double get latitude => coordinates[1];

  factory StationGeometryData.fromJson(Map<String, dynamic> json) =>
      _$StationGeometryDataFromJson(json);

  Map<String, dynamic> toJson() => _$StationGeometryDataToJson(this);
}
