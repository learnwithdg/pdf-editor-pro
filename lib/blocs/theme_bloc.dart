import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeEvent {}
class ToggleThemeEvent extends ThemeEvent {}
class LoadThemeEvent extends ThemeEvent {}

class ThemeBloc extends Bloc<ThemeEvent, ThemeMode> {
  ThemeBloc() : super(ThemeMode.light) {
    on<LoadThemeEvent>((event, emit) async {
      final prefs = await SharedPreferences.getInstance();
      final isDark = prefs.getBool('is_dark_mode') ?? false;
      emit(isDark ? ThemeMode.dark : ThemeMode.light);
    });

    on<ToggleThemeEvent>((event, emit) async {
      final isDark = state == ThemeMode.dark;
      final nextMode = isDark ? ThemeMode.light : ThemeMode.dark;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_dark_mode', !isDark);
      emit(nextMode);
    });
  }
}
