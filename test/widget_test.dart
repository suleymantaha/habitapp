import 'package:flutter_test/flutter_test.dart';

import 'package:whatsapp_catalog/app/app.dart';
import 'package:whatsapp_catalog/app/app_scope.dart';
import 'package:whatsapp_catalog/features/catalog/data/repositories/in_memory_catalog_repository.dart';

void main() {
  testWidgets('Home loads', (WidgetTester tester) async {
    await tester.pumpWidget(
      AppScope(
        catalogRepository: InMemoryCatalogRepository(),
        child: const App(),
      ),
    );
    await tester.pump();
    expect(find.text('Kataloglar'), findsWidgets);
  });
}
