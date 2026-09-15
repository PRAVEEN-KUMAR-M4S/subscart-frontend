import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:subscart/app/data/providers/schedule_api_provider.dart';
import 'package:subscart/app/data/repositories/schedule_repository.dart';
import 'package:subscart/app/modules/schedule/bindings/schedule_binding.dart';
import 'package:subscart/app/modules/schedule/controllers/schedule_controller.dart';
import 'package:subscart/app/modules/schedule/views/schedule_view.dart';

void main() {
  testWidgets('Schedule screen renders subscription and order card', (
    WidgetTester tester,
  ) async {
    // Register dependencies the way the binding would.
    Get.put<ScheduleRepository>(
      ScheduleRepository(provider: ScheduleApiProvider()),
    );
    Get.lazyPut<ScheduleController>(() => ScheduleController());

    await tester.pumpWidget(const GetMaterialApp(home: ScheduleView()));
    // Let the controller's fetchSubscription complete.
    await tester.pumpAndSettle();

    // Header content from the mock subscription.
    expect(find.text('Healthy Lab...'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);

    // Order card content from the mock order for the selected day.
    expect(find.textContaining('Order #'), findsOneWidget);
    expect(find.text('Delivery Slot'), findsOneWidget);
    expect(find.textContaining('Calories'), findsOneWidget);

    // Bottom action bar buttons.
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Swap'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);

    Get.reset();
  });

  testWidgets('ScheduleBinding registers ScheduleController', (
    WidgetTester tester,
  ) async {
    ScheduleBinding().dependencies();
    expect(Get.isRegistered<ScheduleRepository>(), isTrue);
    expect(Get.isRegistered<ScheduleController>(), isTrue);

    Get.reset();
  });
}
