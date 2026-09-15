import 'package:get/get.dart';

import 'app_routes.dart';
import '../modules/schedule/bindings/schedule_binding.dart';
import '../modules/schedule/views/schedule_view.dart';

/// App-wide route table.
class AppPages {
  static const String initial = ScheduleRoutes.schedule;

  static final List<GetPage> routes = [
    GetPage(
      name: ScheduleRoutes.schedule,
      page: () => const ScheduleView(),
      binding: ScheduleBinding(),
    ),
  ];
}
