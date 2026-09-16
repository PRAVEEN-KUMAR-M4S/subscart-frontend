import 'package:get/get.dart';

import '../../../data/repositories/schedule_repository.dart';
import '../controllers/schedule_controller.dart';

/// Registers the schedule module's dependencies before the view is built.
class ScheduleBinding extends Bindings {
  @override
  void dependencies() {
    // Repository is app-wide; keep it alive across modules.
    if (!Get.isRegistered<ScheduleRepository>()) {
      Get.put<ScheduleRepository>(ScheduleRepository(), permanent: true);
    }

    // Controller is scoped to the schedule screen.
    Get.lazyPut<ScheduleController>(() => ScheduleController(), fenix: true);
  }
}
