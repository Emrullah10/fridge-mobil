import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_badge.dart';
import '../../../core/widgets/async_view.dart';
import '../../../core/widgets/button_progress.dart';
import '../../../core/widgets/storage_icon_box.dart';
import '../../../core/widgets/storage_kind.dart';
import '../../../core/widgets/unit_label.dart';
import '../../household/application/household_providers.dart';
import '../../household/data/household_repository.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../product/application/product_providers.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../application/receipt_providers.dart';
import '../data/receipt_repository.dart';

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.householdId,
    required this.scanId,
    this.lineItems,
  });

  final String householdId;
  final String scanId;
  // Bildirimden veya fiş geçmişinden scanId ile açılırken null gelir —
  // ekran kendi GET /:scanId ile satırları çeker (bkz. initState).
  final List<ReceiptLineItem>? lineItems;

  @override
  ConsumerState<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  List<ReceiptLineItem> _items = [];
  bool _loadingItems = false;
  Object? _loadError;
  // Eşleşmemiş satırlar hiçbir zaman kalmıyor (AI otomatik ürün oluşturuyor),
  // ama düşük güvenli satırları varsayılan seçili göndermek riskli — kullanıcı
  // önce göz atmalı. Sadece yüksek güvenli (alias/trigram) satırlar baştan seçili.
  late final Set<String> _selectedIds =
      _items.where((i) => i.isHighConfidence).map((i) => i.id).toSet();
  final Map<String, DateTime?> _expiresAtByItemId = {};
  // itemId -> locationId. null = bölüm belirsiz, kullanıcı seçmeli (backend
  // kategori bulamadıysa suggestedStorageKind de null gelir, bkz.
  // storage-suggestion.js). İlk dolum _initializeSuggestedLocations'ta olur.
  final Map<String, String?> _locationIdByItemId = {};
  bool _locationsInitialized = false;
  bool _isConfirming = false;
  // Fişin tamamı için okunan toplam tutar — satır fiyatları toplamıyla
  // karşılaştırılıp kullanıcıya eksik fiyatlı satır varsa gösterilir.
  double? _scanTotalAmount;
  // Sürükleme sürüyor mu — alt bırakma çubuğunu sadece bu sırada göster,
  // aksi halde ekranda gereksiz yer kaplamasın.
  bool _isDragging = false;
  // Sürüklenen kartın üstünde durulan hedef bölüm (vurgu için).
  String? _dragHoverLocationId;
  // "Belirsiz" (bölüm ataması kaldır) hedefi gerçek bir storage location id'si
  // değil — locationId'lerle çakışmayacak sabit bir sentinel.
  static const _unassignedDropId = '__unassigned__';

  @override
  void initState() {
    super.initState();
    if (widget.lineItems != null) {
      _items = List.of(widget.lineItems!);
    } else {
      _fetchItems();
    }
    // Sürükle-bırak keşfedilebilir değil (uzun basış görsel bir ipucu
    // vermiyor) — ekran ilk açıldığında bir kez kısa bir tüyo göster.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('İpucu: bir ürünü uzun basıp bölüme sürükleyebilirsin'),
          duration: Duration(seconds: 3),
        ),
      );
    });
  }

  Future<void> _fetchItems() async {
    setState(() {
      _loadingItems = true;
      _loadError = null;
    });
    try {
      final result = await ref
          .read(receiptRepositoryProvider)
          .getScan(widget.householdId, widget.scanId);
      if (!mounted) return;
      setState(() {
        _items = result.lineItems;
        _scanTotalAmount = result.totalAmount;
        _loadingItems = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _loadingItems = false;
      });
    }
  }

  // locations her build'de aynı referansla gelmeyebilir ama sadece BİR kere
  // öneriden doldurmak istiyoruz — aksi halde kullanıcının elle seçtiği
  // bölüm bir sonraki rebuild'de öneriyle ezilir.
  void _initializeSuggestedLocations(List<StorageLocation> locations) {
    if (_locationsInitialized) return;
    _locationsInitialized = true;
    for (final item in _items) {
      final suggested = item.suggestedStorageKind;
      final match = suggested == null ? null : locations.where((l) => l.kind == suggested).firstOrNull;
      _locationIdByItemId[item.id] = match?.id;
    }
  }

  Future<void> _editItem(ReceiptLineItem item) async {
    final nameController = TextEditingController(text: item.parsedName);
    final brandController = TextEditingController(text: item.parsedBrand ?? '');
    final quantityController = TextEditingController(text: item.parsedQuantity.toString());
    final packSizeController = TextEditingController(text: item.parsedPackSize?.toString() ?? '');
    final priceController = TextEditingController(text: item.parsedPrice?.toString() ?? '');
    String selectedProductId = item.matchedProductId!;
    String selectedProductName = item.parsedName;
    String? selectedLocationId = _locationIdByItemId[item.id];
    String selectedUnit = item.parsedUnit;
    String? selectedCategoryKey;
    String selectedPackUnit = item.parsedPackUnit ?? 'milliliter';
    final locations = ref.read(storageLocationsProvider(widget.householdId)).valueOrNull ?? [];
    final categories = ref.read(productCategoriesProvider(widget.householdId)).valueOrNull ?? [];

    final edited = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Satırı Düzelt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Fişte yazan: "${item.rawText}"', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: selectedLocationId,
                decoration: const InputDecoration(labelText: 'Bölüm', prefixIcon: Icon(Icons.kitchen_rounded)),
                hint: const Text('Bölüm seç'),
                items: [
                  for (final location in locations)
                    DropdownMenuItem(value: location.id, child: Text(location.name)),
                ],
                onChanged: (value) => setDialogState(() => selectedLocationId = value),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton.icon(
                icon: const Icon(Icons.search_rounded),
                label: Text(selectedProductName),
                onPressed: () async {
                  final picked = await showProductPicker(context, householdId: widget.householdId);
                  if (picked != null) {
                    setDialogState(() {
                      selectedProductId = picked.id;
                      selectedProductName = picked.canonicalName;
                      nameController.text = picked.canonicalName;
                    });
                  }
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Ürün adı')),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: brandController,
                decoration: const InputDecoration(
                  labelText: 'Marka (opsiyonel)',
                  helperText: 'Girdiğin marka bir daha hatırlanır',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: quantityController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Miktar'),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: selectedUnit,
                decoration: const InputDecoration(labelText: 'Birim'),
                items: [
                  for (final unit in unitOptions)
                    DropdownMenuItem(value: unit, child: Text(unitLabel(unit))),
                ],
                onChanged: (value) {
                  if (value != null) setDialogState(() => selectedUnit = value);
                },
              ),
              if (selectedUnit == 'piece') ...[
                const SizedBox(height: AppSpacing.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: packSizeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Paket boyutu (opsiyonel)',
                          helperText: 'örn. 6 adet × 200 ml için 200 yaz',
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedPackUnit,
                        decoration: const InputDecoration(labelText: 'Birim'),
                        items: [
                          for (final unit in unitOptions.where((u) => u != 'piece'))
                            DropdownMenuItem(value: unit, child: Text(unitShortLabel(unit))),
                        ],
                        onChanged: (value) {
                          if (value != null) setDialogState(() => selectedPackUnit = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: priceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Fiyat (opsiyonel)',
                  prefixText: '₺ ',
                  helperText: 'Satırın fiş üzerindeki toplam tutarı',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: selectedCategoryKey,
                decoration: const InputDecoration(
                  labelText: 'Kategori (opsiyonel)',
                  helperText: 'Doğru kategori tarif önerilerini iyileştirir',
                ),
                hint: const Text('Kategori seç'),
                items: [
                  for (final category in categories)
                    DropdownMenuItem(value: category.key, child: Text(category.nameTr)),
                ],
                onChanged: (value) => setDialogState(() => selectedCategoryKey = value),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );

    if (edited != true || !mounted) return;

    final newName = nameController.text.trim();
    final newBrand = brandController.text.trim();
    final newQuantity = double.tryParse(quantityController.text) ?? item.parsedQuantity;
    // Paket boyutu yalnızca 'piece' birimi için anlamlı — birim değiştiyse
    // veya alan boş bırakıldıysa null gönderilir (paket bilgisi silinir).
    final newPackSize = selectedUnit == 'piece' ? double.tryParse(packSizeController.text) : null;
    final newPackUnit = newPackSize != null ? selectedPackUnit : null;
    final priceText = priceController.text.trim().replaceAll(',', '.');
    final newPrice = priceText.isEmpty ? null : double.tryParse(priceText);

    try {
      await ref.read(receiptRepositoryProvider).correctLineItem(
            widget.householdId,
            widget.scanId,
            item.id,
            parsedName: newName,
            parsedBrand: newBrand.isEmpty ? null : newBrand,
            parsedQuantity: newQuantity,
            parsedUnit: selectedUnit,
            parsedPackSize: newPackSize,
            parsedPackUnit: newPackUnit,
            parsedPrice: newPrice,
            matchedProductId: selectedProductId,
            categoryKey: selectedCategoryKey,
          );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
      return; // Sunucu güncellemesi başarısızsa lokal state'i değiştirme.
    }

    setState(() {
      final index = _items.indexWhere((i) => i.id == item.id);
      _items[index] = ReceiptLineItem(
        id: item.id,
        rawText: item.rawText,
        parsedName: newName,
        parsedBrand: newBrand.isEmpty ? null : newBrand,
        parsedQuantity: newQuantity,
        parsedUnit: selectedUnit,
        parsedPackSize: newPackSize,
        parsedPackUnit: newPackUnit,
        parsedPrice: newPrice,
        matchedProductId: selectedProductId,
        matchMethod: 'manual',
        confidence: 1.0,
        suggestedStorageKind: item.suggestedStorageKind,
      );
      // Bölüm seçimi backend'e gitmez (correctLineItem bunu bilmiyor) —
      // sadece confirm anında gönderilecek lokal state.
      _locationIdByItemId[item.id] = selectedLocationId;
      _selectedIds.add(item.id); // Kullanıcı düzelttiyse artık güveniyoruz demektir.
    });
  }

  // Sürükle-bırak ile bölüm atama — _editItem'daki dropdown'ın (L173-174)
  // aynı etkisi, ama sunucuda correctLineItem çağrısı OLMADAN: sürüklemek
  // sadece yerel state değiştirir, ürün adını/markasını düzeltmez.
  void _assignLocation(String itemId, String locationId) {
    setState(() {
      _locationIdByItemId[itemId] = locationId;
      _selectedIds.add(itemId);
    });
  }

  Future<void> _pickExpiryDate(String itemId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );
    if (picked != null) setState(() => _expiresAtByItemId[itemId] = picked);
  }

  Future<void> _confirm() async {
    final selectedItems = _items.where((i) => _selectedIds.contains(i.id)).toList();
    final missingLocation = selectedItems.where((i) => _locationIdByItemId[i.id] == null).isNotEmpty;
    if (missingLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bölümü belirsiz ürünler var — her ürün için bir bölüm seç')),
      );
      return;
    }

    final locations = ref.read(storageLocationsProvider(widget.householdId)).valueOrNull ?? [];
    final locationIdByItemId = {
      for (final item in selectedItems) item.id: _locationIdByItemId[item.id]!,
    };

    // Onay mesajında hangi bölüme kaç ürün gittiğini göstermek için grupla.
    final countByLocationId = <String, int>{};
    for (final locationId in locationIdByItemId.values) {
      countByLocationId[locationId] = (countByLocationId[locationId] ?? 0) + 1;
    }
    final summary = countByLocationId.entries
        .map((e) {
          final name = locations.where((l) => l.id == e.key).map((l) => l.name).firstOrNull;
          return '${e.value} ürün${name != null ? " $name'a" : ""}';
        })
        .join(', ');

    setState(() => _isConfirming = true);
    try {
      await ref.read(receiptRepositoryProvider).confirm(
            widget.householdId,
            widget.scanId,
            locationIdByItemId: locationIdByItemId,
            items: selectedItems,
            expiresAtByItemId: _expiresAtByItemId,
          );
      // Onaydan sonra ürünler DB'ye yazılıyor ama envanter ekranı hâlâ eski
      // (invalidate edilmemiş) provider örneğini gösteriyordu — sessizce
      // "eklenmedi" gibi görünüyordu. Hem etkilenen her bölümün hem
      // household-geneli önbelleği tazeliyoruz ki nereden bakılırsa
      // bakılsın güncel gelsin.
      for (final locationId in countByLocationId.keys) {
        ref.invalidate(inventoryItemsProvider(InventoryParams(householdId: widget.householdId, storageLocationId: locationId)));
      }
      ref.invalidate(inventoryItemsProvider(InventoryParams(householdId: widget.householdId)));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$summary eklendi')));
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  /// Kalemlerin fiyat toplamı ile fişin toplamını (receipt_scan.total_amount,
  /// TOPLAM satırından deterministik okunur) yan yana gösterir — sapma varsa
  /// kullanıcı hangi satırların fiyatsız kaldığını fark edip düzeltebilir.
  Widget _buildPriceComparisonBar(ColorScheme colorScheme) {
    final itemsTotal = _items.fold<double>(0, (sum, item) => sum + (item.parsedPrice ?? 0));
    final missingPriceCount = _items.where((item) => item.parsedPrice == null).length;
    final total = _scanTotalAmount!;
    final mismatch = missingPriceCount > 0 || (total - itemsTotal).abs() > 0.5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: mismatch ? colorScheme.errorContainer.withValues(alpha: 0.4) : colorScheme.surfaceContainerHigh,
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Kalemler ₺${itemsTotal.toStringAsFixed(2)} · Fiş ₺${total.toStringAsFixed(2)}'
              '${missingPriceCount > 0 ? ' · $missingPriceCount fiyatsız' : ''}',
              style: TextStyle(
                color: mismatch ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(
    ReceiptLineItem item, {
    required DateFormat dateFormat,
    required ColorScheme colorScheme,
    required bool locationMissing,
  }) {
    final isSelected = _selectedIds.contains(item.id);
    final expiresAt = _expiresAtByItemId[item.id];
    final textTheme = Theme.of(context).textTheme;
    final card = Card(
      child: Column(
        children: [
          CheckboxListTile(
            value: isSelected,
            onChanged: (checked) => setState(() {
              if (checked == true) {
                _selectedIds.add(item.id);
              } else {
                _selectedIds.remove(item.id);
              }
            }),
            title: Text(item.parsedName, style: textTheme.titleSmall),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.sm,
                    children: [
                      Text(item.parsedPackSize != null
                          ? '${item.parsedQuantity.toStringAsFixed(0)} adet × ${item.parsedPackSize} ${unitShortLabel(item.parsedPackUnit!)}'
                          : '${item.parsedQuantity} ${unitLabel(item.parsedUnit)}'),
                      if (item.parsedBrand != null) AppBadge(label: item.parsedBrand!),
                      // Fiyat OCR/AI tarafından yakalanamayabilir — o zaman
                      // rozet hiç gösterilmez, "₺0" gibi yanlış bir sinyal
                      // verilmez. Kullanıcı kalem ikonuyla elle girebilir.
                      if (item.parsedPrice != null) AppBadge(label: '₺${item.parsedPrice!.toStringAsFixed(2)}'),
                      if (!item.isHighConfidence)
                        const AppBadge(label: 'Kontrol et', variant: AppBadgeVariant.warning),
                    ],
                  ),
                  // Fişteki ham metin: AI'ın çevirisini doğrulamak için
                  // kullanıcının yanına koyduğumuz referans.
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(item.rawText, style: textTheme.bodySmall),
                  ),
                ],
              ),
            ),
            secondary: IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Düzelt',
              onPressed: () => _editItem(item),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.event_rounded, size: 16),
                      label: Text(
                        expiresAt != null
                            ? 'SKT: ${dateFormat.format(expiresAt)}'
                            : 'SKT ekle (opsiyonel)',
                      ),
                      onPressed: () => _pickExpiryDate(item.id),
                    ),
                  ),
                ),
                // Bölümü belirsiz ürünlerde göze çarpan bir kısayol —
                // kullanıcı hangi ürünün bölüm beklediğini hemen görsün.
                if (locationMissing)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.push_pin_outlined, size: 16),
                    label: const Text('Bölüm seç'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      // Tema minimumSize'ı Size.fromHeight(52) = sonsuz
                      // genişlik demek; Column içinde sorun çıkarmıyor ama
                      // bu buton doğrudan bir Row çocuğu (Row sınırsız
                      // genişlik kısıtı verir) — sonsuz minimum asla
                      // çözülemeyip layout'u çökertiyordu. Bu kullanım için
                      // ezip içeriğe göre daralmasını sağlıyoruz.
                      minimumSize: const Size(0, 40),
                    ),
                    onPressed: () => _editItem(item),
                  ),
              ],
            ),
          ),
        ],
      ),
    );

    // CheckboxListTile zaten tap'i tüketiyor, uzun basış boştaydı — kartı
    // uzun basıp sürükleyerek doğrudan bir bölüm başlığına bırakmak,
    // "kalem ikonu -> dialog -> dropdown" akışına kısayol sağlar.
    return LongPressDraggable<String>(
      data: item.id,
      onDragStarted: () => setState(() => _isDragging = true),
      onDragEnd: (_) => setState(() {
        _isDragging = false;
        _dragHoverLocationId = null;
      }),
      feedback: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SizedBox(
          width: MediaQuery.of(context).size.width - AppSpacing.md * 2,
          child: Opacity(opacity: 0.9, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: card,
    );
  }

  /// Bölüm bazlı gruplama başlığı + ürün kartları. `location` verilmezse
  /// "bölüm seçilmedi" uyarı grubu çizilir (eski _buildUnresolvedSection'ın
  /// yerine geçen tek parametrik hâli).
  List<Widget> _buildSection({
    StorageLocation? location,
    required List<ReceiptLineItem> items,
    required DateFormat dateFormat,
    required ColorScheme colorScheme,
  }) {
    if (items.isEmpty) return const [];
    final icon = location == null ? Icons.help_outline_rounded : storageKindStyle(context, location.kind).icon;
    final color = location == null ? colorScheme.error : storageKindStyle(context, location.kind).color;
    final title = location == null
        ? 'BÖLÜM SEÇİLMEDİ · ${items.length} ürün'
        : '${location.name.toUpperCase()} · ${items.length} ürün';

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.md, AppSpacing.xs, AppSpacing.xs),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: AppSpacing.xs),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
      for (final item in items) ...[
        _buildItemCard(item, dateFormat: dateFormat, colorScheme: colorScheme, locationMissing: location == null),
        const SizedBox(height: AppSpacing.xs),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(storageLocationsProvider(widget.householdId));
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd.MM.yyyy');

    if (_loadingItems) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fişi Onayla')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_loadError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fişi Onayla')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(describeApiError(_loadError!)),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(onPressed: _fetchItems, child: const Text('Tekrar dene')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Fişi Onayla')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Text(
                  '${_items.length} ürün bulundu',
                  style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  '${_selectedIds.length} seçili',
                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: AppSpacing.sm),
                TextButton(
                  onPressed: () => setState(() {
                    if (_selectedIds.length == _items.length) {
                      _selectedIds.clear();
                    } else {
                      _selectedIds
                        ..clear()
                        ..addAll(_items.map((i) => i.id));
                    }
                  }),
                  child: Text(_selectedIds.length == _items.length ? 'Tümünü Kaldır' : 'Tümünü Seç'),
                ),
              ],
            ),
          ),
          Expanded(
            child: AsyncView(
              value: locationsAsync,
              onRetry: () => ref.invalidate(storageLocationsProvider(widget.householdId)),
              data: (locations) {
                _initializeSuggestedLocations(locations);

                final unresolvedItems = _items.where((i) => _locationIdByItemId[i.id] == null).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
                  children: [
                    for (final location in locations)
                      ..._buildSection(
                        location: location,
                        items: _items.where((i) => _locationIdByItemId[i.id] == location.id).toList(),
                        dateFormat: dateFormat,
                        colorScheme: colorScheme,
                      ),
                    if (unresolvedItems.isNotEmpty)
                      ..._buildSection(
                        items: unresolvedItems,
                        dateFormat: dateFormat,
                        colorScheme: colorScheme,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isDragging) _buildDropBar(context, locationsAsync.valueOrNull ?? []),
            if (_scanTotalAmount != null) _buildPriceComparisonBar(colorScheme),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton(
                onPressed: _isConfirming || _selectedIds.isEmpty ? null : _confirm,
                child: _isConfirming ? const ButtonProgress() : Text('${_selectedIds.length} ürünü dolaba ekle'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sürükleme sürdüğü sürece görünen sabit bırakma çubuğu — liste ne kadar
  /// kaydırılırsa kaydırılsın her zaman erişilebilir kalır (CustomScrollView +
  /// pinned header yerine daha basit ve güvenilir bir çözüm). Giriş/çıkışta
  /// kayarak belirir — eskiden `if (_isDragging)` ile aniden çıkıyordu.
  Widget _buildDropBar(BuildContext context, List<StorageLocation> locations) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      offset: _isDragging ? Offset.zero : const Offset(0, 1),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isDragging ? 1 : 0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4)),
            ],
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final location in locations) ...[
                  _buildDropTarget(context, location),
                  const SizedBox(width: AppSpacing.sm),
                ],
                _buildUnassignDropTarget(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int _countAssigned(String? locationId) =>
      _items.where((i) => _locationIdByItemId[i.id] == locationId).length;

  Widget _buildDropTarget(BuildContext context, StorageLocation location) {
    final style = storageKindStyle(context, location.kind, icon: location.icon);
    final count = _countAssigned(location.id);
    return _DropTargetCard(
      isHovering: _dragHoverLocationId == location.id,
      color: style.color,
      icon: style.icon,
      label: location.name,
      count: count,
      onWillAccept: () => setState(() => _dragHoverLocationId = location.id),
      onLeave: () => setState(() => _dragHoverLocationId = null),
      onAccept: (itemId) {
        HapticFeedback.selectionClick();
        _assignLocation(itemId, location.id);
        setState(() => _dragHoverLocationId = null);
      },
    );
  }

  // "Bölüm seçilmedi" hedefi — önceden sadece listede bir grup başlığı
  // olarak vardı, sürükleyerek bir atamayı GERİ ALMANIN yolu yoktu.
  Widget _buildUnassignDropTarget(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final count = _countAssigned(null);
    return _DropTargetCard(
      isHovering: _dragHoverLocationId == _unassignedDropId,
      color: colorScheme.onSurfaceVariant,
      icon: Icons.remove_circle_outline_rounded,
      label: 'Belirsiz',
      count: count,
      onWillAccept: () => setState(() => _dragHoverLocationId = _unassignedDropId),
      onLeave: () => setState(() => _dragHoverLocationId = null),
      onAccept: (itemId) {
        HapticFeedback.selectionClick();
        setState(() {
          _locationIdByItemId[itemId] = null;
          _dragHoverLocationId = null;
        });
      },
    );
  }
}

/// Sürükle-bırak hedef kartı — sabit boyut, gölgeli Material yüzey, hover'da
/// ölçekleniyor ve ürün sayısı rozeti taşıyor. Eskiden sabit boyutsuz, gölgesiz
/// bir AnimatedContainer'dı; metin uzunluğuna göre chip'ler farklı genişlikte
/// hizasız görünüyordu (kullanıcı geri bildirimi: "çok düz bir tasarım").
class _DropTargetCard extends StatelessWidget {
  const _DropTargetCard({
    required this.isHovering,
    required this.color,
    required this.icon,
    required this.label,
    required this.count,
    required this.onWillAccept,
    required this.onLeave,
    required this.onAccept,
  });

  final bool isHovering;
  final Color color;
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onWillAccept;
  final VoidCallback onLeave;
  final ValueChanged<String> onAccept;

  @override
  Widget build(BuildContext context) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        onWillAccept();
        return true;
      },
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (details) => onAccept(details.data),
      builder: (context, candidateData, rejectedData) {
        return AnimatedScale(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          scale: isHovering ? 1.08 : 1.0,
          child: Material(
            color: isHovering ? color.withValues(alpha: 0.18) : Theme.of(context).colorScheme.surfaceContainerLow,
            elevation: isHovering ? 4 : 1,
            shadowColor: color.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(AppRadius.card),
            child: Container(
              width: 84,
              height: 84,
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: color.withValues(alpha: isHovering ? 0.9 : 0.35), width: isHovering ? 2 : 1),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      StorageIconBox(icon: icon, color: color, size: 36, iconSize: 20),
                      const SizedBox(height: AppSpacing.xs),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (count > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: AppBadge(label: '$count', variant: AppBadgeVariant.quantity),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
