import 'dart:async';

import 'package:app/business/stations/fuel_type.dart';
import 'package:app/business/stations/stations_state.dart';
import 'package:app/presentation/map/map_controller.dart';
import 'package:app/presentation/map/map_page_viewmodel.dart';
import 'package:app/presentation/map/widgets/fuel_type_filter_bar.dart';
import 'package:app/presentation/map/widgets/station_detail_sheet.dart';
import 'package:app/presentation/mvvm/mvvm_widget.dart';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// The main map page showing all gas stations.
final class MapPage extends MvvmWidget<MapPageViewModel> {
  const MapPage({super.key});

  @override
  MapPageViewModel getViewModel() => MapPageViewModel();

  @override
  Widget build(BuildContext context, MapPageViewModel viewModel) {
    return Scaffold(
      body: Stack(
        children: [
          _MapView(viewModel: viewModel),
          // Filter chips below search bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 0,
            right: 0,
            child: FuelTypeFilterBar(
              viewModel: viewModel,
              activeFilter: viewModel.activeFilter,
            ),
          ),
          // Station detail sheet anchored to the bottom with slide animation.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) => SlideTransition(
                position: Tween(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
              child: viewModel.selectedStation != null
                  ? StationDetailSheet(
                      key: ValueKey(viewModel.selectedStation!.id),
                      station: viewModel.selectedStation!,
                      onDismiss: viewModel.onStationDetailDismissed,
                    )
                  : const SizedBox.shrink(),
            ),
          ),
          // Loading / error overlays
          StreamBuilder<StationsState>(
            stream: viewModel.stateStream,
            builder: (context, snapshot) {
              final state = snapshot.data;
              if (state is StationsStateLoading) {
                return const _LoadingOverlay();
              }
              if (state is StationsStateError) {
                return _ErrorOverlay(
                  error: state.error,
                  onRetry: viewModel.onRefresh,
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _MapView extends StatefulWidget {
  const _MapView({required this.viewModel});
  final MapPageViewModel viewModel;

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> {
  MapController? _mapController;
  StationsStateLoaded? _lastLoaded;
  bool _isRenderingPins = false;
  bool _isLocating = false;
  StreamSubscription<StationsState>? _stateSubscription;

  /// Returns the single selected FuelType when exactly one chip is active.
  FuelType? get _displayFuelType {
    final selected = widget.viewModel.activeFilter.fuelTypes;
    return selected.length == 1 ? selected.first : null;
  }

  @override
  void initState() {
    super.initState();
    _stateSubscription = widget.viewModel.stateStream.listen(_onStateChanged);
  }

  void _onStateChanged(StationsState state) {
    if (state is StationsStateLoaded && _mapController != null) {
      _lastLoaded = state;
      setState(() => _isRenderingPins = true);
      _mapController!
          .updateStations(
            state.filteredStations,
            displayFuelType: _displayFuelType,
          )
          .whenComplete(() {
            if (mounted) setState(() => _isRenderingPins = false);
          });
    }
  }

  void _onStationTapped(String stationId) {
    final station = _lastLoaded?.filteredStations
        .where((s) => s.id == stationId)
        .firstOrNull;
    if (station != null) widget.viewModel.onStationTapped(station);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapWidget(
          styleUri: MapboxStyles.LIGHT,
          cameraOptions: CameraOptions(
            center: Point(coordinates: Position(-73.5, 46.8)),
            zoom: 5.5,
          ),
          onMapCreated: (map) async {
            _mapController = MapController(
              mapboxMap: map,
              onStationTapped: _onStationTapped,
            );

            await _mapController!.initialize();

            // If state already loaded before the map was ready, apply it now.
            if (_lastLoaded != null) {
              await _mapController!.updateStations(
                _lastLoaded!.filteredStations,
                displayFuelType: _displayFuelType,
              );
            }
          },
        ),
        if (_isRenderingPins)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x44FFFFFF),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        // Locate-me button
        Positioned(
          right: 16,
          bottom: 16 + MediaQuery.of(context).padding.bottom,
          child: FloatingActionButton.small(
            heroTag: 'locate-me',
            tooltip: 'Centre on my location',
            onPressed: _isLocating ? null : _onLocatePressed,
            child: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }

  Future<void> _onLocatePressed() async {
    setState(() => _isLocating = true);
    try {
      final position = await widget.viewModel.requestUserLocation();
      if (position != null && mounted) {
        await _mapController?.flyTo(position.latitude, position.longitude);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location unavailable or permission denied'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    super.dispose();
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const Positioned.fill(
      child: ColoredBox(
        color: Color(0x55FFFFFF),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ErrorOverlay extends StatelessWidget {
  const _ErrorOverlay({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 24,
      right: 24,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.errorContainer,
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.error_outline),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.mapLocal.errorLoadingStations),
                      Text(
                        error.toString(),
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.refresh),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on BuildContext {
  // Localisation shortcut — resolves at call site to avoid circular imports.
  _MapLocalStrings get mapLocal => _MapLocalStrings(this);
}

class _MapLocalStrings {
  final BuildContext _context;
  const _MapLocalStrings(this._context);
  String get errorLoadingStations {
    // Falls back to a hardcoded string; generated l10n will be used once
    // `flutter gen-l10n` runs.
    try {
      final l10n = Localizations.of<dynamic>(_context, dynamic);
      return (l10n as dynamic).errorLoadingStations as String;
    } catch (_) {
      return 'Could not load stations. Tap to retry.';
    }
  }
}
