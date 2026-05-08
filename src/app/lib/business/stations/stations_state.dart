import 'package:app/business/stations/fuel_type.dart';
import 'package:app/business/stations/station.dart';
import 'package:app/business/stations/station_filter.dart';

/// Sealed state for the stations stream.
sealed class StationsState {}

/// Stations are being loaded for the first time.
final class StationsStateLoading extends StationsState {}

/// Stations have been loaded and are ready.
final class StationsStateLoaded extends StationsState {
  final List<Station> allStations;
  final List<Station> filteredStations;
  final StationFilter activeFilter;
  final Map<FuelType, ({double min, double max})> priceRangeByFuelType;
  final DateTime generatedAt;

  StationsStateLoaded({
    required this.allStations,
    required this.filteredStations,
    required this.activeFilter,
    required this.priceRangeByFuelType,
    required this.generatedAt,
  });
}

/// An error occurred while loading stations.
final class StationsStateError extends StationsState {
  final Object error;
  StationsStateError(this.error);
}
