import 'package:app/business/stations/fuel_type.dart';
import 'package:app/business/stations/station.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A bottom card that displays detailed information about a [Station].
class StationDetailSheet extends StatelessWidget {
  const StationDetailSheet({
    super.key,
    required this.station,
    required this.onDismiss,
  });

  final Station station;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Material(
      elevation: 16,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + bottomPad),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle row + close button
            Row(
              children: [
                const Spacer(),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Brand + Station name
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _BrandBadge(brand: station.brand),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.brand,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: Colors.grey[600]),
                      ),
                      Text(
                        station.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Address
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    station.address,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            // Region + postal code
            Row(
              children: [
                const Icon(Icons.map_outlined, size: 16),
                const SizedBox(width: 6),
                Text(
                  '${station.region}  •  ${station.postalCode}',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
            const Divider(height: 20),
            // Prices
            Text('Fuel Prices', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            _PricesTable(station: station),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _openDirections(station),
              icon: const Icon(Icons.directions),
              label: const Text('Get Directions'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDirections(Station station) async {
    final uri = Uri.parse(
      'https://maps.apple.com/?q=${Uri.encodeComponent(station.name)}'
      '&ll=${station.latitude},${station.longitude}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// ---------------------------------------------------------------------------
// Private sub-widgets
// ---------------------------------------------------------------------------

class _BrandBadge extends StatelessWidget {
  const _BrandBadge({required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Text(
        brand.isNotEmpty ? brand[0].toUpperCase() : '?',
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class _PricesTable extends StatelessWidget {
  const _PricesTable({required this.station});
  final Station station;

  static const _fuelOrder = [
    FuelType.regulier,
    FuelType.super_,
    FuelType.diesel,
  ];

  static String _label(FuelType ft) {
    switch (ft) {
      case FuelType.regulier:
        return 'Regular';
      case FuelType.super_:
        return 'Super';
      case FuelType.diesel:
        return 'Diesel';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _fuelOrder.map((ft) {
        final price = station.prices.where((p) => p.fuelType == ft).firstOrNull;
        return _PriceRow(label: _label(ft), price: price);
      }).toList(),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.label, required this.price});

  final String label;
  final dynamic price; // FuelPrice?

  @override
  Widget build(BuildContext context) {
    final available = price?.isAvailable == true;
    final priceText = available
        ? '${price!.priceValue.toStringAsFixed(1)}c'
        : 'Unavailable';
    final priceColor = available
        ? Theme.of(context).colorScheme.onSurface
        : Colors.grey[400];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const Spacer(),
          Text(
            priceText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: priceColor,
            ),
          ),
        ],
      ),
    );
  }
}
