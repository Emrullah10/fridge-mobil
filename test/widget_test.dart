import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fridge_mobil/main.dart';

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=http://localhost:4000/api');
  });

  testWidgets('App boots and shows a loading state before auth resolves', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: FridgeApp()));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
