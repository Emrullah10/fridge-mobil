import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../application/receipt_providers.dart';
import '../data/receipt_repository.dart';
import 'receipt_review_screen.dart';

final _receiptScansProvider = FutureProvider.family<List<ReceiptScanSummary>, String>(
  (ref, householdId) => ref.read(receiptRepositoryProvider).listScans(householdId),
);

/// Taranan tüm fişlerin geçmişi — özellikle inceleme yarım bırakılmış veya
/// bir sebeple ("başarısız" görünüp aslında backend'de tamamlanmış) erişimi
/// kaybedilmiş taramalara geri dönüş yolu sağlar.
class ReceiptHistoryScreen extends ConsumerWidget {
  const ReceiptHistoryScreen({super.key, required this.householdId});

  final String householdId;

  (IconData, Color, Color, String) _statusStyle(BuildContext context, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    return switch (status) {
      'review_pending' => (Icons.rate_review_rounded, colorScheme.primary, colorScheme.primaryContainer, 'İnceleme bekliyor'),
      'completed' => (Icons.check_circle_rounded, colorScheme.primary, colorScheme.surfaceContainerHighest, 'Tamamlandı'),
      'failed' => (Icons.error_outline_rounded, colorScheme.error, colorScheme.errorContainer, 'Başarısız'),
      _ => (Icons.hourglass_top_rounded, colorScheme.onSurfaceVariant, colorScheme.surfaceContainerHighest, 'İşleniyor'),
    };
  }

  Future<void> _retry(BuildContext context, WidgetRef ref, String scanId) async {
    try {
      await ref.read(receiptRepositoryProvider).retry(householdId, scanId);
      ref.invalidate(_receiptScansProvider(householdId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fiş yeniden işleniyor')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scansAsync = ref.watch(_receiptScansProvider(householdId));
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Fiş Geçmişi')),
      body: AsyncView(
        value: scansAsync,
        onRetry: () => ref.invalidate(_receiptScansProvider(householdId)),
        data: (scans) {
          if (scans.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_rounded,
              message: 'Henüz fiş taramadın',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_receiptScansProvider(householdId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: scans.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final scan = scans[index];
                final (icon, iconColor, badgeColor, label) = _statusStyle(context, scan.status);
                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    onTap: scan.status == 'review_pending' || scan.status == 'completed'
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ReceiptReviewScreen(
                                  householdId: householdId,
                                  scanId: scan.id,
                                ),
                              ),
                            );
                          }
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(icon, color: iconColor),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  scan.merchantName ?? 'Fiş',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  dateFormat.format(scan.createdAt.toLocal()),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: badgeColor,
                                  borderRadius: BorderRadius.circular(AppRadius.pill),
                                ),
                                child: Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: iconColor)),
                              ),
                              if (scan.status == 'failed') ...[
                                const SizedBox(height: AppSpacing.xs),
                                TextButton(
                                  onPressed: () => _retry(context, ref, scan.id),
                                  child: const Text('Tekrar dene'),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
