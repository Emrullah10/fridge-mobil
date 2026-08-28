import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/responsive.dart';
import '../../../core/widgets/storage_icon_box.dart';
import '../../../core/widgets/storage_kind.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../notification/application/notification_providers.dart';
import '../../notification/presentation/notifications_screen.dart';
import '../../onboarding/application/onboarding_providers.dart';
import '../../onboarding/presentation/spotlight/coach_tour.dart';
import '../../receipt/application/receipt_providers.dart';
import '../../receipt/presentation/receipt_history_screen.dart';
import 'household_members_screen.dart';
import '../../receipt/presentation/receipt_review_screen.dart';
import '../../receipt/presentation/receipt_scan_screen.dart';
import '../application/household_providers.dart';
import '../data/household_repository.dart';
import 'edit_storage_location_dialog.dart';

/// Spotlight turunun hedeflediği widget'lar. Aynı anda tek bir
/// HouseholdHomeScreen görünür olduğu için modül düzeyinde tutmak güvenli;
/// tur motoru bu key'lerin `currentContext`'inden ekran dikdörtgenini
/// hesaplar.
final scanFabKey = GlobalKey();
final firstStorageCardKey = GlobalKey();
final bottomNavKey = GlobalKey();

class HouseholdHomeScreen extends ConsumerWidget {
  const HouseholdHomeScreen({super.key, required this.household});

  final Household household;

  static const _inviteBaseUrl = 'https://api-fridge.emrullahbozkurt.com/join';

  String _formatCode(String code) => code.replaceAllMapped(
        RegExp(r'.{1,4}'),
        (match) => '${match.group(0)} ',
      ).trim();

