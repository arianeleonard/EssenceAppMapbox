import 'dart:convert';
import 'dart:developer' as dev;

import 'package:app/business/stations/fuel_price.dart';
import 'package:app/business/stations/fuel_type.dart';
import 'package:app/business/stations/station.dart';
import 'package:app/presentation/map/pin_painter.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart' show compute;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Top-level function required by [compute]. Encodes a feature list to a
/// GeoJSON FeatureCollection string in a background isolate, keeping the
/// main thread free during serialisation of large datasets.
String _encodeFeaturesToGeoJson(List<Map<String, dynamic>> features) {
  return jsonEncode({'type': 'FeatureCollection', 'features': features});
}

/// Handles all Mapbox map setup and interaction for the station map.
///
/// Responsibilities:
/// - Register brand images as Mapbox style images
/// - Add/update the GeoJSON source with pre-processed features
/// - Configure cluster and symbol layers with data-driven expressions
/// - Apply filter expressions without reloading the source
class MapController {
  static const _sourceId = 'stations-source';
  static const _clusterLayerId = 'stations-clusters';
  static const _clusterCountLayerId = 'stations-cluster-count';
  static const _symbolLayerId = 'stations-symbols';

  final MapboxMap mapboxMap;

  /// Called when the user taps a station pin. Receives the station's string ID
  /// as stored in the GeoJSON feature's `station_id` property.
  final void Function(String stationId) onStationTapped;

  /// Tracks style image IDs already registered this session to avoid duplicates.
  final Set<String> _registeredPinIds = {};

  /// Maximum number of pin images kept in the style cache.
  /// When the limit is reached the cache is cleared so stale images do not
  /// accumulate indefinitely in the Mapbox style layer.
  static const int _maxPinCacheSize = 300;

  /// Incremented on each [updateStations] call. A stale async update compares
  /// its captured value against this and bails out if they diverge, preventing
  /// an older update from overwriting a newer one.
  int _updateGeneration = 0;

  /// Station count from the last completed [updateStations] call.
  /// Used to detect significant data reloads that should invalidate the pin cache.
  int _lastStationCount = 0;

