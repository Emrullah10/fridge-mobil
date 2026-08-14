import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/main.dart';

void main() {
  testWidgets('App boots and shows a loading state before auth resolves', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FridgeApp()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
