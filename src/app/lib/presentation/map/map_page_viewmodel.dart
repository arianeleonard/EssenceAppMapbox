import 'package:app/business/stations/fuel_type.dart';
import 'package:app/business/stations/station.dart';
import 'package:app/business/stations/station_filter.dart';
import 'package:app/business/stations/stations_service.dart';
import 'package:app/business/stations/stations_state.dart';
import 'package:app/presentation/mvvm/view_model.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';

class MapPageViewModel extends ViewModel {
  final StationsService _stationsService = GetIt.I<StationsService>();
  AppLifecycleListener? _lifecycleListener;

  Stream<StationsState> get stateStream =>
      getLazy('stateStream', () => _stationsService.stateStream);

  Station? get selectedStation => get<Station?>('selectedStation', null);

  StationFilter get activeFilter => get<StationFilter>(
    'activeFilter',
    StationFilter(fuelTypes: {FuelType.regulier}),
  );

  @override
  void startRecordingPropertiesToNotify() {
    super.startRecordingPropertiesToNotify();
    _lifecycleListener ??= AppLifecycleListener(onResume: _onAppResume);
  }

  void onStationTapped(Station station) {
    set('selectedStation', station);
  }

  void onStationDetailDismissed() {
    set('selectedStation', null);
  }

  void onFilterChanged(StationFilter filter) {
    set('activeFilter', filter);
    _stationsService.applyFilter(filter);
  }

  /// Requests location permission and returns the current [Position],
  /// or null if permission is denied or location is unavailable.
  Future<Position?> requestUserLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  void onRefresh() {
    _stationsService.loadStations();
  }

  void _onAppResume() {
    _stationsService.loadStations();
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    super.dispose();
  }
}
