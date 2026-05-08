import 'package:app/business/stations/fuel_price.dart';
import 'package:app/business/stations/fuel_type.dart';
import 'package:app/business/stations/station.dart';
import 'package:app/business/stations/station_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Station _makeStation({
  required String id,
  String brand = 'Shell',
  String region = 'Montréal',
  List<FuelPrice> prices = const [],
}) {
  return Station(
    id: id,
    name: 'Test Station $id',
    brand: brand,
    status: 'En opération',
    address: '123 rue Test',
    postalCode: 'H0H 0H0',
    region: region,
    latitude: 45.5,
    longitude: -73.5,
    prices: prices,
  );
}

FuelPrice _price(FuelType ft, double value, {bool available = true}) =>
    FuelPrice(fuelType: ft, priceValue: value, isAvailable: available);

void main() {
  // ---------------------------------------------------------------------------
  // FuelPrice.parsePrice
  // ---------------------------------------------------------------------------
  group('FuelPrice.parsePrice', () {
    test('parses standard format', () {
      expect(FuelPrice.parsePrice('184.9¢'), closeTo(184.9, 0.001));
    });

    test('parses price without decimal', () {
      expect(FuelPrice.parsePrice('200¢'), closeTo(200.0, 0.001));
    });

    test('parses price with whitespace', () {
      expect(FuelPrice.parsePrice(' 175.4¢ '), closeTo(175.4, 0.001));
    });
  });

  // ---------------------------------------------------------------------------
  // Station.cheapestPrice
  // ---------------------------------------------------------------------------
  group('Station.cheapestPrice', () {
    test('returns the minimum available price', () {
      final station = _makeStation(
        id: '1',
        prices: [
          _price(FuelType.regulier, 172.9),
          _price(FuelType.super_, 198.9),
          _price(FuelType.diesel, 210.9),
        ],
      );
      expect(station.cheapestPrice, closeTo(172.9, 0.001));
    });

    test('ignores unavailable prices', () {
      final station = _makeStation(
        id: '2',
        prices: [
          _price(FuelType.regulier, 172.9, available: false),
          _price(FuelType.super_, 198.9),
        ],
      );
      expect(station.cheapestPrice, closeTo(198.9, 0.001));
    });

    test('returns null when all unavailable', () {
      final station = _makeStation(
        id: '3',
        prices: [_price(FuelType.regulier, 172.9, available: false)],
      );
      expect(station.cheapestPrice, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // StationFilter
  // ---------------------------------------------------------------------------
  group('StationFilter', () {
    test('isEmpty on default empty filter', () {
      expect(StationFilter.empty.isEmpty, isTrue);
    });

    test('isEmpty is false when brand filter is set', () {
      final f = StationFilter(brands: {'Shell'});
      expect(f.isEmpty, isFalse);
    });

    test('copyWith preserves unset fields', () {
      const original = StationFilter(brands: {'Shell'});
      final updated = original.copyWith(regions: {'Montréal'});
      expect(updated.brands, contains('Shell'));
      expect(updated.regions, contains('Montréal'));
    });

    test('copyWith with clearMaxPrice resets maxPrice', () {
      const original = StationFilter(maxPrice: 180.0);
      final updated = original.copyWith(clearMaxPrice: true);
      expect(updated.maxPrice, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // FuelType.fromGasType
  // ---------------------------------------------------------------------------
  group('FuelType.fromGasType', () {
    test('parses Régulier', () {
      expect(FuelType.fromGasType('Régulier'), FuelType.regulier);
    });

    test('parses regulier (ASCII)', () {
      expect(FuelType.fromGasType('regulier'), FuelType.regulier);
    });

    test('parses Super', () {
      expect(FuelType.fromGasType('Super'), FuelType.super_);
    });

    test('parses Diesel', () {
      expect(FuelType.fromGasType('Diesel'), FuelType.diesel);
    });

    test('returns null for unknown type', () {
      expect(FuelType.fromGasType('Électrique'), isNull);
    });
  });
}