  MapController({required this.mapboxMap, required this.onStationTapped});

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    await PinPainter.preloadIcon();
    await _registerImages();
    await _addLayers();
    _listenToTaps();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Animates the camera to [latitude] / [longitude] at street level.
  Future<void> flyTo(double latitude, double longitude) async {
    await mapboxMap.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: 13.0,
      ),
      MapAnimationOptions(duration: 1200),
    );
  }

  /// Replaces the GeoJSON source data with new [stations].
  ///
  /// [displayFuelType] pins show the price for that specific fuel type.
  /// When null the cheapest available price is used.
  Future<void> updateStations(
    List<Station> stations, {
    FuelType? displayFuelType,
  }) async {
    final generation = ++_updateGeneration;

    // Invalidate the pin cache when the station count changes by more than 10%.
    // This prevents stale pins from persisting after a significant data reload
    // (e.g. after a filter change that removes/adds many stations).
    if (_lastStationCount > 0) {
      final delta =
          (stations.length - _lastStationCount).abs() / _lastStationCount;
      if (delta > 0.10) {
        dev.log(
          'Station count changed by ${(delta * 100).toStringAsFixed(0)}% '
          '($_lastStationCount → ${stations.length}). Invalidating pin cache.',
          name: 'MapController',
        );
        _registeredPinIds.clear();
      }
    }
    _lastStationCount = stations.length;
    dev.Timeline.startSync(
      'MapController.updateStations',
      arguments: {
        'stationCount': stations.length,
        'displayFuelType': displayFuelType?.name ?? 'cheapest',
        'generation': generation,
      },
    );
    try {
      dev.Timeline.startSync('MapController.computeRanges');
      final ranges = _computeRanges(stations, displayFuelType: displayFuelType);
      dev.Timeline.finishSync();

      await _ensurePinsRegistered(
        stations,
        ranges,
        displayFuelType: displayFuelType,
      );

      // Bail out if a newer call arrived while pin images were being rendered.
      if (generation != _updateGeneration) {
        dev.log(
          'updateStations g$generation: superseded by g$_updateGeneration — skipping GeoJSON update',
          name: 'MapController',
        );
        return;
      }

      dev.Timeline.startSync('MapController.buildFeatures');
      final features = _buildFeatures(
        stations,
        ranges,
        displayFuelType: displayFuelType,
      );
      dev.Timeline.finishSync();

      dev.Timeline.startSync('MapController.jsonEncode');
      final geoJson = await compute(_encodeFeaturesToGeoJson, features);
      dev.Timeline.finishSync();

      final source = await mapboxMap.style.getSource(_sourceId);
      if (source is GeoJsonSource) {
        await source.updateGeoJSON(geoJson);
      }
    } finally {
      dev.Timeline.finishSync();
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<void> _registerImages() async {
    // Register one fallback pin per tier so there is always a valid style image
    // even if canvas rendering fails later (e.g. on the Android SW emulator).
    for (var tier = 0; tier < PinPainter.tierColors.length; tier++) {
      final id = '${PinPainter.fallbackIconId}_$tier';
      final bytes = await PinPainter.render(tier: tier, priceLabel: '');
      if (bytes != null) {
        await mapboxMap.style.addStyleImage(
          id,
          2.0,
          MbxImage(
            width: PinPainter.width,
            height: PinPainter.height,
            data: bytes,
          ),
          false,
          [],
          [],
          null,
        );
        _registeredPinIds.add(id);
      }
    }
  }

  /// Renders and registers a Mapbox style image for every unique
  /// (priceTier, priceLabel) combination not yet registered.
  Future<void> _ensurePinsRegistered(
    List<Station> stations,
    Map<FuelType, ({double min, double max, List<double> sorted})> ranges, {
    FuelType? displayFuelType,
  }) async {
    final pending = <String, ({int tier, String label})>{};

    // Evict cache if it has grown beyond the limit to avoid accumulating stale
    // image objects in the Mapbox style indefinitely.
    if (_registeredPinIds.length >= _maxPinCacheSize) {
      dev.log(
        'Pin cache full ($_maxPinCacheSize). Clearing to avoid memory growth.',
        name: 'MapController',
      );
      _registeredPinIds.clear();
    }

    for (final station in stations) {
      final tier = _stationTier(
        station,
        ranges,
        displayFuelType: displayFuelType,
      );
      final label = _priceLabel(station, displayFuelType: displayFuelType);
      final id = PinPainter.pinImageId(tier, label);
      if (!_registeredPinIds.contains(id)) {
        pending[id] = (tier: tier, label: label);
      }
    }

    if (pending.isEmpty) {
      dev.log(
        'Pin cache: all ${_registeredPinIds.length} images already cached — skipping render',
        name: 'MapController',
      );
      return;
    }

    dev.log(
      'Pin render: ${pending.length} new images '
      '(${_registeredPinIds.length} already cached)',
      name: 'MapController',
    );
    final sw = Stopwatch()..start();

    // Phase 1: render all bitmaps in parallel via PinPainter.
    // toByteData() runs on a thread pool so concurrent futures are faster.
    final rendered = await Future.wait(
      pending.entries.map((entry) async {
        final bytes = await PinPainter.render(
          tier: entry.value.tier,
          priceLabel: entry.value.label,
        );
        return (id: entry.key, bytes: bytes);
      }),
    );

    // Phase 2: register with Mapbox in parallel.
    // Platform channel calls are queued on the platform thread and can be
    // dispatched concurrently from the Dart side.
    await Future.wait(
      rendered.map((result) async {
        if (result.bytes != null) {
          await mapboxMap.style.addStyleImage(
            result.id,
            2.0, // 2× pixel ratio → effective 48×42 dp at iconSize 1.0
            MbxImage(
              width: PinPainter.width,
              height: PinPainter.height,
              data: result.bytes!,
            ),
            false,
            [],
            [],
            null,
          );
        }
        // Always add to the set so we don't retry on subsequent calls.
        _registeredPinIds.add(result.id);
      }),
    );

    dev.log(
      'Pin render: finished in ${sw.elapsedMilliseconds} ms '
      '(${pending.length} images)',
      name: 'MapController',
    );
  }

  Future<void> _addLayers() async {
    // Read cluster_max_zoom from Firebase Remote Config (default: 14).
    // Can be tuned without a release by updating the value in the console.
    final clusterMaxZoom = FirebaseRemoteConfig.instance.getInt(
      'cluster_max_zoom',
    );
    if (clusterMaxZoom == 0) {
      // Fallback: getInt returns 0 when the key is missing (not yet fetched).
      dev.log(
        'cluster_max_zoom not yet available — using default of 14',
        name: 'MapController',
      );
    }
    final effectiveMaxZoom = (clusterMaxZoom > 0 ? clusterMaxZoom : 14)
        .toDouble();

    // Add GeoJSON source with clustering enabled.
    await mapboxMap.style.addSource(
      GeoJsonSource(
        id: _sourceId,
        data: '{"type":"FeatureCollection","features":[]}',
        cluster: true,
        clusterMaxZoom: effectiveMaxZoom,
        clusterRadius: 50,
        clusterProperties: {
          // Aggregate the minimum displayed price across all points in a cluster.
          'min_price': [
            'min',
            ['get', 'display_price'],
          ],
        },
      ),
    );

    // Cluster circle layer.
    await mapboxMap.style.addLayer(
      CircleLayer(
        id: _clusterLayerId,
        sourceId: _sourceId,
        filter: ['has', 'point_count'],
        circleRadiusExpression: [
          'step',
          ['get', 'point_count'],
          20,
          10,
          30,
          50,
          40,
          200,
          50,
        ],
        circleColorExpression: [
          'step',
          ['get', 'point_count'],
          '#3FB1CE',
          10,
          '#1976D2',
          50,
          '#0D47A1',
        ],
        circleOpacity: 0.85,
      ),
    );

    // Cluster count + min price text.
    await mapboxMap.style.addLayer(
      SymbolLayer(
        id: _clusterCountLayerId,
        sourceId: _sourceId,
        filter: ['has', 'point_count'],
        textFieldExpression: [
          'format',
          [
            'to-string',
            ['get', 'point_count_abbreviated'],
          ],
          <String, dynamic>{},
          '\n',
          <String, dynamic>{},
          [
            'number-format',
            ['get', 'min_price'],
            {'min-fraction-digits': 1, 'max-fraction-digits': 1},
          ],
          {'font-scale': 0.8},
          '¢',
          {'font-scale': 0.8},
        ],
        textSize: 13.0,
        textColor: 0xFFFFFFFF,
        textFont: ['DIN Offc Pro Medium', 'Arial Unicode MS Bold'],
      ),
    );

    // Individual station symbol layer.
    await mapboxMap.style.addLayer(
      SymbolLayer(
        id: _symbolLayerId,
        sourceId: _sourceId,
        filter: [
          '!',
          ['has', 'point_count'],
        ],
        iconImageExpression: ['get', 'pin_image_id'],
        iconSize: 1.0,
        iconAllowOverlap: false,
        iconIgnorePlacement: false,
        iconAnchor: IconAnchor.BOTTOM,
      ),
    );
  }

  void _listenToTaps() {
    mapboxMap.addInteraction(
      TapInteraction(
        FeaturesetDescriptor(layerId: _symbolLayerId),
        (feature, context) => _onFeatureTapped(feature),
      ),
    );
  }

  void _onFeatureTapped(TypedFeaturesetFeature<FeaturesetDescriptor> feature) {
    final properties = feature.properties;
    final id = properties['station_id'] as String?;
    if (id != null) onStationTapped(id);
  }

  // ---------------------------------------------------------------------------
  // GeoJSON feature building
  // ---------------------------------------------------------------------------

  Map<FuelType, ({double min, double max, List<double> sorted})> _computeRanges(
    List<Station> stations, {
    FuelType? displayFuelType,
  }) {
    final ranges =
        <FuelType, ({double min, double max, List<double> sorted})>{};
    final typesToCompute = displayFuelType != null
        ? [displayFuelType]
        : FuelType.values;
    for (final ft in typesToCompute) {
      final prices =
          stations
              .expand((s) => s.prices)
              .where((p) => p.fuelType == ft && p.isAvailable)
              .map((p) => p.priceValue)
              .toList()
            ..sort();
      if (prices.isEmpty) continue;
      ranges[ft] = (min: prices.first, max: prices.last, sorted: prices);
    }
    return ranges;
  }

  /// Returns 0–3 (green/yellow/orange/red) based on price quartile
  /// within the same fuel type's distribution.
  ///
  /// When [displayFuelType] is null, the station's cheapest available price
  /// is compared against the range for *that specific fuel type* — so prices
  /// are always compared like-for-like.
  static int _stationTier(
    Station station,
    Map<FuelType, ({double min, double max, List<double> sorted})> ranges, {
    FuelType? displayFuelType,
  }) {
    double? price;
    FuelType? ft;
    if (displayFuelType != null) {
      ft = displayFuelType;
      price = station.prices
          .where((p) => p.fuelType == ft && p.isAvailable)
          .map((p) => p.priceValue)
          .firstOrNull;
    } else {
      // Find the cheapest available price and the fuel type it belongs to.
      FuelPrice? cheapestEntry;
      for (final p in station.prices) {
        if (!p.isAvailable) continue;
        if (cheapestEntry == null || p.priceValue < cheapestEntry.priceValue) {
          cheapestEntry = p;
        }
      }
      price = cheapestEntry?.priceValue;
      ft = cheapestEntry?.fuelType;
    }
    if (price == null || ft == null) return 1;
    final range = ranges[ft];
    if (range == null || range.sorted.isEmpty) return 1;
    // Quartile rank: 0 = bottom 25 %, 1 = 25–50 %, 2 = 50–75 %, 3 = top 25 %.
    final n = range.sorted.length;
    final rank = range.sorted.indexWhere((p) => p >= price!);
    final percentile = rank < 0 ? 1.0 : rank / n;
    if (percentile < 0.25) return 0;
    if (percentile < 0.50) return 1;
    if (percentile < 0.75) return 2;
    return 3;
  }

  static String _priceLabel(Station station, {FuelType? displayFuelType}) {
    double? price;
    if (displayFuelType != null) {
      price = station.prices
          .where((p) => p.fuelType == displayFuelType && p.isAvailable)
          .map((p) => p.priceValue)
          .firstOrNull;
    } else {
      price = station.cheapestPrice;
    }
    // Round to 1 decimal to minimise unique image count while showing
    // enough precision. e.g. 168.44 → "168.4¢".
    return price != null ? '${(price * 10).round() / 10}¢' : '';
  }

  List<Map<String, dynamic>> _buildFeatures(
    List<Station> stations,
    Map<FuelType, ({double min, double max, List<double> sorted})> ranges, {
    FuelType? displayFuelType,
  }) {
    if (stations.isEmpty) return [];

    return stations.map((station) {
      final cheapest = station.cheapestPrice;
      final tier = _stationTier(
        station,
        ranges,
        displayFuelType: displayFuelType,
      );
      final label = _priceLabel(station, displayFuelType: displayFuelType);
      final pinId =
          _registeredPinIds.contains(PinPainter.pinImageId(tier, label))
          ? PinPainter.pinImageId(tier, label)
          : '${PinPainter.fallbackIconId}_$tier';

      // Numeric price for cluster min aggregation — matches the displayed price.
      final double displayPriceValue;
      if (displayFuelType != null) {
        displayPriceValue =
            station.prices
                .where((p) => p.fuelType == displayFuelType && p.isAvailable)
                .map((p) => p.priceValue)
                .firstOrNull ??
            99999.0;
      } else {
        displayPriceValue = station.cheapestPrice ?? 99999.0;
      }

      final availableFuelTypes = station.prices
          .where((p) => p.isAvailable)
          .map((p) => _fuelTypeName(p.fuelType))
          .join(',');

      return {
        'type': 'Feature',
        'id': station.id,
        'geometry': {
          'type': 'Point',
          'coordinates': [station.longitude, station.latitude],
        },
        'properties': {
          'station_id': station.id,
          'name': station.name,
          'brand': station.brand,
          'region': station.region,
          'cheapest_price': cheapest ?? 0.0,
          'display_price': displayPriceValue,
          'available_fuel_types': availableFuelTypes,
          'pin_image_id': pinId,
        },
      };
    }).toList();
  }

  static String _fuelTypeName(FuelType ft) {
    switch (ft) {
      case FuelType.regulier:
        return 'regulier';
      case FuelType.super_:
        return 'super';
      case FuelType.diesel:
        return 'diesel';
    }
  }
}
