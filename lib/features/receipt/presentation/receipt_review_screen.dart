import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/error/api_error.dart';
import '../../../core/theme/app_theme.dart';
import '../../household/application/household_providers.dart';
import '../../household/data/household_repository.dart';
import '../../inventory/application/inventory_providers.dart';
import '../../product/presentation/product_picker_sheet.dart';
import '../application/receipt_providers.dart';
import '../data/receipt_repository.dart';

class _LocationStyle {
  const _LocationStyle(this.icon, this.color);
  final IconData icon;
  final Color color;
}

// household_home_screen.dart'taki _locationStyles ile aynı — bölüm türü
// simgelerinin uygulama genelinde tutarlı görünmesi için (o harita private,
// buraya taşımak yerine küçük olduğu için tekrar tanımlamak daha basit).
const _locationStyles = {
  'fridge': _LocationStyle(Icons.kitchen_rounded, Color(0xFF3B82F6)),
  'freezer': _LocationStyle(Icons.ac_unit_rounded, Color(0xFF06B6D4)),
  'pantry': _LocationStyle(Icons.inventory_2_rounded, Color(0xFFB45309)),
};
const _defaultLocationStyle = _LocationStyle(Icons.category_rounded, Color(0xFF6B7280));

class ReceiptReviewScreen extends ConsumerStatefulWidget {
  const ReceiptReviewScreen({
    super.key,
    required this.householdId,
    required this.scanId,
    required this.lineItems,
  });

  final String householdId;
  final String scanId;
  final List<ReceiptLineItem> lineItems;

  @override
  ConsumerState<ReceiptReviewScreen> createState() => _ReceiptReviewScreenState();
}

class _ReceiptReviewScreenState extends ConsumerState<ReceiptReviewScreen> {
  late final List<ReceiptLineItem> _items = List.of(widget.lineItems);
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
    String selectedProductId = item.matchedProductId!;
    String selectedProductName = item.parsedName;
    String? selectedLocationId = _locationIdByItemId[item.id];
    final locations = ref.read(storageLocationsProvider(widget.householdId)).valueOrNull ?? [];

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

    try {
      await ref.read(receiptRepositoryProvider).correctLineItem(
            widget.householdId,
            widget.scanId,
            item.id,
            parsedName: newName,
            parsedBrand: newBrand.isEmpty ? null : newBrand,
            parsedQuantity: newQuantity,
            parsedUnit: item.parsedUnit,
            matchedProductId: selectedProductId,
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
        parsedUnit: item.parsedUnit,
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
        Navigator.of(context)
          ..pop()
          ..pop();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeApiError(error))));
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  Widget _buildItemCard(
    ReceiptLineItem item, {
    required DateFormat dateFormat,
    required ColorScheme colorScheme,
    required bool locationMissing,
  }) {
    final isSelected = _selectedIds.contains(item.id);
    final expiresAt = _expiresAtByItemId[item.id];
    return Card(
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
            title: Text(item.parsedName, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    children: [
                      Text('${item.parsedQuantity} ${item.parsedUnit}'),
                      if (item.parsedBrand != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            item.parsedBrand!,
                            style: TextStyle(fontSize: 11, color: colorScheme.onSecondaryContainer),
                          ),
                        ),
                      if (!item.isHighConfidence)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Kontrol et',
                            style: TextStyle(fontSize: 11, color: colorScheme.onErrorContainer),
                          ),
                        ),
                    ],
                  ),
                  // Fişteki ham metin: AI'ın çevirisini doğrulamak için
                  // kullanıcının yanına koyduğumuz referans.
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      item.rawText,
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
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
                    style: OutlinedButton.styleFrom(foregroundColor: colorScheme.error),
                    onPressed: () => _editItem(item),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildLocationSection({
    required StorageLocation location,
    required List<ReceiptLineItem> items,
    required DateFormat dateFormat,
    required ColorScheme colorScheme,
  }) {
    if (items.isEmpty) return const [];
    final style = _locationStyles[location.kind] ?? _defaultLocationStyle;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.xs),
        child: Row(
          children: [
            Icon(style.icon, size: 18, color: style.color),
            const SizedBox(width: 6),
            Text(
              '${location.name.toUpperCase()} · ${items.length} ürün',
              style: TextStyle(fontWeight: FontWeight.w700, color: style.color, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
      for (final item in items) ...[
        _buildItemCard(item, dateFormat: dateFormat, colorScheme: colorScheme, locationMissing: false),
        const SizedBox(height: AppSpacing.xs),
      ],
    ];
  }

  List<Widget> _buildUnresolvedSection({
    required List<ReceiptLineItem> items,
    required DateFormat dateFormat,
    required ColorScheme colorScheme,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, AppSpacing.md, 4, AppSpacing.xs),
        child: Row(
          children: [
            Icon(Icons.help_outline_rounded, size: 18, color: colorScheme.error),
            const SizedBox(width: 6),
            Text(
              'BÖLÜM SEÇİLMEDİ · ${items.length} ürün',
              style: TextStyle(fontWeight: FontWeight.w700, color: colorScheme.error, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
      for (final item in items) ...[
        _buildItemCard(item, dateFormat: dateFormat, colorScheme: colorScheme, locationMissing: true),
        const SizedBox(height: AppSpacing.xs),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(storageLocationsProvider(widget.householdId));
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat('dd.MM.yyyy');

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
              ],
            ),
          ),
          Expanded(
            child: locationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text(describeApiError(error))),
              data: (locations) {
                _initializeSuggestedLocations(locations);

                final unresolvedItems = _items.where((i) => _locationIdByItemId[i.id] == null).toList();

                return ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xl),
                  children: [
                    for (final location in locations)
                      ..._buildLocationSection(
                        location: location,
                        items: _items.where((i) => _locationIdByItemId[i.id] == location.id).toList(),
                        dateFormat: dateFormat,
                        colorScheme: colorScheme,
                      ),
                    if (unresolvedItems.isNotEmpty)
                      ..._buildUnresolvedSection(
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
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: FilledButton(
            onPressed: _isConfirming || _selectedIds.isEmpty ? null : _confirm,
            child: _isConfirming
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text('${_selectedIds.length} ürünü dolaba ekle'),
          ),
        ),
      ),
    );
  }
}
