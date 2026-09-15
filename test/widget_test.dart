import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:subscart/app/data/providers/schedule_api_provider.dart';
import 'package:subscart/app/data/repositories/schedule_repository.dart';
import 'package:subscart/app/modules/schedule/bindings/schedule_binding.dart';
import 'package:subscart/app/modules/schedule/controllers/schedule_controller.dart';
import 'package:subscart/app/modules/schedule/views/schedule_view.dart';

void main() {
  testWidgets('Schedule screen shows error when backend is unreachable',
      (WidgetTester tester) async {
    Get.put<ScheduleRepository>(
      ScheduleRepository(provider: ScheduleApiProvider()),
    );
    Get.lazyPut<ScheduleController>(() => ScheduleController());

    await tester.pumpWidget(
      const GetMaterialApp(home: ScheduleView()),
    );
    await tester.pumpAndSettle();

    // Flutter test HttpClient returns 400, which maps to a generic error.
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);

    Get.reset();
  });

  testWidgets('ScheduleBinding registers ScheduleController',
      (WidgetTester tester) async {
    ScheduleBinding().dependencies();
    expect(Get.isRegistered<ScheduleRepository>(), isTrue);
    expect(Get.isRegistered<ScheduleController>(), isTrue);

    Get.reset();
  });
}
