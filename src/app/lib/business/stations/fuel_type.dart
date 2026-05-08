/// Fuel type offered at a gas station.
enum FuelType {
  regulier,
  super_,
  diesel;

  /// Maps the [GasType] string from the API to a [FuelType].
  static FuelType? fromGasType(String gasType) {
    switch (gasType.toLowerCase()) {
      case 'régulier':
      case 'regulier':
        return FuelType.regulier;
      case 'super':
        return FuelType.super_;
      case 'diesel':
        return FuelType.diesel;
      default:
        return null;
    }
  }
}
