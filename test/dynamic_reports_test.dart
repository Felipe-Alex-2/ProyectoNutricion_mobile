import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/storage_service.dart';
import 'package:mobile/screens/reports/personal_reports_screen.dart';

void main() {
  testWidgets(
    'Mobile report accepts text commands and keeps server query for exports',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final channel in [
        'flutter_tts',
        'plugin.csdcorp.com/speech_to_text',
      ]) {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(
              MethodChannel(channel),
              (call) async => 1,
            );
      }
      final requests = <Map<String, dynamic>>[];
      final columns = [
        {'key': 'full_name', 'label': 'Nombre', 'type': 'string'},
      ];
      final report = {
        'entity': 'patients',
        'title': 'Clientes activos',
        'total_rows': 1,
        'summary': '1 cliente',
        'columns': columns,
        'rows': [
          {'full_name': 'Paciente compartido'},
        ],
        'notes': [],
      };
      final api = ApiService(
        StorageService(),
        client: MockClient((request) async {
          if (request.url.path.endsWith('/entities'))
            return http.Response(
              jsonEncode([
                {
                  'entity': 'patients',
                  'label': 'Clientes / Pacientes',
                  'available_columns': columns,
                },
              ]),
              200,
            );
          if (request.url.path.endsWith('/scope'))
            return http.Response(
              jsonEncode({'companies': [], 'branches': []}),
              200,
            );
          if (request.url.path.endsWith('/voice-command')) {
            requests.add(jsonDecode(request.body));
            return http.Response(
              jsonEncode({
                'parsed_request': {'entity': 'patients', 'status': 'activo'},
                'explanation': 'Filtro aplicado',
                'report_data': report,
              }),
              200,
            );
          }
          if (request.url.path.endsWith('/query'))
            return http.Response(jsonEncode(report), 200);
          return http.Response('[]', 200);
        }),
      )..currentUserId = 'client';
      await tester.pumpWidget(
        Provider<ApiService>.value(
          value: api,
          child: const MaterialApp(home: PersonalReportsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Reportes dinámicos'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'Clientes activos');
      await tester.pump();
      await tester.tap(find.text('Procesar'));
      await tester.pumpAndSettle();
      expect(requests.single['transcript'], 'Clientes activos');
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Descargar PDF'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Descargar Excel'), findsOneWidget);
      expect(find.text('Paciente compartido'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
