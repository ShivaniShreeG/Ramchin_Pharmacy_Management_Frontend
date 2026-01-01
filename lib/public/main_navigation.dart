import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../admin/manage.dart';
import '../admin/admin_dashboard.dart';
import '../admin/home_page.dart';
import '../company/manage.dart';
import 'app_drawer.dart';
import 'message.dart';
import 'app_navbar.dart';
import 'login_page.dart';
import '../public/config.dart';
import 'dart:io';


const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class MainNavigation extends StatefulWidget {
  final int? initialIndex;

  const MainNavigation({super.key, this.initialIndex});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  String? role;
  String? userId;
  int? shopId;
  int _selectedIndex = 0;
  bool isLoading = true;
  late List<Widget> _pages;
  Timer? _sessionTimer;
  bool _isDialogShown = false;
  bool _hasNotifications = false;
  bool _hasDueReminder = false;
  DateTime? _lastNotificationTime;
  String? _lastNotificationType;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
  }

  void _showMessage(String message, {String? type}) {
    final now = DateTime.now();

    // ⏱ Prevent same notification every 30 sec
    if (_lastNotificationType == type &&
        _lastNotificationTime != null &&
        now.difference(_lastNotificationTime!).inMinutes < 5) {
      return;
    }

    _lastNotificationType = type;
    _lastNotificationTime = now;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: royal, width: 2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            message,
            style: const TextStyle(
              color: royal,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('role');
    final savedShopId = prefs.getInt('shopId');
    final savedUserId = prefs.getString('userId');

    if (savedRole == null || savedShopId == null || savedUserId == null) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
      return;
    }

    setState(() {
      role = savedRole;
      shopId = savedShopId;
      userId = savedUserId;
    });

    if (role == 'ADMIN') {
      _pages = const [
        AdminDashboard(),
        HomePage(),
        AdminManagePage(),
      ];
      _selectedIndex = widget.initialIndex ?? 1;
    } else {
      _pages = const [ManagePage()];
    }

    await _validateSession();
    await _checkNotifications();

    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _validateSession();
      _checkNotifications();
    });

    setState(() => isLoading = false);
  }

  Future<void> _validateSession() async {
    if (_isDialogShown || userId == null || shopId == null) return;

    try {
      final url = Uri.parse('$baseUrl/users/$shopId/$userId');
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10)); // ⏱ timeout added

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final isUserActive = data['is_active'] ?? false;
        final userBlockReason = data['userBlockReason'] ?? '';
        final shop = data['shop'];

        if (shop != null) {
          final isShopActive = shop['is_active'] ?? false;
          final shopBlockReason = shop['shopBlockReason'] ?? '';

          if (!isShopActive) {
            _isDialogShown = true;
            try {
              await _showInactiveDialog(
                shopBlockReason.isNotEmpty
                    ? "This shop is inactive:\n\"$shopBlockReason\"\nPlease contact administrator."
                    : "This shop is inactive.\nPlease contact administrator.",
              );
            } finally {
              _isDialogShown = false;
            }
            return;
          }
        }

        if (!isUserActive) {
          _isDialogShown = true;
          try {
            await _showInactiveDialog(
              userBlockReason.isNotEmpty
                  ? userBlockReason
                  : "Your account has been deactivated.",
            );
          } finally {
            _isDialogShown = false;
          }
        }
      }
    }

    // 🌐 NO INTERNET / DNS ISSUE
    on SocketException {
      _showMessage(
        "⚠️ Network issue. Please check your internet connection.",
        type: "network",
      );
    }

    // ⏱ REQUEST TIMEOUT
    on TimeoutException {
      _showMessage(
        "⏱ Server taking too long. Please try again.",
        type: "timeout",
      );
    }

    // ❌ OTHER ERRORS
    catch (e) {
      debugPrint('❌ Session error: $e');
      _showMessage(
        "❌ Something went wrong. Please try again.",
        type: "error",
      );
    }
  }

  Future<void> _showInactiveDialog(String reason) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            "Access Denied",
            style: TextStyle(
              color: royal,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            reason,
            style: const TextStyle(
              color: royal,
              fontSize: 16,
            ),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                        (route) => false,
                  );
                },
                child: const Text("Login"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    _validateSession();
  }

  Future<void> _checkNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getInt('shopId');
      if (shopId == null) return;

      final msgRes = await http.get(Uri.parse('$baseUrl/message/shop/$shopId'));
      bool hasMessages = false;
      if (msgRes.statusCode == 200) {
        final data = jsonDecode(msgRes.body);
        hasMessages = data is List && data.isNotEmpty;
      }

      bool hasDue = false;
      final shopRes = await http.get(Uri.parse('$baseUrl/shops/$shopId'));
      if (shopRes.statusCode == 200) {
        final data = jsonDecode(shopRes.body);
        if (data['duedate'] != null) {
          final duedate = DateTime.tryParse(data['duedate']);
          if (duedate != null) {
            final daysLeft = duedate.difference(DateTime.now()).inDays;
            if (daysLeft <= 30 && daysLeft >= 0) hasDue = true;
          }
        }
      }

      if (mounted) {
        setState(() {
          _hasNotifications = hasMessages || hasDue;
          _hasDueReminder = hasDue;
        });

        if (hasMessages) {
          _showMessage("📩 You have new messages!", type: "message");
        } else if (hasDue) {
          _showMessage("💰 Payment due soon!", type: "due");
        }
      }
    } catch (e) {
      debugPrint('❌ Notification error: $e');
      _showMessage("⚠️ Network issue. Please try again.", type: "error");
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [royalblue, royalLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    final showNavbar = role == 'ADMIN' && _pages.length > 1;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: royal,
        title: Text(
          role == 'ADMIN' ? 'Admin Panel' : 'Administrator Panel',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: role == 'ADMIN'
            ? [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.message_outlined),
                color: Colors.white,
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminMessagesPage(),
                    ),
                  );
                  _checkNotifications();
                },
              ),
              if (_hasNotifications)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(height: 8, width: 8),
                  ),
                ),
            ],
          ),
          if (_hasDueReminder) // 👈 Now used in UI
            IconButton(
              icon: const Icon(Icons.warning_amber_rounded),
              color: Colors.yellowAccent,
              tooltip: "Payment due soon",
              onPressed: () {
                _showMessage("💰 Your payment is due soon!", type: "dueButton");
              },
            ),
        ]
            : null,
      ),
      drawer: const AppDrawer(),
      body: _pages[_selectedIndex],
      bottomNavigationBar: showNavbar
          ? BottomNavbar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        role: role ?? '',
      )
          : null,
    );
  }
}