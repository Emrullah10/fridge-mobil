import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart';

/// AsyncValue.when'i her ekranda tekrar yazmamak için tek yer. loading ve
/// error durumlarının görünümü tüm ekranlarda birebir aynı olur.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.emptyCheck});

  final AsyncValue<T> value;
  final Widget Function(T data) data;

  /// Örn. liste boşsa true dönen bir kontrol — verilirse boş durum yerine
  /// çağıran widget kendi EmptyState'ini data() içinde gösterebilir.
  final bool Function(T data)? emptyCheck;

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
              const Text('Bir şeyler ters gitti', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
      data: data,
    );
  }
}
