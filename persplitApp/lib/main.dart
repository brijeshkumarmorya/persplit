import 'package:flutter/material.dart';
import 'routes/app_router.dart';
import 'services/settlement_service.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ CRITICAL: Initialize Dio with auth interceptors BEFORE running app
  SettlementService.initializeDio();

  // Check if user is already authenticated
  final isAuthenticated = await AuthService.isAuthenticated();
  print('🔍 Auth Status: $isAuthenticated');

  runApp(PerSplitApp(isAuthenticated: isAuthenticated));
}

class PerSplitApp extends StatelessWidget {
  final bool isAuthenticated;

  const PerSplitApp({super.key, required this.isAuthenticated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'PerSplit',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        primaryColor: const Color(0xFF41A67E),
        fontFamily: 'Roboto',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF41A67E)),
      ),
    );
  }
}
