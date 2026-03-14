import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../pages/group/create_group_page.dart';
import '../pages/group/group_expansion_page.dart';
import '../pages/group/group_page.dart';
import '../pages/home/home_page.dart';
import '../pages/add_expense_page.dart';
import '../pages/home/notification_page.dart';
import '../pages/home/profile_page.dart';
import '../pages/auth_page.dart';
import '../pages/profile_edit_page.dart';
import '../pages/settle/payment/payment_page_new.dart';
import '../pages/settle/payment_management_page.dart';
import '../pages/settle/settle_page.dart';
import '../pages/friends_page.dart';
import '../services/auth_service.dart';

final GoRouter appRouter = GoRouter(
  // ✅ CRITICAL: Add redirect for auth check
  redirect: (context, state) async {
    final isLoggedIn = await AuthService.isAuthenticated();
    final isLoggingIn = state.matchedLocation == '/auth';
    final path = state.matchedLocation;

    print('🔐 [ROUTER] Current path: $path, Logged in: $isLoggedIn');

    // If not logged in and not on auth page, redirect to auth
    if (!isLoggedIn && !isLoggingIn && path != '/auth') {
      print('❌ [ROUTER] Not authenticated - redirecting to /auth');
      return '/auth';
    }

    // If logged in and on auth page, redirect to home
    if (isLoggedIn && isLoggingIn) {
      print('✅ [ROUTER] Already authenticated - redirecting to /');
      return '/';
    }

    return null;
  },
  refreshListenable: GoRouterRefreshStream(AuthService.authStatusStream()),
  routes: [
    // ✅ AUTH ROUTE (no parent protection)
    GoRoute(path: '/auth', builder: (context, state) => const AuthPage()),

    // ✅ HOME ROUTE (protected)
    GoRoute(path: '/', builder: (context, state) => const HomePage()),

    // ✅ ADD EXPENSE ROUTE
    GoRoute(path: '/add', builder: (context, state) => const AddExpensePage()),

    // ✅ GROUPS ROUTE
    GoRoute(path: '/groups', builder: (context, state) => const GroupsPage()),

    // ✅ SETTLE ROUTE
    GoRoute(path: '/settle', builder: (context, state) => const SettlePage()),

    // ✅ FRIENDS ROUTE
    GoRoute(path: '/friends', builder: (context, state) => const FriendsPage()),

    // ✅ NOTIFICATIONS ROUTE
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsPage(),
    ),

    // ✅ GROUP DETAIL ROUTE
    GoRoute(
      path: '/group/:id',
      builder: (context, state) {
        final groupId = state.pathParameters['id']!;
        return GroupExpansionPage(groupId: groupId);
      },
    ),

    // ✅ PAYMENT DETAIL ROUTE
    GoRoute(
      path: '/payment/new',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return MaterialPage(
          child: PaymentPage(
            payeeName: extra?['payeeName'] ?? 'Friend',
            amount: extra?['amount'] ?? 0.0,
            payeeId: extra?['payeeId'] ?? '',
            expenseId: extra?['expenseId'],
            source: extra?['source'] ?? 'splitwise',
          ),
        );
      },
    ),

    // ✅ PROFILE ROUTE
    GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),

    // ✅ CREATE GROUP ROUTE
    GoRoute(
      path: '/create-group',
      builder: (context, state) => const CreateGroupPage(),
    ),

    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const ProfileEditPage(),
    ),

    GoRoute(
      path: '/payment-management',
      builder: (context, state) => const PaymentManagementPage(),
    ),
  ],

  errorBuilder: (context, state) {
    return Scaffold(
      appBar: AppBar(title: const Text('Error')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Page not found'),
            Text('Path: ${state.uri.toString()}'),
            ElevatedButton(
              onPressed: () {
                context.go('/');
              },
              child: const Text('Go Home'),
            ),
          ],
        ),
      ),
    );
  },
);

class GoRouterRefreshStream extends ChangeNotifier implements Listenable {
  late final StreamSubscription<void> _subscription;

  GoRouterRefreshStream(Stream<void> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
