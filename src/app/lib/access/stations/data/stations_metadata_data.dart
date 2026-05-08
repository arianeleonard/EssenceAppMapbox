import 'package:json_annotation/json_annotation.dart';

part 'stations_metadata_data.g.dart';

@JsonSerializable()
final class StationsMetadataData {
  @JsonKey(name: 'generated_at')
  final String generatedAt;

  @JsonKey(name: 'excel_url')
  final String excelUrl;

  @JsonKey(name: 'total_stations')
  final int totalStations;

  @JsonKey(name: 'excel_size_bytes')
  final int excelSizeBytes;

  const StationsMetadataData({
    required this.generatedAt,
    required this.excelUrl,
    required this.totalStations,
    required this.excelSizeBytes,
  });

  factory StationsMetadataData.fromJson(Map<String, dynamic> json) =>
      _$StationsMetadataDataFromJson(json);

  Map<String, dynamic> toJson() => _$StationsMetadataDataToJson(this);
}
