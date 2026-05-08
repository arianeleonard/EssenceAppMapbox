import 'dart:async';

import 'package:app/access/stations/data/station_feature_data.dart';
import 'package:app/access/stations/stations_repository.dart';
import 'package:app/business/stations/fuel_price.dart';
import 'package:app/business/stations/fuel_type.dart';
import 'package:app/business/stations/station.dart';
import 'package:app/business/stations/station_filter.dart';
import 'package:app/business/stations/stations_state.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';

/// Interface for the stations service.
abstract interface class StationsService implements Disposable {
  factory StationsService(
    StationsRepository stationsRepository,
    Logger logger,
  ) = _StationsService;

  /// Stream of [StationsState].
  Stream<StationsState> get stateStream;

  /// Load (or reload) all stations from the API.
  Future<void> loadStations();

  /// Apply a filter to the currently loaded stations.
  void applyFilter(StationFilter filter);

  /// The currently active filter.
  StationFilter get activeFilter;
}

/// Implementation of [StationsService].
final class _StationsService implements StationsService {
  final StationsRepository _repository;
  final Logger _logger;

  final BehaviorSubject<StationsState> _stateSubject = BehaviorSubject.seeded(
    StationsStateLoading(),
  );

  List<Station> _allStations = [];
  Map<FuelType, ({double min, double max})> _priceRangeByFuelType = {};
  DateTime _generatedAt = DateTime.now();
  StationFilter _activeFilter = const StationFilter(
    fuelTypes: {FuelType.regulier},
  );

  _StationsService(this._repository, this._logger) {
    loadStations();
  }

  @override
  Stream<StationsState> get stateStream => _stateSubject.stream;

  @override
  StationFilter get activeFilter => _activeFilter;

  @override
  Future<void> loadStations() async {
    _stateSubject.add(StationsStateLoading());
    try {
      final geoJsonData = await _repository.getStations();

      final stations = await compute(_parseFeatures, geoJsonData.features);

      _allStations = stations;
      _priceRangeByFuelType = _computePriceRanges(stations);
      _generatedAt = DateTime.parse(geoJsonData.metadata.generatedAt);

      _logger.i(
        'Loaded ${stations.length} stations. Generated at: $_generatedAt',
      );

      _emitFiltered();
    } catch (e, stack) {
      _logger.e('Failed to load stations', error: e, stackTrace: stack);
      debugPrint('[StationsService] ERROR: $e\n$stack');
      _stateSubject.add(StationsStateError(e));
    }
  }

  @override
  void applyFilter(StationFilter filter) {
    _activeFilter = filter;
    _emitFiltered();
  }

  void _emitFiltered() {
    final filtered = _applyFilter(_allStations, _activeFilter);
    _stateSubject.add(
      StationsStateLoaded(
        allStations: _allStations,
        filteredStations: filtered,
        activeFilter: _activeFilter,
        priceRangeByFuelType: _priceRangeByFuelType,
        generatedAt: _generatedAt,
      ),
    );
  }

  @override
  void onDispose() {
    _stateSubject.close();
  }
}

// ---------------------------------------------------------------------------
// Isolate-safe helpers (top-level functions)
// ---------------------------------------------------------------------------

/// Parses a list of [StationFeatureData] into [Station] entities.
/// Runs in a separate isolate via [compute].
List<Station> _parseFeatures(List<StationFeatureData> features) {
  return features.asMap().entries.map((entry) {
    final index = entry.key;
    final feature = entry.value;
    final props = feature.properties;

    final prices = props.prices
        .map((priceData) {
          if (priceData.gasType == null || priceData.price == null) return null;
          final fuelType = FuelType.fromGasType(priceData.gasType!);
          if (fuelType == null) return null;
          return FuelPrice(
            fuelType: fuelType,
            priceValue: FuelPrice.parsePrice(priceData.price!),
            isAvailable: priceData.isAvailable,
          );
        })
        .whereType<FuelPrice>()
        .toList();

    return Station(
      id: '${index}_${feature.geometry.longitude}_${feature.geometry.latitude}',
      name: props.name ?? '',
      brand: props.brand ?? '',
      status: props.status ?? '',
      address: props.address ?? '',
      postalCode: props.postalCode ?? '',
      region: props.region ?? '',
      latitude: feature.geometry.latitude,
      longitude: feature.geometry.longitude,
      prices: prices,
    );
  }).toList();
}

/// Computes min/max price per fuel type across all stations.
Map<FuelType, ({double min, double max})> _computePriceRanges(
  List<Station> stations,
) {
  final result = <FuelType, ({double min, double max})>{};

  for (final fuelType in FuelType.values) {
    final prices = stations
        .expand((s) => s.prices)
        .where((p) => p.fuelType == fuelType && p.isAvailable)
        .map((p) => p.priceValue)
        .toList();

    if (prices.isEmpty) continue;

    prices.sort();
    result[fuelType] = (min: prices.first, max: prices.last);
  }

  return result;
}

/// Applies a [StationFilter] to a list of [Station]s.
List<Station> _applyFilter(List<Station> stations, StationFilter filter) {
  if (filter.isEmpty) return stations;

  return stations.where((station) {
    if (filter.brands.isNotEmpty && !filter.brands.contains(station.brand)) {
      return false;
    }

    if (filter.regions.isNotEmpty && !filter.regions.contains(station.region)) {
      return false;
    }

    if (filter.fuelTypes.isNotEmpty || filter.maxPrice != null) {
      final targetFuelTypes = filter.fuelTypes.isNotEmpty
          ? filter.fuelTypes
          : FuelType.values.toSet();

      final hasPriceMatch = station.prices.any((p) {
        if (!targetFuelTypes.contains(p.fuelType)) return false;
        if (!p.isAvailable) return false;
        if (filter.maxPrice != null && p.priceValue > filter.maxPrice!) {
          return false;
        }
        return true;
      });

      if (!hasPriceMatch) return false;
    }

    return true;
  }).toList();
}
