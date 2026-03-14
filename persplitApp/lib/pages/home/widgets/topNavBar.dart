// lib/pages/home/widgets/topNavBar.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TopNavbar extends StatelessWidget {
  final String? userName;
  final VoidCallback? onProfileTap;
  final VoidCallback? onAnalyticsTap;
  final VoidCallback? onNotificationsTap;

  const TopNavbar({
    super.key,
    this.userName,
    this.onProfileTap,
    this.onAnalyticsTap,
    this.onNotificationsTap,
  });

  // Generate initials from name (handles multi-word names)
  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    } else {
      final first = parts.first[0];
      final last = parts.last[0];
      return (first + last).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme colors centralized for easy change
    const primary = Color(0xFF41A67E);
    const darkText = Color(0xFF2C3E50);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar with ripple and semantic label
            Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  // prefer injected callback; fallback to navigation
                  if (onProfileTap != null) {
                    onProfileTap!();
                  } else {
                    context.push('/profile');
                  }
                },
                child: Semantics(
                  label: userName != null && userName!.isNotEmpty
                      ? 'Open profile for $userName'
                      : 'Open profile',
                  button: true,
                  child: CircleAvatar(
                    radius: 24,
                    backgroundColor: primary,
                    child: Text(
                      _initials(userName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Spacer between avatar and center logo
            const SizedBox(width: 12),

            // Center logo + greeting (shrinks gracefully)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo row - keeps compact on narrow screens
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 220),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Per',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF01734c),
                            letterSpacing: 0.3,
                          ),
                        ),
                        Text(
                          'Split',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.black,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Animated greeting (only when userName provided)
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.1),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: userName != null
                        ? Padding(
                            key: ValueKey('greeting-$userName'),
                            padding: const EdgeInsets.only(top: 6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: primary.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.waving_hand,
                                    size: 16,
                                    color: primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      'Hi, ${userName!.split(' ').first}!',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: darkText,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),

            // Action icons
            Row(
              children: [
                // Analytics
                Tooltip(message: 'Analytics (coming soon)'),
                IconButton(
                  onPressed: () {
                    if (onAnalyticsTap != null) {
                      onAnalyticsTap!();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Expanded(child: Text('Analytics coming soon!')),
                            ],
                          ),
                          backgroundColor: primary,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  tooltip: 'Analytics',
                  icon: const Icon(
                    Icons.bar_chart_rounded,
                    color: primary,
                    size: 26,
                  ),
                ),

                // Notifications
                IconButton(
                  onPressed: () {
                    if (onNotificationsTap != null) {
                      onNotificationsTap!();
                    } else {
                      context.push('/notifications');
                    }
                  },
                  tooltip: 'Notifications',
                  icon: const Icon(
                    Icons.notifications_none_rounded,
                    color: primary,
                    size: 26,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
