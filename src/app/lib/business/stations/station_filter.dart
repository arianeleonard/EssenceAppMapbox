import 'package:app/business/stations/fuel_type.dart';
import 'package:equatable/equatable.dart';

/// Immutable filter state for the stations map.
final class StationFilter extends Equatable {
  final Set<String> brands;
  final Set<FuelType> fuelTypes;
  final double? maxPrice;
  final Set<String> regions;

  const StationFilter({
    this.brands = const {},
    this.fuelTypes = const {},
    this.maxPrice,
    this.regions = const {},
  });

  /// An empty filter that matches all stations.
  static const empty = StationFilter();

  bool get isEmpty =>
      brands.isEmpty &&
      fuelTypes.isEmpty &&
      maxPrice == null &&
      regions.isEmpty;

  StationFilter copyWith({
    Set<String>? brands,
    Set<FuelType>? fuelTypes,
    double? maxPrice,
    bool clearMaxPrice = false,
    Set<String>? regions,
  }) {
    return StationFilter(
      brands: brands ?? this.brands,
      fuelTypes: fuelTypes ?? this.fuelTypes,
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      regions: regions ?? this.regions,
    );
  }

  @override
  List<Object?> get props => [brands, fuelTypes, maxPrice, regions];
}
