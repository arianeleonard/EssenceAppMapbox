import 'package:app/business/stations/fuel_type.dart';
import 'package:app/business/stations/station_filter.dart';
import 'package:app/business/stations/stations_state.dart';
import 'package:app/presentation/map/map_page_viewmodel.dart';
import 'package:flutter/material.dart';

/// A horizontal row of quick-filter chips for fuel types.
class FuelTypeFilterBar extends StatelessWidget {
  const FuelTypeFilterBar({
    super.key,
    required this.viewModel,
    required this.activeFilter,
  });
  final MapPageViewModel viewModel;
  final StationFilter activeFilter;

  static const _fuelTypes = [
    (FuelType.regulier, 'Regular'),
    (FuelType.super_, 'Super'),
    (FuelType.diesel, 'Diesel'),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          // Filter icon button — opens full filter sheet
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _FilterIconButton(viewModel: viewModel),
          ),
          ..._fuelTypes.map((entry) {
            final (fuelType, label) = entry;
            final isSelected = activeFilter.fuelTypes.contains(fuelType);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(label),
                selected: isSelected,
                onSelected: (_) => _toggleFuelType(fuelType, activeFilter),
                showCheckmark: false,
              ),
            );
          }),
        ],
      ),
    );
  }

  void _toggleFuelType(FuelType ft, StationFilter current) {
    // Single-select: selecting an already-selected chip deselects it;
    // selecting a different chip replaces the selection.
    final updated = current.fuelTypes.contains(ft) ? <FuelType>{} : {ft};
    viewModel.onFilterChanged(current.copyWith(fuelTypes: updated));
  }
}

class _FilterIconButton extends StatelessWidget {
  const _FilterIconButton({required this.viewModel});
  final MapPageViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = !viewModel.activeFilter.isEmpty;
    return Badge(
      isLabelVisible: hasActiveFilter,
      child: IconButton.filledTonal(
        icon: const Icon(Icons.tune),
        tooltip: 'Filter stations',
        onPressed: () => _showFilterSheet(context),
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => StationsFilterSheet(viewModel: viewModel),
    );
  }
}

// ---------------------------------------------------------------------------
// Full filter sheet (imported inline for simplicity)
// ---------------------------------------------------------------------------

class StationsFilterSheet extends StatefulWidget {
  const StationsFilterSheet({super.key, required this.viewModel});
  final MapPageViewModel viewModel;

  @override
  State<StationsFilterSheet> createState() => _StationsFilterSheetState();
}

class _StationsFilterSheetState extends State<StationsFilterSheet> {
  late StationFilter _draft;
  List<String> _brands = [];
  List<String> _regions = [];
  double? _maxPrice;

  @override
  void initState() {
    super.initState();
    _draft = widget.viewModel.activeFilter;

    final state = widget.viewModel.stateStream;
    state.first.then((s) {
      if (s is StationsStateLoaded && mounted) {
        setState(() {
          _brands = s.allStations.map((s) => s.brand).toSet().toList()..sort();
          _regions = s.allStations.map((s) => s.region).toSet().toList()
            ..sort();
          // Use regulier max as the default slider max.
          final range = s.priceRangeByFuelType[FuelType.regulier];
          _maxPrice = range?.max;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'Filter Stations',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    TextButton(onPressed: _reset, child: const Text('Reset')),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _SectionTitle(title: 'Fuel Types'),
                    _FuelTypeToggles(
                      selected: _draft.fuelTypes,
                      onChanged: (fts) => setState(
                        () => _draft = _draft.copyWith(fuelTypes: fts),
                      ),
                    ),
                    if (_maxPrice != null) ...[
                      _SectionTitle(title: 'Max Price (¢/L)'),
                      _PriceSlider(
                        currentMax: _draft.maxPrice ?? _maxPrice!,
                        absoluteMax: _maxPrice!,
                        onChanged: (v) => setState(
                          () => _draft = _draft.copyWith(maxPrice: v),
                        ),
                      ),
                    ],
                    _SectionTitle(title: 'Brands'),
                    _MultiSelectChips(
                      options: _brands,
                      selected: _draft.brands,
                      onChanged: (brands) => setState(
                        () => _draft = _draft.copyWith(brands: brands),
                      ),
                    ),
                    _SectionTitle(title: 'Regions'),
                    _MultiSelectChips(
                      options: _regions,
                      selected: _draft.regions,
                      onChanged: (regions) => setState(
                        () => _draft = _draft.copyWith(regions: regions),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _apply,
                    child: const Text('Apply'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _reset() {
    setState(() => _draft = StationFilter.empty);
  }

  void _apply() {
    widget.viewModel.onFilterChanged(_draft);
    Navigator.of(context).pop();
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _FuelTypeToggles extends StatelessWidget {
  const _FuelTypeToggles({required this.selected, required this.onChanged});
  final Set<FuelType> selected;
  final ValueChanged<Set<FuelType>> onChanged;

  static const _options = [
    (FuelType.regulier, 'Regular'),
    (FuelType.super_, 'Super'),
    (FuelType.diesel, 'Diesel'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: _options.map((entry) {
        final (ft, label) = entry;
        final isSelected = selected.contains(ft);
        return FilterChip(
          label: Text(label),
          selected: isSelected,
          onSelected: (_) {
            final updated = Set<FuelType>.from(selected);
            isSelected ? updated.remove(ft) : updated.add(ft);
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}

class _PriceSlider extends StatelessWidget {
  const _PriceSlider({
    required this.currentMax,
    required this.absoluteMax,
    required this.onChanged,
  });

  final double currentMax;
  final double absoluteMax;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Slider(
            value: currentMax.clamp(100, absoluteMax),
            min: 100,
            max: absoluteMax,
            divisions: ((absoluteMax - 100) / 0.5).round(),
            label: '${currentMax.toStringAsFixed(1)}¢',
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 52,
          child: Text(
            '${currentMax.toStringAsFixed(1)}¢',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _MultiSelectChips extends StatelessWidget {
  const _MultiSelectChips({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) {
            final updated = Set<String>.from(selected);
            isSelected ? updated.remove(option) : updated.add(option);
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}
