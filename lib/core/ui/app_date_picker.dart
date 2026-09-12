import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/app_theme.dart';
import 'adaptive.dart';

/// `showDatePicker` uygulamada 3 yerde kullanılıyordu (hepsi Material
/// takvim) — iOS kullanıcısı bu ekranlarda hiç görmediği bir bileşenle
/// karşılaşıyordu, HIG'de tarih seçimi AYLIK IZGARA (Takvim uygulamasındaki
/// gibi) ile yapılır — kullanıcı gerçek Apple ekran görüntüsü göndererek
/// bunu netleştirdi; çark (`CupertinoDatePicker`) YANLIŞ referanstı.
/// `isCupertino(context)`'e göre doğru olanı döndürür, Android'de mevcut
/// Material takvimi değiştirmeden bırakır (kullanıcı bunu zaten beğendi).
Future<DateTime?> showAppDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  if (!isCupertino(context)) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
  }

  // initialDate aralığın dışında kalırsa aşağıdaki ay ızgarası boş bir ay
  // gösterebilir (Material'ın showDatePicker'ı bunu sessizce tolere eder)
  // — çağıranlar arasında `initialDate == firstDate` olan yerler var, o
  // sınırda kaymaya karşı burada clamp ediliyor.
  final clampedInitial = initialDate.isBefore(firstDate)
      ? firstDate
      : (initialDate.isAfter(lastDate) ? lastDate : initialDate);

  return showCupertinoModalPopup<DateTime>(
    context: context,
    builder: (context) => _CupertinoCalendarSheet(
      initialDate: clampedInitial,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

/// Apple'ın Takvim uygulamasındaki tarih seçici maketine sadık, Cupertino
/// stiliyle boyanmış aylık ızgara: üstte büyük tarih başlığı, altında
/// "‹ Ay Yıl ›" gezinme satırı, altında 7 sütunlu gün ızgarası. Seçili gün
/// dolu daire (`colorScheme.primary`). Üstte İptal/Bitti — eski çark
/// sürümünde İptal hiç yoktu, kullanıcı barrier'a dokunmak zorundaydı.
class _CupertinoCalendarSheet extends StatefulWidget {
  const _CupertinoCalendarSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  State<_CupertinoCalendarSheet> createState() =>
      _CupertinoCalendarSheetState();
}

class _CupertinoCalendarSheetState extends State<_CupertinoCalendarSheet> {
  late DateTime _selected = widget.initialDate;
  late DateTime _visibleMonth = DateTime(
    widget.initialDate.year,
    widget.initialDate.month,
  );

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _isSelectable(DateTime day) {
    final start = DateTime(
      widget.firstDate.year,
      widget.firstDate.month,
      widget.firstDate.day,
    );
    final end = DateTime(
      widget.lastDate.year,
      widget.lastDate.month,
      widget.lastDate.day,
    );
    return !day.isBefore(start) && !day.isAfter(end);
  }

  bool get _canGoPrevious {
    final firstOfVisible = DateTime(_visibleMonth.year, _visibleMonth.month);
    final firstOfMin = DateTime(widget.firstDate.year, widget.firstDate.month);
    return firstOfVisible.isAfter(firstOfMin);
  }

  bool get _canGoNext {
    final firstOfVisible = DateTime(_visibleMonth.year, _visibleMonth.month);
    final firstOfMax = DateTime(widget.lastDate.year, widget.lastDate.month);
    return firstOfVisible.isBefore(firstOfMax);
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  List<DateTime?> _daysInVisibleMonth() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    // Pazartesi=1 ... Pazar=7 (TR takvimi haftaya Pazartesi başlar).
    final leadingBlanks = firstOfMonth.weekday - 1;
    return [
      for (var i = 0; i < leadingBlanks; i++) null,
      for (var day = 1; day <= daysInMonth; day++)
        DateTime(_visibleMonth.year, _visibleMonth.month, day),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final monthFormat = DateFormat.yMMMM('tr');
    final weekdayLabels = ['P', 'S', 'Ç', 'P', 'C', 'C', 'P'];
    final days = _daysInVisibleMonth();

    return Container(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context),
                    child: const Text('İptal'),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(context, _selected),
                    child: const Text('Bitti'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  DateFormat('d MMM E', 'tr').format(_selected),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${monthFormat.format(_visibleMonth)} ›',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_left),
                    onPressed: _canGoPrevious ? () => _changeMonth(-1) : null,
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.chevron_right),
                    onPressed: _canGoNext ? () => _changeMonth(1) : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  for (final label in weekdayLabels)
                    Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: GridView.count(
                crossAxisCount: 7,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final day in days)
                    if (day == null)
                      const SizedBox.shrink()
                    else
                      _CalendarDayCell(
                        day: day,
                        isSelected: _isSameDay(day, _selected),
                        isSelectable: _isSelectable(day),
                        onTap: _isSelectable(day)
                            ? () => setState(() => _selected = day)
                            : null,
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    required this.isSelected,
    required this.isSelectable,
    required this.onTap,
  });

  final DateTime day;
  final bool isSelected;
  final bool isSelectable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: isSelected
              ? BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                )
              : null,
          child: Text(
            '${day.day}',
            style: TextStyle(
              color: isSelected
                  ? colorScheme.onPrimary
                  : isSelectable
                  ? colorScheme.onSurface
                  : colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
