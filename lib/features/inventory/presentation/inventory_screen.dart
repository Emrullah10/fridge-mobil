import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/haptics.dart';
import '../../../core/ui/app_number_field.dart';
import '../../../core/ui/app_segmented.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/validation/validators.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/unit_label.dart';
import '../../chef/presentation/chef_chat_screen.dart';
import '../../household/application/household_providers.dart';
import '../../household/data/household_repository.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../onboarding/presentation/spotlight/coach_tour.dart';
import '../../onboarding/presentation/spotlight/coach_tour_launcher.dart';
import '../application/inventory_providers.dart';
import '../data/inventory_repository.dart';
import 'add_inventory_item_screen.dart';

/// Envanter turunun hedefledikleri — aynı anda tek InventoryScreen görünür.
final inventoryAddFabKey = GlobalKey();
final inventoryChefKey = GlobalKey();
final inventoryExpiryKey = GlobalKey();

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({
    super.key,
    required this.householdId,
    required this.location,
  });

  final String householdId;
  final StorageLocation location;

  List<CoachStep> _coachSteps(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return [
      CoachStep(
        targetKey: inventoryAddFabKey,
        title: 'Ürün ekle',
        body:
            'Fiş taramadan da ekleyebilirsin — isim, miktar ve son kullanma tarihi yeter.',
        accent: scheme.primary,
      ),
      CoachStep(
        targetKey: inventoryExpiryKey,
        optional: true,
        title: 'Tarihi yaklaşanlar',
        body:
            'Son kullanma tarihi 3 günden yakınsa turuncu, geçtiyse kırmızı görürsün.',
        accent: context.appColors.statusWarning,
      ),
      CoachStep(
        targetKey: inventoryChefKey,
        optional: true,
        title: 'Elindekiyle pişir',
        body:
            'AI Chef’e sor — tarihi yaklaşan ürünlerle ne yapabileceğini söylesin.',
        accent: scheme.tertiary,
      ),
    ];
  }

  Future<void> _consume(
    BuildContext context,
    WidgetRef ref,
    InventoryItem item,
  ) async {
    final result = await showAppSheet<_ConsumeResult>(
      context,
      builder: (_, __) => _ConsumeSheet(item: item),
    );
    if (result == null) return;

    final params = InventoryParams(
      householdId: householdId,
      storageLocationId: location.id,
    );
    try {
      await ref
          .read(inventoryRepositoryProvider)
          .consume(householdId, item.id, result.amount, reason: result.reason);
      ref.invalidate(inventoryItemsProvider(params));
      AppHaptics.success();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  /// Son kullanma tarihi yaklaşanları (3 gün içinde) turuncu, geçmişleri
  /// kırmızı, uzak/yoksa nötr renkte gösterir — envanteri tararken göz
  /// bir bakışta hangi ürünün acele istediğini yakalar.
  Color? _expiryColor(BuildContext context, DateTime? expiresAt) {
    if (expiresAt == null) return null;
    final daysLeft = expiresAt.difference(DateTime.now()).inDays;
    if (daysLeft < 0) return Theme.of(context).colorScheme.error;
    if (daysLeft <= 3) return context.appColors.statusWarning;
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final params = InventoryParams(
      householdId: householdId,
      storageLocationId: location.id,
    );
    final itemsAsync = ref.watch(inventoryItemsProvider(params));
    final dateFormat = DateFormat('dd.MM.yyyy');
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    // Yemek özelliği kapalı alanlarda (atölye/dükkan vb.) AI Chef anlamsız —
    // bkz. app_bottom_nav.dart'taki aynı gating.
    final foodEnabled =
        ref.watch(householdByIdProvider(householdId))?.foodEnabled ?? true;

    maybeStartCoachTour(
      context,
      ref,
      id: CoachTourId.inventory,
      buildSteps: () => _coachSteps(context),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(location.name),
        actions: [
          if (foodEnabled)
            IconButton(
              key: inventoryChefKey,
              tooltip: 'AI Chef’e sor',
              icon: const Icon(Icons.auto_awesome_rounded),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChefChatScreen(
                    householdId: householdId,
                    seedPrompt:
                        'Son kullanma tarihi yaklaşanlarla ne pişirebilirim?',
                  ),
                ),
              ),
            ),
        ],
      ),
      body: AsyncView(
        value: itemsAsync,
        onRetry: () => ref.invalidate(inventoryItemsProvider(params)),
        data: (items) {
          Future<void> onRefresh() async {
            ref.invalidate(inventoryItemsProvider(params));
            await ref.read(inventoryItemsProvider(params).future);
          }

          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: onRefresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.6,
                    child: EmptyState(
                      icon: Icons.inventory_2_outlined,
                      message:
                          'Bu bölüm boş.\nFiş tarayarak veya elle ekleyerek doldurabilirsin.',
                      action: FilledButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Ürün Ekle'),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AddInventoryItemScreen(
                              householdId: householdId,
                              storageLocationId: location.id,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          // Biten ürünler (miktar 0) kaydı silinmediği için listede kalır —
          // aynı ürün tekrar alındığında backend var olan satırın üstüne
          // ekler, böylece SKT/not ve stok geçmişi korunur. Kullanıcıyı
          // şaşırtmamak için bunları listenin dibine alıp soluklaştırıyoruz.
          final sorted = [...items]
            ..sort((a, b) {
              final aEmpty = a.quantity <= 0;
              final bEmpty = b.quantity <= 0;
              if (aEmpty == bEmpty) return 0;
              return aEmpty ? 1 : -1;
            });
          // Coach tour SKT adımı: ilk SKT'li (ve bitmemiş) satıra key ver.
          final expiryRowIndex = sorted.indexWhere(
            (i) => i.quantity > 0 && i.expiresAt != null,
          );

          return RefreshIndicator(
            onRefresh: onRefresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.fabBottomPadding,
              ),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final InventoryItem item = sorted[index];
                final isEmpty = item.quantity <= 0;
                final expiryColor = isEmpty
                    ? null
                    : _expiryColor(context, item.expiresAt);

                return Card(
                  // Bitmiş ürün kartını Opacity ile soluklaştırmak üzerindeki
                  // metni de (onSurfaceVariant zaten sınırda bir kontrasta
                  // sahip) WCAG AA'nın altına düşürür — bkz. cerebrum
                  // 2026-08-29, web maketlerinde aynı hata bulunup düzeltilmişti.
                  // Bunun yerine yalnızca ZEMİN yüzeye karıştırılır, metin
                  // rengi sabit token'da kalır; "bitmişlik" hissini lineThrough
                  // + "Bitti" rozeti + kapalı tüket butonu zaten veriyor.
                  color: isEmpty
                      ? Color.alphaBlend(
                          colorScheme.surface.withValues(alpha: 0.55),
                          colorScheme.surfaceContainerLow,
                        )
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.productName,
                                style: textTheme.titleSmall?.copyWith(
                                  decoration: isEmpty
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isEmpty
                                      ? colorScheme.onSurfaceVariant
                                      : null,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  if (isEmpty)
                                    const AppBadge(label: 'Bitti')
                                  else
                                    AppBadge(
                                      label:
                                          '${item.quantity} ${unitLabel(item.unit)}',
                                      variant: AppBadgeVariant.quantity,
                                    ),
                                  // Fiyat OCR/AI'dan hiç gelmemiş olabilir —
                                  // o durumda rozet hiç gösterilmez.
                                  if (item.unitPrice != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    AppBadge(
                                      label:
                                          '₺${item.unitPrice!.toStringAsFixed(2)}',
                                    ),
                                  ],
                                  if (!isEmpty && item.expiresAt != null) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Row(
                                      key: index == expiryRowIndex
                                          ? inventoryExpiryKey
                                          : null,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.event_rounded,
                                          size: 14,
                                          color:
                                              expiryColor ??
                                              colorScheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          'SKT: ${dateFormat.format(item.expiresAt!)}',
                                          style: textTheme.bodySmall?.copyWith(
                                            color:
                                                expiryColor ??
                                                colorScheme.onSurfaceVariant,
                                            fontWeight: expiryColor != null
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                          tooltip: isEmpty ? 'Ürün bitti' : 'Tüket',
                          // Miktar 0'ken tüketmeye çalışmak backend'den
                          // InsufficientStockError döndürür — butonu baştan kapatıyoruz.
                          onPressed: isEmpty
                              ? null
                              : () => _consume(context, ref, item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        key: inventoryAddFabKey,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddInventoryItemScreen(
              householdId: householdId,
              storageLocationId: location.id,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ConsumeResult {
  const _ConsumeResult({required this.amount, required this.reason});
  final double amount;
  final String reason;
}

/// "Bu üründen ne oldu?" sheet'i — eskiden AlertDialog'du, `SegmentedButton`
/// + canlı doğrulama bir dialog sınırına sıkışıyordu ve iOS'ta yabancı
/// duruyordu (bkz. AppSegmented: iOS'ta CupertinoSlidingSegmentedControl).
///
/// reason ayrımı para & israf paneli için kritik: 'consumed' -> "kurtarılan
/// para", 'discarded'/'expired' -> "israf". Girilen miktar eldekini aşarsa
/// backend InsufficientStockError döner, o yüzden hem "Tamamı" kısayolu hem
/// de anlık doğrulama var.
class _ConsumeSheet extends StatefulWidget {
  const _ConsumeSheet({required this.item});

  final InventoryItem item;

  @override
  State<_ConsumeSheet> createState() => _ConsumeSheetState();
}

class _ConsumeSheetState extends State<_ConsumeSheet> {
  late final TextEditingController _controller;
  String _reason = 'consumed';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double? _parsedAmount(String text) => Validators.parseDecimal(text);

  bool _isValid(double? parsed) =>
      parsed != null && parsed > 0 && parsed <= widget.item.quantity;

  void _confirmWith(double amount) {
    Navigator.pop(context, _ConsumeResult(amount: amount, reason: _reason));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controller,
      builder: (_, value, _) {
        final parsed = _parsedAmount(value.text);
        final valid = _isValid(parsed);
        return AppSheetScaffold(
          title: 'Bu üründen ne oldu?',
          onClose: () => Navigator.pop(context),
          onConfirm: valid ? () => _confirmWith(parsed!) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSegmented<String>(
                options: const [
                  AppSegmentedOption(
                    value: 'consumed',
                    label: 'Kullandım',
                    icon: Icons.restaurant_rounded,
                  ),
                  AppSegmentedOption(
                    value: 'discarded',
                    label: 'Bozuldu',
                    icon: Icons.delete_outline_rounded,
                  ),
                ],
                selected: _reason,
                onChanged: (value) => setState(() => _reason = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Elinde ${item.quantity} ${unitLabel(item.unit)} var.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppNumberField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (text) {
                  final parsedValue = _parsedAmount(text);
                  if (_isValid(parsedValue)) _confirmWith(parsedValue!);
                },
                decoration: InputDecoration(
                  suffixText: unitLabel(item.unit),
                  errorText: (parsed != null && parsed > item.quantity)
                      ? 'Elindekinden fazla'
                      : null,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextButton.icon(
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(
                  _reason == 'consumed'
                      ? 'Tamamı kullanıldı'
                      : 'Tamamı bozuldu',
                ),
                onPressed: () => _confirmWith(item.quantity),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: valid ? () => _confirmWith(parsed!) : null,
                  child: const Text('Onayla'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
