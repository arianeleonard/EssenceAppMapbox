import 'package:app/access/stations/data/station_price_data.dart';
import 'package:json_annotation/json_annotation.dart';

part 'station_properties_data.g.dart';

@JsonSerializable()
final class StationPropertiesData {
  @JsonKey(name: 'Name')
  final String? name;

  final String? brand;

  @JsonKey(name: 'Status')
  final String? status;

  @JsonKey(name: 'Address')
  final String? address;

  @JsonKey(name: 'PostalCode')
  final String? postalCode;

  @JsonKey(name: 'Region')
  final String? region;

  @JsonKey(name: 'Prices')
  final List<StationPriceData> prices;

  const StationPropertiesData({
    required this.name,
    required this.brand,
    required this.status,
    required this.address,
    required this.postalCode,
    required this.region,
    required this.prices,
  });

  factory StationPropertiesData.fromJson(Map<String, dynamic> json) =>
      _$StationPropertiesDataFromJson(json);

  Map<String, dynamic> toJson() => _$StationPropertiesDataToJson(this);
}
