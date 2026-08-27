import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/product_repository.dart';

final productRepositoryProvider = Provider<ProductRepository>((ref) {
  return ProductRepository(ref.watch(apiClientProvider));
});

// Kategori sayısı sabit ve az (17), household değişmedikçe değişmez —
// fiş onay ekranındaki kategori dropdown'ı için önbelleklenir.
final productCategoriesProvider =
    FutureProvider.family<List<ProductCategory>, String>((ref, householdId) {
  return ref.watch(productRepositoryProvider).listCategories(householdId);
});
