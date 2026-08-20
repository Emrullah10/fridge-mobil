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

    // _AuthGate açılışta arka planda /app-config'i sorgular (bkz. main.dart
    // _checkAppVersion) — testte gerçek bir sunucu olmadığı için istek asla
    // yanıtlanmaz ama pending bir Dio timer'ı bırakır. Bir sonraki pump
    // network hatasını (bağlantı reddedildi) tetikleyip timer'ı temizler;
    // AppConfigRepository.fetch bunu zaten yutuyor (best-effort tasarım).
    await tester.pump(const Duration(seconds: 15));
  });
}
