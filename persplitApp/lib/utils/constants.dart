// lib/utils/constants.dart - COMPLETE VERSION WITH SOCKET.IO

import 'package:socket_io_client/socket_io_client.dart' as IO;

class Constants {
  // ============================================
  // API CONFIGURATION
  // ============================================

  // Base API URL - CHANGE THIS TO YOUR SERVER URL
  static const String baseUrl = 'https://persplit-api-877176161393.us-central1.run.app/api'; // Production
  // static const String baseUrl = 'http://10.0.2.2:8000/api'; // Android Emulator
  // static const String baseUrl = 'http://localhost:8000/api'; // iOS Simulator
  // static const String baseUrl = 'http://10.85.235.56:8000/api'; // Real Device

  // Socket.IO URL
  static const String socketUrl = 'https://persplit-api-877176161393.us-central1.run.app'; // Production
  // static const String socketUrl = 'http://10.0.2.2:8000'; // Android Emulator
  // static const String socketUrl = 'http://localhost:8000'; // iOS Simulator
  // static const String socketUrl = 'http://10.85.235.56:8000'; // Real Device

  // API endpoint aliases (for compatibility)
  static const String apiUrl = baseUrl;

  // Auth endpoints
  static const String authBaseUrl = '$baseUrl/auth';

  // User endpoints
  static const String userBaseUrl = '$baseUrl/users';

  // Payment endpoints
  static const String paymentBaseUrl = '$baseUrl/payment';

  // Expense endpoints
  static const String expenseBaseUrl = '$baseUrl/expenses';

  // Settlement endpoints
  static const String settlementBaseUrl = '$baseUrl/settlement';

  // ============================================
  // APP CONFIGURATION
  // ============================================

  static const String appName = 'PerSplit';
  static const String appVersion = '1.0.0';

  // ============================================
  // TIMEOUTS
  // ============================================

  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ============================================
  // STORAGE KEYS
  // ============================================

  static const String keyAccessToken = 'accessToken';
  static const String keyRefreshToken = 'refreshToken';
  static const String keyUserId = 'userId';
  static const String keyUserName = 'userName';
  static const String keyUserEmail = 'userEmail';
  static const String keyUserUsername = 'userUsername';
  static const String keyUserAvatar = 'userAvatar';
  static const String keyUserUpiId = 'userUpiId';
}

// ============================================
// BACKWARD COMPATIBILITY EXPORTS
// ============================================

const String baseUrl = Constants.baseUrl;
const String apiUrl = Constants.apiUrl;
const String socketUrl = Constants.socketUrl;

// ============================================
// SOCKET.IO SETUP
// ============================================

/// Initialize Socket.IO connection with authentication
///
/// Usage:
/// ```dart
/// final token = await AuthService.getAccessToken();
/// if (token != null) {
///   final socket = initSocket(token);
///   socket.connect();
/// }
/// ```
IO.Socket initSocket(String userToken) {
  final socket = IO.io(
    socketUrl,
    IO.OptionBuilder()
        .setTransports(['websocket']) // Required for Render deployment
        .setAuth({'token': userToken}) // Attach JWT for authentication
        .enableForceNew() // Force new connection
        .enableReconnection() // Auto-reconnect on disconnect
        .disableAutoConnect() // Manual connect (safer)
        .build(),
  );

  return socket;
}
