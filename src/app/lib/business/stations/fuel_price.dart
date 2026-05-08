import 'package:app/business/stations/fuel_type.dart';
import 'package:equatable/equatable.dart';

/// A fuel price entry for a specific [FuelType].
final class FuelPrice extends Equatable {
  final FuelType fuelType;
  final double priceValue;
  final bool isAvailable;

  const FuelPrice({
    required this.fuelType,
    required this.priceValue,
    required this.isAvailable,
  });

  /// Parses a price string like "184.9¢" into a [double].
  static double parsePrice(String raw) {
    return double.parse(raw.replaceAll('¢', '').trim());
  }

  @override
  List<Object?> get props => [fuelType, priceValue, isAvailable];
}
