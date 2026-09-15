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
        date: DateTime.tryParse(json['date']?.toString() ?? '') ??
            DateTime.now(),
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

  const SubscriptionModel({
    required this.id,
    required this.planName,
    required this.subtitle,
    required this.scheduleDays,
    required this.isPaused,
  });

  SubscriptionModel copyWith({
    String? id,
    String? planName,
    String? subtitle,
    List<DateSlot>? scheduleDays,
    bool? isPaused,
  }) =>
      SubscriptionModel(
        id: id ?? this.id,
        planName: planName ?? this.planName,
        subtitle: subtitle ?? this.subtitle,
        scheduleDays: scheduleDays ?? this.scheduleDays,
        isPaused: isPaused ?? this.isPaused,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'planName': planName,
        'subtitle': subtitle,
        'scheduleDays': scheduleDays.map((d) => d.toJson()).toList(),
        'isPaused': isPaused,
      };

  /// Handles both Flutter-expected keys and actual backend format:
  ///   Backend: _id, planName, mealsPerWeek, planDurationWeeks,
  ///            scheduleDays (List<String> like ['Mon','Tue']),
  ///            status ('active'|'paused')
  ///   Flutter: id, planName, subtitle, scheduleDays (List<DateSlot>),
  ///            isPaused (bool)
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

    // Build subtitle from mealsPerWeek + planDurationWeeks if needed
    String subtitle;
    if (json.containsKey('subtitle') && json['subtitle'] != null) {
      subtitle = json['subtitle'].toString();
    } else {
      final meals = json['mealsPerWeek'];
      final weeks = json['planDurationWeeks'];
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
      // Backend format: ['Mon', 'Tue', ...]
      final now = DateTime.now();
      days = rawDays.map((dayStr) {
        // Find the next occurrence of this day from today
        final nextDate = _nextDateForDay(now, dayStr.toString());
        return DateSlot(day: dayStr.toString(), date: nextDate);
      }).toList();
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
    );
  }

  /// Find the next occurrence of a day-of-week abbreviation from [from].
  static DateTime _nextDateForDay(DateTime from, String dayAbbr) {
    const dayMap = {
      'Mon': DateTime.monday,
      'Tue': DateTime.tuesday,
      'Wed': DateTime.wednesday,
      'Thu': DateTime.thursday,
      'Fri': DateTime.friday,
      'Sat': DateTime.saturday,
      'Sun': DateTime.sunday,
    };
    final target = dayMap[dayAbbr];
    if (target == null) return from;

    var d = DateTime(from.year, from.month, from.day);
    while (d.weekday != target) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  /// Convenience factory used by the provider's mock fallback.
  static SubscriptionModel mock() {
    final now = DateTime.now();
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
    );
  }
}
