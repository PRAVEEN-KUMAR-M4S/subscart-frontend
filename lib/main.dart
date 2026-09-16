import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/routes/app_pages.dart';
import 'app/services/theme_service.dart';

void main() {
  Get.put(ThemeService(), permanent: true);
  runApp(const SubsCartApp());
}

class SubsCartApp extends StatelessWidget {
  const SubsCartApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Get.find<ThemeService>();
    return Obx(() {
      return GetMaterialApp(
        title: 'SubsCart',
        debugShowCheckedModeBanner: false,
        themeMode: themeService.themeMode,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: Colors.black,
                brightness: Brightness.light,
              ).copyWith(
                primary: Colors.black,
                onPrimary: Colors.white,
                surface: Colors.white,
              ),
          scaffoldBackgroundColor: Colors.white,
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.black),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.black
                  : Colors.grey,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.black26
                  : Colors.grey.shade300,
            ),
          ),
        ),
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme:
              ColorScheme.fromSeed(
                seedColor: Colors.white,
                brightness: Brightness.dark,
              ).copyWith(
                primary: Colors.white,
                onPrimary: Colors.black,
                surface: const Color(0xFF1E1E1E),
              ),
          scaffoldBackgroundColor: const Color(0xFF121212),
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E1E1E),
            surfaceTintColor: Color(0xFF1E1E1E),
            elevation: 0,
            iconTheme: IconThemeData(color: Colors.white),
          ),
          switchTheme: SwitchThemeData(
            thumbColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white
                  : Colors.grey,
            ),
            trackColor: WidgetStateProperty.resolveWith(
              (states) => states.contains(WidgetState.selected)
                  ? Colors.white24
                  : Colors.grey.shade700,
            ),
          ),
        ),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      );
    });
  }
}
