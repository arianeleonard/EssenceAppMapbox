import 'package:json_annotation/json_annotation.dart';

part 'station_price_data.g.dart';

@JsonSerializable()
final class StationPriceData {
  @JsonKey(name: 'GasType')
  final String? gasType;

  @JsonKey(name: 'Price')
  final String? price;

  @JsonKey(name: 'IsAvailable')
  final bool isAvailable;

  const StationPriceData({
    required this.gasType,
    required this.price,
    required this.isAvailable,
  });

  factory StationPriceData.fromJson(Map<String, dynamic> json) =>
      _$StationPriceDataFromJson(json);

  Map<String, dynamic> toJson() => _$StationPriceDataToJson(this);
}
