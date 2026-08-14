import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../data/receipt_repository.dart';

final receiptRepositoryProvider = Provider<ReceiptRepository>((ref) {
  return ReceiptRepository(ref.watch(apiClientProvider));
});
