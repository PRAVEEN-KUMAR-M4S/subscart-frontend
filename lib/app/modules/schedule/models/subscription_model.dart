import 'package:intl/intl.dart';

/// A single selectable day pill in the horizontal schedule row.
class DateSlot {
  final String day; // e.g. "Tue"
  final DateTime date;
  final bool isSelected;

  const DateSlot({
    required this.day,
    required this.date,
    this.isSelected = false,
  });

  DateSlot copyWith({String? day, DateTime? date, bool? isSelected}) =>
      DateSlot(
        day: day ?? this.day,
        date: date ?? this.date,
        isSelected: isSelected ?? this.isSelected,
      );

  Map<String, dynamic> toJson() => {
    'day': day,
    'date': date.toIso8601String(),
    'isSelected': isSelected,
  };

  factory DateSlot.fromJson(Map<String, dynamic> json) => DateSlot(
    day: json['day']?.toString() ?? '',
    date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
    isSelected: json['isSelected'] == true,
  );
}

/// Meal-plan subscription shown on the schedule screen.
class SubscriptionModel {
  final String id;
  final String planName;
  final String subtitle;
  final List<DateSlot> scheduleDays;
  final bool isPaused;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? mealsPerWeek;
  final int? planDurationWeeks;

  const SubscriptionModel({
    required this.id,
    required this.planName,
    required this.subtitle,
    required this.scheduleDays,
    required this.isPaused,
    this.startDate,
    this.endDate,
    this.mealsPerWeek,
    this.planDurationWeeks,
  });

  SubscriptionModel copyWith({
    String? id,
    String? planName,
    String? subtitle,
    List<DateSlot>? scheduleDays,
    bool? isPaused,
    DateTime? startDate,
    DateTime? endDate,
    int? mealsPerWeek,
    int? planDurationWeeks,
  }) => SubscriptionModel(
    id: id ?? this.id,
    planName: planName ?? this.planName,
    subtitle: subtitle ?? this.subtitle,
    scheduleDays: scheduleDays ?? this.scheduleDays,
    isPaused: isPaused ?? this.isPaused,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    mealsPerWeek: mealsPerWeek ?? this.mealsPerWeek,
    planDurationWeeks: planDurationWeeks ?? this.planDurationWeeks,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'planName': planName,
    'subtitle': subtitle,
    'scheduleDays': scheduleDays.map((d) => d.toJson()).toList(),
    'isPaused': isPaused,
    if (startDate != null) 'startDate': startDate!.toIso8601String(),
    if (endDate != null) 'endDate': endDate!.toIso8601String(),
    if (mealsPerWeek != null) 'mealsPerWeek': mealsPerWeek,
    if (planDurationWeeks != null) 'planDurationWeeks': planDurationWeeks,
  };

  /// Handles both Flutter-expected keys and actual backend format:
  ///   Backend: _id, planName, mealsPerWeek, planDurationWeeks,
  ///            scheduleDays (`List<String>` like ['Mon','Tue']),
  ///            status ('active'|'paused'),
  ///            startDate, endDate
  ///   Flutter: id, planName, subtitle, scheduleDays (`List<DateSlot>`),
  ///            isPaused (bool), startDate, endDate, mealsPerWeek, planDurationWeeks
  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    // Determine isPaused from either 'isPaused' bool or 'status' string
    bool paused;
    if (json.containsKey('isPaused')) {
      paused = json['isPaused'] == true;
    } else if (json['status'] is String) {
      paused = json['status'] == 'paused';
    } else {
      paused = false;
    }

    // Parse startDate / endDate from backend
    final startDate = DateTime.tryParse(json['startDate']?.toString() ?? '');
    final endDate = DateTime.tryParse(json['endDate']?.toString() ?? '');
    final mealsPerWeek = json['mealsPerWeek'] is int
        ? json['mealsPerWeek'] as int
        : int.tryParse(json['mealsPerWeek']?.toString() ?? '');
    final planDurationWeeks = json['planDurationWeeks'] is int
        ? json['planDurationWeeks'] as int
        : int.tryParse(json['planDurationWeeks']?.toString() ?? '');

