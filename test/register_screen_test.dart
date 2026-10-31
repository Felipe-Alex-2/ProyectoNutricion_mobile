import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:mobile/models/branch_model.dart';
import 'package:mobile/screens/auth/register_screen.dart';
import 'package:mobile/services/api_service.dart';
import 'package:mobile/services/auth_service.dart';
import 'package:mobile/services/storage_service.dart';

class RegistrationAuth extends AuthService {
  RegistrationAuth(super.api, super.storage);
  bool failBranches = false;
  bool submitted = false;
  String? submittedTenant;
  String? submittedBranch;
  List<Branch> branches = [];
  @override
  Future<List<Branch>> fetchPublicBranches() async => [
    Branch(id: 'company', name: 'Empresa', code: 'E'),
  ];
  @override
  Future<List<Branch>> fetchCompanyBranches(String tenantId) async {
    if (failBranches) throw Exception('offline');
    return branches;
  }

  @override
  Future<bool> register(
    String email,
    String password,
    String fullName, {
    String? tenantId,
    String? branchId,
  }) async {
    submitted = true;
    submittedTenant = tenantId;
    submittedBranch = branchId;
    return false;
  }
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  Future<RegistrationAuth> show(WidgetTester tester) async {
    final storage = StorageService();
    final api = ApiService(storage);
    final auth = RegistrationAuth(api, storage);
    addTearDown(api.dispose);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthService>.value(
        value: auth,
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  Future<void> submit(WidgetTester tester) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Paciente Prueba');
    await tester.enterText(fields.at(1), 'paciente@example.com');
    await tester.enterText(fields.at(2), 'Segura123!');
    await tester.enterText(fields.at(3), 'Segura123!');
    final button = find.byType(ElevatedButton);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Company with no branches allows registration without branch_id',
    (tester) async {
      final auth = await show(tester);
      expect(find.textContaining('aún no tiene sucursales'), findsOneWidget);
      await submit(tester);
      expect(auth.submitted, isTrue);
      expect(auth.submittedTenant, 'company');
      expect(auth.submittedBranch, isNull);
    },
  );
  testWidgets('Branch loading failure blocks registration and supports retry', (
    tester,
  ) async {
    final auth = await show(tester);
    auth.failBranches = true;
    // Reload by changing the company selection.
    final dropdown = find.byType(DropdownButtonFormField<String>).first;
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Empresa').last);
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    await submit(tester);
    expect(auth.submitted, isFalse);
    auth.failBranches = false;
    auth.branches = [Branch(id: 'branch', name: 'Sucursal Central', code: 'C')];
    await tester.ensureVisible(find.text('Reintentar'));
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    await submit(tester);
    expect(auth.submittedBranch, 'branch');
  });
}
