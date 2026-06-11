import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:drobe/main.dart';

void main() {
  testWidgets('Drobe app shell renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
