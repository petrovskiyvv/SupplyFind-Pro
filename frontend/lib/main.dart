import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/supplier_list_screen.dart';
import 'services/theme_service.dart';
import 'services/localization_service.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => LocalizationService()),
      ],
      child: const FoodSupplierApp(),
    ),
  );
}

class FoodSupplierApp extends StatelessWidget {
  const FoodSupplierApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);
    
    return MaterialApp(
      title: 'SupplyFind Pro',
      debugShowCheckedModeBanner: false,
      themeMode: themeService.themeMode,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0F172A),
          secondary: Color(0xFF10B981),
          surface: Colors.white,
          error: Color(0xFFEF4444),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
          bodyMedium: TextStyle(color: Color(0xFF334155)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF020617),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF38BDF8),
          secondary: Color(0xFF34D399),
          surface: Color(0xFF0B1329),
          background: Color(0xFF020617),
          error: Color(0xFFF87171),
          onPrimary: Color(0xFF020617),
          onSecondary: Color(0xFF020617),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF1E293B), width: 1),
          ),
          clipBehavior: Clip.antiAlias,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC), letterSpacing: -0.5),
          titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFF8FAFC), letterSpacing: -0.5),
          bodyMedium: TextStyle(color: Color(0xFF94A3B8)),
        ),
      ),
      home: const SelectionArea(child: SupplierListScreen()),
    );
  }
}
