import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../error/api_error.dart';
import '../theme/app_theme.dart';

/// AsyncValue.when'i her ekranda tekrar yazmamak için tek yer. loading ve
/// error durumlarının görünümü tüm ekranlarda birebir aynı olur.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Verilirse hata durumunda "Yeniden dene" butonu gösterilir.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: AppSpacing.sm),
              Text('Bir şeyler ters gitti', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                describeApiError(error),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Yeniden dene'),
                ),
              ],
            ],
          ),
        ),
      ),
      data: data,
    );
  }
}