    // Build subtitle from mealsPerWeek + planDurationWeeks if needed
    String subtitle;
    if (json.containsKey('subtitle') && json['subtitle'] != null) {
      subtitle = json['subtitle'].toString();
    } else {
      final meals = mealsPerWeek;
      final weeks = planDurationWeeks;
      if (meals != null && weeks != null) {
        subtitle = '$meals Meals Weekly Plan · $weeks-week';
      } else {
        subtitle = '';
      }
    }

    // Parse scheduleDays — backend returns List<String>,
    // Flutter-expected format is List<DateSlot>
    List<DateSlot> days;
    final rawDays = json['scheduleDays'] as List<dynamic>?;
    if (rawDays == null || rawDays.isEmpty) {
      days = [];
    } else if (rawDays.first is String) {
      // Backend format: ['Mon', 'Tue', ...] — day abbreviations
      // Generate DateSlots for EVERY occurrence across the full subscription
      final subStart = startDate ?? DateTime.now();
      final subEnd = endDate ?? subStart.add(const Duration(days: 42));
      days = _generateAllDates(rawDays.cast<String>(), subStart, subEnd);
    } else {
      // Flutter-expected format: [{'day': 'Tue', 'date': '...', ...}]
      days = rawDays
          .map((e) => DateSlot.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return SubscriptionModel(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      planName: json['planName']?.toString() ?? '',
      subtitle: subtitle,
      scheduleDays: days,
      isPaused: paused,
      startDate: startDate,
      endDate: endDate,
      mealsPerWeek: mealsPerWeek,
      planDurationWeeks: planDurationWeeks,
    );
  }

  /// Generate DateSlots for every occurrence of [dayAbbrs] between
  /// [start] and [end] (inclusive).
  static List<DateSlot> _generateAllDates(
    List<String> dayAbbrs,
    DateTime start,
    DateTime end,
  ) {
    const dayMap = {
      'Mon': DateTime.monday,
      'Tue': DateTime.tuesday,
      'Wed': DateTime.wednesday,
      'Thu': DateTime.thursday,
      'Fri': DateTime.friday,
      'Sat': DateTime.saturday,
      'Sun': DateTime.sunday,
    };

    // Resolve day abbreviations to weekday ints
    final targetWeekdays = dayAbbrs
        .map((d) => dayMap[d])
        .whereType<int>()
        .toSet();

    if (targetWeekdays.isEmpty) return [];

    final List<DateSlot> result = [];
    var current = DateTime(start.year, start.month, start.day);
    final lastDay = DateTime(end.year, end.month, end.day);

    while (!current.isAfter(lastDay)) {
      if (targetWeekdays.contains(current.weekday)) {
        final abbr = dayAbbrs.firstWhere(
          (a) => dayMap[a] == current.weekday,
          orElse: () => '',
        );
        result.add(DateSlot(day: abbr, date: current));
      }
      current = current.add(const Duration(days: 1));
    }

    return result;
  }

  /// Convenience factory used by the provider's mock fallback.
  static SubscriptionModel mock() {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day);
    final endDate = startDate.add(const Duration(days: 42));
    final days = List.generate(7, (i) {
      final date = DateTime(now.year, now.month, now.day + i);
      return DateSlot(
        day: DateFormat.E().format(date),
        date: date,
        isSelected: i == 1,
      );
    });
    return SubscriptionModel(
      id: 'sub_001',
      planName: 'Healthy Lab...',
      subtitle: '5 Meals Weekly Plan · 6-week',
      scheduleDays: days,
      isPaused: false,
      startDate: startDate,
      endDate: endDate,
      mealsPerWeek: 5,
      planDurationWeeks: 6,
    );
  }
}
