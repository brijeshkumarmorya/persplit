import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../services/notification_service.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await NotificationService.getMyNotifications();

    if (result['success']) {
      setState(() {
        _notifications = (result['notifications'] as List)
            .map((n) => n as Map<String, dynamic>)
            .toList();
        _isLoading = false;
      });

      debugPrint('📬 Loaded ${_notifications.length} notifications');
    } else {
      setState(() {
        _errorMessage = result['message'];
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to load notifications'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _refreshNotifications() async {
    await _loadNotifications();
  }

  Future<void> _markAsRead(String notificationId, int index) async {
    // Optimistically update UI
    setState(() {
      _notifications[index]['isRead'] = true;
    });

    final result = await NotificationService.markAsRead(
      notificationId: notificationId,
    );

    if (!result['success']) {
      // Revert if failed
      setState(() {
        _notifications[index]['isRead'] = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to mark as read'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Group notifications by date (Today, Yesterday, Older)
  Map<String, List<Map<String, dynamic>>> _groupNotificationsByDate() {
    final Map<String, List<Map<String, dynamic>>> grouped = {
      'Today': [],
      'Yesterday': [],
      'Older': [],
    };

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (var notification in _notifications) {
      try {
        final createdAt = notification['createdAt'] as String?;
        if (createdAt == null) continue;

        final date = DateTime.parse(createdAt);
        final dateOnly = DateTime(date.year, date.month, date.day);

        if (dateOnly == today) {
          grouped['Today']!.add(notification);
        } else if (dateOnly == yesterday) {
          grouped['Yesterday']!.add(notification);
        } else {
          grouped['Older']!.add(notification);
        }
      } catch (e) {
        debugPrint('Error parsing date: $e');
        grouped['Older']!.add(notification);
      }
    }

    return grouped;
  }

  String _formatTime(String? dateStr) {
    if (dateStr == null) return '';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM d').format(date);
      }
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAF9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9FAF9),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: const Text(
          "Notifications",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF41A67E)),
            )
          : _errorMessage != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshNotifications,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF41A67E),
                    ),
                    child: const Text(
                      'Retry',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 80,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _refreshNotifications,
              color: const Color(0xFF41A67E),
              child: _buildNotificationList(width, height),
            ),
    );
  }

  Widget _buildNotificationList(double width, double height) {
    final groupedNotifications = _groupNotificationsByDate();

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.05,
        vertical: height * 0.015,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Today Section
          if (groupedNotifications['Today']!.isNotEmpty) ...[
            _buildSectionTitle("Today"),
            ...groupedNotifications['Today']!
                .asMap()
                .entries
                .map(
                  (entry) => _buildNotificationCard(
                    context,
                    notification: entry.value,
                    index: _notifications.indexOf(entry.value),
                  ),
                )
                .toList(),
            SizedBox(height: height * 0.02),
          ],

          // Yesterday Section
          if (groupedNotifications['Yesterday']!.isNotEmpty) ...[
            _buildSectionTitle("Yesterday"),
            ...groupedNotifications['Yesterday']!
                .asMap()
                .entries
                .map(
                  (entry) => _buildNotificationCard(
                    context,
                    notification: entry.value,
                    index: _notifications.indexOf(entry.value),
                  ),
                )
                .toList(),
            SizedBox(height: height * 0.02),
          ],

          // Older Section
          if (groupedNotifications['Older']!.isNotEmpty) ...[
            _buildSectionTitle("Older"),
            ...groupedNotifications['Older']!
                .asMap()
                .entries
                .map(
                  (entry) => _buildNotificationCard(
                    context,
                    notification: entry.value,
                    index: _notifications.indexOf(entry.value),
                  ),
                )
                .toList(),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context, {
    required Map<String, dynamic> notification,
    required int index,
  }) {
    final width = MediaQuery.of(context).size.width;

    final notificationId = notification['_id'] as String?;
    final type = notification['type'] as String? ?? 'unknown';
    final message = notification['message'] as String? ?? 'Notification';
    final createdAt = notification['createdAt'] as String?;
    final isUnread = !(notification['isRead'] as bool? ?? false);

    final icon = NotificationService.getNotificationIcon(type);
    final iconColor = NotificationService.getNotificationIconColor(type);
    final time = _formatTime(createdAt);

    return GestureDetector(
      onTap: () {
        if (isUnread && notificationId != null) {
          _markAsRead(notificationId, index);
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: width * 0.03),
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.04,
          vertical: width * 0.035,
        ),
        decoration: BoxDecoration(
          color: isUnread
              ? const Color(0xFFF0F8FF) // Light blue for unread
              : Colors.white,
          borderRadius: BorderRadius.circular(width * 0.04),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: iconColor.withOpacity(0.15),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            SizedBox(width: width * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: width * 0.01),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 13, color: Colors.black45),
                  ),
                ],
              ),
            ),
            if (isUnread)
              const Icon(Icons.circle, size: 10, color: Color(0xFF41A67E)),
          ],
        ),
      ),
    );
  }
}
