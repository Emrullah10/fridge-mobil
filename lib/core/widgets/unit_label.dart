/// Envanter/fiş birimi (`unit_kind`) -> Türkçe etiket. Backend'deki
/// `unit_kind` enum'ıyla birebir aynı anahtarları kullanır
/// (db-schemas/00-extensions-enums.sql). Tek kaynak — ekranlara ham
/// İngilizce enum string'i asla basılmamalı.
const _unitLabels = <String, String>{
  'piece': 'Adet',
  'gram': 'Gram',
  'kilogram': 'Kilogram',
  'milliliter': 'Mililitre',
  'liter': 'Litre',
  'package': 'Paket',
};

const _unitShortLabels = <String, String>{
  'piece': 'adet',
  'gram': 'g',
  'kilogram': 'kg',
  'milliliter': 'ml',
  'liter': 'L',
  'package': 'paket',
};

const unitOptions = ['piece', 'gram', 'kilogram', 'milliliter', 'liter', 'package'];

String unitLabel(String unit) => _unitLabels[unit] ?? unit;

String unitShortLabel(String unit) => _unitShortLabels[unit] ?? unit;
