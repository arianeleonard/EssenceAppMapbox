import 'package:app/business/stations/fuel_price.dart';
import 'package:equatable/equatable.dart';

/// A gas station business entity.
final class Station extends Equatable {
  final String id;
  final String name;
  final String brand;
  final String status;
  final String address;
  final String postalCode;
  final String region;
  final double latitude;
  final double longitude;
  final List<FuelPrice> prices;

  const Station({
    required this.id,
    required this.name,
    required this.brand,
    required this.status,
    required this.address,
    required this.postalCode,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.prices,
  });

  /// Returns the cheapest available fuel price, or null if no prices are available.
  double? get cheapestPrice {
    final available = prices.where((p) => p.isAvailable).toList();
    if (available.isEmpty) return null;
    return available.map((p) => p.priceValue).reduce((a, b) => a < b ? a : b);
  }

  @override
  List<Object?> get props => [id];
}
