import 'package:app/app.dart';
import 'package:app/business/diagnostics/diagnostics_service.dart';
import 'package:app/business/stations/stations_service.dart';
import 'package:app/shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';
import 'package:mockito/annotations.dart';

import 'app_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<DiagnosticsService>(),
  MockSpec<StationsService>(),
])
void main() {
  var diagnosticsService = MockDiagnosticsService();
  var stationsService = MockStationsService();

  setUp(() {
    diagnosticsService = MockDiagnosticsService();
    stationsService = MockStationsService();

    GetIt.I.registerSingleton<DiagnosticsService>(diagnosticsService);
    GetIt.I.registerSingleton<StationsService>(stationsService);

    GetIt.I.registerSingleton(Logger());
  });

  testWidgets('Shell Test', (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.byType(Shell), findsOneWidget);
  });
}
