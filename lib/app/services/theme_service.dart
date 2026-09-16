import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Manages dark/light theme mode across the app.
class ThemeService extends GetxService {
  final RxBool isDarkMode = false.obs;

  ThemeMode get themeMode =>
      isDarkMode.value ? ThemeMode.dark : ThemeMode.light;

  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    Get.changeThemeMode(themeMode);
  }
}
