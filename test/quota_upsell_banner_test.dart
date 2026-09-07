import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fridge_mobil/features/billing/application/entitlements_providers.dart';
import 'package:fridge_mobil/features/billing/domain/entitlements.dart';
import 'package:fridge_mobil/features/billing/presentation/widgets/quota_upsell_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Entitlements withQuota(int used, int limit) => const Entitlements(
        plan: PlanTier.free,
        source: 'signup',
        status: 'active',
        features: {},
        quotas: {},
        households: {},
      ).copyWithQuota('recipe', AiQuota(limit: limit, used: used, boosted: false));

  Widget wrap(Entitlements entitlements) {
    SharedPreferences.setMockInitialValues({});
    return ProviderScope(
      overrides: [
        entitlementsProvider.overrideWithValue(entitlements),
      ],
      child: const MaterialApp(home: Scaffold(body: QuotaUpsellBanner(feature: 'recipe'))),
    );
  }

  testWidgets('kullanım %79 iken banner görünmez', (tester) async {
    await tester.pumpWidget(wrap(withQuota(11, 15))); // %73
    await tester.pumpAndSettle();
    expect(find.byType(QuotaUpsellBanner), findsOneWidget);
    expect(find.textContaining('kullandın'), findsNothing);
  });

  testWidgets('kullanım %80+ iken banner görünür', (tester) async {
    await tester.pumpWidget(wrap(withQuota(12, 15))); // %80
    await tester.pumpAndSettle();
    expect(find.text('12/15 kullandın'), findsOneWidget);
  });

  testWidgets('kota tamamen dolduğunda banner görünmez (402 sheet devreye girer)', (tester) async {
    await tester.pumpWidget(wrap(withQuota(15, 15)));
    await tester.pumpAndSettle();
    expect(find.textContaining('kullandın'), findsNothing);
  });

  testWidgets('sınırsız kotada banner hiç görünmez', (tester) async {
    const unlimited = Entitlements(
      plan: PlanTier.premium,
      source: 'signup',
      status: 'active',
      features: {},
      quotas: {'recipe': AiQuota(limit: null, used: 400, boosted: false)},
      households: {},
    );
    await tester.pumpWidget(wrap(unlimited));
    await tester.pumpAndSettle();
    expect(find.textContaining('kullandın'), findsNothing);
  });
}

extension on Entitlements {
  Entitlements copyWithQuota(String feature, AiQuota quota) => Entitlements(
        plan: plan,
        source: source,
        status: status,
        features: features,
        quotas: {...quotas, feature: quota},
        households: households,
        trialEndsAt: trialEndsAt,
        periodEndsAt: periodEndsAt,
        familySeat: familySeat,
        family: family,
      );
}