  /// Kullanıcının household-profile.js'teki tür varsayımını elle ezmesi —
  /// ör. bir ofis alanında mutfak/tarif özelliklerini sonradan açabilir.
  Future<void> _toggleFoodFeature(BuildContext context, WidgetRef ref, Household household) async {
    final enable = !household.foodEnabled;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Yemek özellikleri'),
        content: Text(
          enable
              ? 'Tarifler, AI Chef ve son kullanma tarihi takibi bu alanda açılsın mı?'
              : 'Tarifler ve AI Chef bu alanda kapatılsın mı? Envanter ve alışveriş listesi etkilenmez.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(enable ? 'Aç' : 'Kapat'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(householdRepositoryProvider).updateFoodFeature(household.id, enable);
      ref.invalidate(householdsProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _showInviteCode(BuildContext context, WidgetRef ref) async {
    String? code;
    String? loadError;
    try {
      code = await ref.read(householdRepositoryProvider).createInvite(household.id);
    } catch (error) {
      loadError = describeApiError(error);
    }
    if (!context.mounted) return;

    if (loadError != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loadError)));
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) => _InviteCodeDialog(
        household: household,
        initialCode: code!,
        baseUrl: _inviteBaseUrl,
        formatCode: _formatCode,
        onRotate: (expiresInDays) => ref
            .read(householdRepositoryProvider)
            .rotateInvite(household.id, expiresInDays: expiresInDays),
      ),
    );
  }

  // Fiş taraması artık ekranı kilitlemiyor (bkz. receipt_scan_screen.dart) —
  // arka planda süren işi burada, ev ekranında bir banner ile gösteriyoruz.
  // İşleniyor/hazır/başarısız üç hali de kapsar; kullanıcı "Fiş Tara"ya
  // bastıktan sonra gezinmeye devam edebilir, sonucu buradan görür.
  Widget _buildPendingScanBanner(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingReceiptScanProvider(household.id));
    if (pending == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final notifier = ref.read(
      pendingReceiptScanProvider(household.id).notifier,
    );

    switch (pending.status) {
      case PendingScanStatus.processing:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: colorScheme.secondaryContainer,
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Fiş işleniyor...',
                style: TextStyle(color: colorScheme.onSecondaryContainer),
              ),
            ],
          ),
        );
      case PendingScanStatus.ready:
        return Material(
          color: colorScheme.primaryContainer,
          child: InkWell(
            onTap: () {
              Navigator.of(context)
                  .push<bool>(
                    MaterialPageRoute(
                      builder: (_) => ReceiptReviewScreen(
                        householdId: household.id,
                        scanId: pending.scanId,
                        lineItems: pending.result!.lineItems,
                      ),
                    ),
                  )
                  .then((confirmed) {
                    // Yalnızca kullanıcı gerçekten onaylarsa banner temizlenir
                    // ve kalıcı kayıt silinir — yarım bırakılıp geri çıkılırsa
                    // (geri tuşu, uygulamayı kapatma) tarama "review_pending"de
                    // asılı kalmamalı, banner bir sonraki açılışta da görünmeli.
                    if (confirmed == true) notifier.clear();
                  });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Fiş hazır — incelemek için dokun',
                      style: TextStyle(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ],
              ),
            ),
          ),
        );
      case PendingScanStatus.failed:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          color: colorScheme.errorContainer,
          child: Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Fiş işlenemedi',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
              TextButton(
                onPressed: notifier.clear,
                child: Text(
                  'Kapat',
                  style: TextStyle(color: colorScheme.onErrorContainer),
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _createLocation(BuildContext context, WidgetRef ref) async {
    final result = await showStorageLocationFormDialog(context);
    if (result == null) return;
    try {
      await ref.read(householdRepositoryProvider).createLocation(
            household.id,
            name: result.name,
            kind: result.kind,
            icon: result.icon,
          );
      ref.invalidate(storageLocationsProvider(household.id));
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _editLocation(BuildContext context, WidgetRef ref, StorageLocation location) async {
    final result = await showStorageLocationFormDialog(context, existing: location);
    if (result == null) return;
    try {
      final response = await ref.read(householdRepositoryProvider).updateLocation(
            household.id,
            location.id,
            name: result.name,
            kind: result.kind,
            icon: result.icon ?? '',
          );
      ref.invalidate(storageLocationsProvider(household.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${response.name} güncellendi')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  Future<void> _deleteLocation(BuildContext context, WidgetRef ref, StorageLocation location) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Bölümü Sil'),
        content: Text('"${location.name}" bölümünü silmek istediğine emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Sil', style: TextStyle(color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(householdRepositoryProvider);
    try {
      await repo.deleteLocation(household.id, location.id);
      ref.invalidate(storageLocationsProvider(household.id));
      return;
    } on Object catch (error) {
      final itemCount = _extractItemCount(error);
      if (itemCount == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
        }
        return;
      }
    }

    // Bölüm dolu (409) — kullanıcıya hedef bölüm seçtirip taşıma ile sil.
    if (!context.mounted) return;
    final locations = ref.read(storageLocationsProvider(household.id)).valueOrNull ?? [];
    final otherLocations = locations.where((l) => l.id != location.id).toList();
    if (otherLocations.isEmpty) return;

    final targetId = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text('"${location.name}" dolu — ürünleri nereye taşıyalım?'),
        children: [
          for (final target in otherLocations)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, target.id),
              child: Text(target.name),
            ),
        ],
      ),
    );
    if (targetId == null) return;

    try {
      await repo.deleteLocation(household.id, location.id, strategy: 'move', targetLocationId: targetId);
      ref.invalidate(storageLocationsProvider(household.id));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bölüm silindi, ürünler taşındı')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    }
  }

  int? _extractItemCount(Object error) {
    try {
      final data = (error as dynamic).response.data;
      if (data is Map && data['itemCount'] is int) return data['itemCount'] as int;
    } catch (_) {
      // response yoksa (ağ hatası vb.) itemCount de yok — null dön.
    }
    return null;
  }

  /// Alan ana ekranına ilk girişte çalışan spotlight turu — eski 4 kartlık
  /// AlertDialog'un yerini aldı. Yemek kapalı alanlarda (atölye/dükkan)
  /// Tarifler adımı yok; navbar hedefleri görünür sekme listesine göre
  /// hesaplanır (bkz. AppBottomNav._visibleItems).
  void _startCoachTour(BuildContext context, WidgetRef ref, {required bool foodEnabled}) {
    final scheme = Theme.of(context).colorScheme;
    final appColors = context.appColors;

    // Navbar'ın i. sekmesinin ekran dikdörtgeni: navbar'ın kendi RenderBox'ı
    // + eşit bölünmüş sekme genişliği (NavigationDestination'lara ayrı
    // GlobalKey verilemiyor).
    Rect navTabRect(int visibleIndex, int visibleCount) {
      final box = bottomNavKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        final size = MediaQuery.sizeOf(context);
        return Rect.fromLTWH(0, size.height - 64, size.width, 56);
      }
      final origin = box.localToGlobal(Offset.zero);
      final tabWidth = box.size.width / visibleCount;
      final cx = origin.dx + tabWidth * (visibleIndex + 0.5);
      final cy = origin.dy + box.size.height / 2;
      return Rect.fromCenter(center: Offset(cx, cy), width: tabWidth * 0.8, height: 40);
    }

    // Görünür sekmeler AppShell/AppBottomNav ile TEK kaynaktan (visibleTabsFor)
    // — elle tutulan ikinci bir liste, sıra kayması riskini taşırdı.
    final visibleTabs = visibleTabsFor(householdId: household.id, foodEnabled: foodEnabled);
    final shoppingIndex = visibleTabs.indexWhere((item) => item.tab == AppBottomTab.shopping);
    final insightsIndex = visibleTabs.indexWhere((item) => item.tab == AppBottomTab.insights);

    final steps = <CoachStep>[
      CoachStep(
        targetKey: scanFabKey,
        title: 'Fişini buradan tara',
        body: 'Market fişinin fotoğrafını çek — ürünler fiyatlarıyla envantere düşsün.',
        accent: scheme.primary,
      ),
      CoachStep(
        targetKey: firstStorageCardKey,
        title: 'Bölümlerin burada',
        body: 'Her bölüme dokunup içindeki ürünleri gör, ekle, tüket.',
        accent: appColors.storageFridge,
      ),
      CoachStep(
        rectResolver: (_) => navTabRect(shoppingIndex, visibleTabs.length),
        title: 'Alışveriş listesi',
        body: 'Eksikleri buradan yönet, markette işaretle, dönüşte envantere aktar.',
        accent: appColors.storageFreezer,
      ),
      CoachStep(
        rectResolver: (_) => navTabRect(insightsIndex, visibleTabs.length),
        title: 'Para ve israf',
        body: 'Ne biriktirdiğini, ne israf ettiğini ay ay buradan gör.',
        accent: appColors.storagePantry,
      ),
    ];

    showCoachTour(context, steps: steps, onFinished: () {});
  }

  Widget _buildLocationCard(BuildContext context, WidgetRef ref, StorageLocation location, {Key? cardKey}) {
    final style = storageKindStyle(context, location.kind, icon: location.icon);
    return Card(
      key: cardKey,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InventoryScreen(householdId: household.id, location: location),
          ),
        ),
        onLongPress: () => showModalBottomSheet<void>(
          context: context,
          builder: (sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Düzenle'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _editLocation(context, ref, location);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Theme.of(sheetContext).colorScheme.error),
                  title: Text('Sil', style: TextStyle(color: Theme.of(sheetContext).colorScheme.error)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _deleteLocation(context, ref, location);
                  },
                ),
              ],
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              StorageIconBox(icon: style.icon, color: style.color, size: 48, iconSize: 24),
              const SizedBox(height: AppSpacing.sm),
              Text(
                location.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // updateFoodFeature sonrası households listesi invalidate edilir —
    // ekran hâlâ açıksa güncel foodEnabled'ı burada yansıtır. Liste henüz
    // yenilenmediyse (ör. offline) constructor'dan gelen değere düşülür.
    final household = ref.watch(householdByIdProvider(this.household.id)) ?? this.household;
    final locationsAsync = ref.watch(storageLocationsProvider(household.id));

    // İlk kez bir alana giriliyorsa 4 kartlık tanıtımı göster. `seen == null`
    // henüz SharedPreferences okunmadığı anlamına gelir — o durumda hiçbir
    // şey yapılmaz (bir sonraki build'de `false`/`true` netleşir).
    final coachTourSeen = ref.watch(coachTourSeenProvider);
    if (coachTourSeen == false) {
      final foodEnabled = household.foodEnabled;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ref.read(coachTourSeenProvider.notifier).markSeen();
        _startCoachTour(context, ref, foodEnabled: foodEnabled);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(household.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Bölüm ekle',
            onPressed: () => _createLocation(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_rounded),
            tooltip: 'Fiş geçmişi',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReceiptHistoryScreen(householdId: household.id),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_outlined),
            tooltip: 'Üyeler',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HouseholdMembersScreen(household: household),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_add_alt_rounded),
            tooltip: 'Bu alana davet et',
            onPressed: () => _showInviteCode(context, ref),
          ),
          IconButton(
            icon: Icon(household.foodEnabled ? Icons.restaurant_rounded : Icons.restaurant_outlined),
            tooltip: 'Yemek özellikleri',
            onPressed: () => _toggleFoodFeature(context, ref, household),
          ),
          Consumer(
            builder: (context, ref, _) {
              final unreadCount = ref.watch(notificationListProvider).valueOrNull?.unreadCount ?? 0;
              return IconButton(
                icon: Badge(
                  label: Text('$unreadCount'),
                  isLabelVisible: unreadCount > 0,
                  child: const Icon(Icons.notifications_outlined),
                ),
                tooltip: 'Bildirimler',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                ),
              );
            },
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: Column(
        children: [
          _buildPendingScanBanner(context, ref),
          Expanded(
            child: AsyncView(
              value: locationsAsync,
              onRetry: () => ref.invalidate(storageLocationsProvider(household.id)),
              data: (locations) {
                if (locations.isEmpty) {
                  return const EmptyState(
                    icon: Icons.category_rounded,
                    message: 'Bu alanda henüz bir depolama bölümü yok.',
                  );
                }
                return LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = gridColumnsFor(constraints.maxWidth);
                    // Tek sayıda kart varsa son kart iki sütun genişliğinde
                    // gösterilir (Stitch'in Ev Ana tasarımındaki Kiler kartı).
                    final hasDanglingLast = locations.length.isOdd && locations.length > 1 && columns == 2;
                    final gridCount = hasDanglingLast ? locations.length - 1 : locations.length;

                    return CustomScrollView(
                      slivers: [
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                          sliver: SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: columns,
                              mainAxisSpacing: AppSpacing.sm,
                              crossAxisSpacing: AppSpacing.sm,
                              childAspectRatio: 1.1,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildLocationCard(
                                context,
                                ref,
                                locations[index],
                                cardKey: index == 0 ? firstStorageCardKey : null,
                              ),
                              childCount: gridCount,
                            ),
                          ),
                        ),
                        if (hasDanglingLast)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                            sliver: SliverToBoxAdapter(
                              child: SizedBox(
                                height: constraints.maxWidth / columns / 1.1,
                                child: _buildLocationCard(context, ref, locations.last),
                              ),
                            ),
                          ),
                        SliverToBoxAdapter(
                          child: SizedBox(height: AppSpacing.fabBottomPadding),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: scanFabKey,
        icon: const Icon(Icons.document_scanner_rounded),
        label: const Text('Fiş Tara'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ReceiptScanScreen(householdId: household.id),
          ),
        ),
      ),
    );
  }
}

/// Davet kodu dialogu — süre seçimi ve "Kodu yenile" içerdiği için ayrı bir
/// StatefulWidget: her yenilemede kod değişip dialogun kendi state'ini
/// güncellemesi (parent'ı yeniden build etmeden) gerekiyor.
class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog({
    required this.household,
    required this.initialCode,
    required this.baseUrl,
    required this.formatCode,
    required this.onRotate,
  });

  final Household household;
  final String initialCode;
  final String baseUrl;
  final String Function(String code) formatCode;
  final Future<String> Function(int? expiresInDays) onRotate;

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  late String _code = widget.initialCode;
  // null = süresiz (backend varsayılanı).
  int? _expiresInDays;
  bool _rotating = false;

  String get _link => '${widget.baseUrl}/$_code';

  Future<void> _rotate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kodu yenile?'),
        content: const Text('Eski kod artık çalışmaz. Bu kodu daha önce paylaştığın kişiler yeni kodu almadan katılamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Yenile')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _rotating = true);
    try {
      final newCode = await widget.onRotate(_expiresInDays);
      if (mounted) setState(() => _code = newCode);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _rotating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Davet Kodu'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bu kod alan için sabittir — istediğin kadar kişi aynı kodla katılabilir.'),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.input),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: _code));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kod kopyalandı')));
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.input),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.formatCode(_code),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(letterSpacing: 1),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.copy_rounded, size: 18, color: colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Kodun süresi', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final option in const [
                (null, 'Süresiz'),
                (1, '1 gün'),
                (7, '7 gün'),
                (30, '30 gün'),
              ])
                ChoiceChip(
                  label: Text(option.$2),
                  selected: _expiresInDays == option.$1,
                  onSelected: (_) => setState(() => _expiresInDays = option.$1),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _rotating ? null : _rotate,
              icon: _rotating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Kodu yenile'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () => Share.share(
            '${widget.household.name} alanıma katıl! Davet kodu: $_code\n$_link',
          ),
          icon: const Icon(Icons.share_rounded, size: 18),
          label: const Text('Paylaş'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}
