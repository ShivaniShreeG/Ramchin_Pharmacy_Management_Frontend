import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'login_page.dart';
import 'config.dart';
import 'edit_profile.dart';
import 'profile.dart';
import 'change_password.dart';

const Color royalblue = Color(0xFFE18F5B);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFFC39C84);

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String shopName = 'shop';
  String? shopLogoBase64;

  @override
  void initState() {
    super.initState();
    _loadHallInfo();
  }

  Future<void> _loadHallInfo() async {
    final prefs = await SharedPreferences.getInstance();
    String? name = prefs.getString('shopName');
    String? logo = prefs.getString('shopLogo');
    int? shopId = prefs.getInt('shopId');

    // Show cached data if available
    if (name != null) {
      if (!mounted) return;
      setState(() {
        shopName = name;
        shopLogoBase64 = logo;
      });
    }

    // Always refresh from API if hallId exists
    if (shopId != null) {
      await _fetchHallInfo(shopId);
    }
  }

  Future<void> _fetchHallInfo(int shopId) async {
    try {
      final url = Uri.parse('$baseUrl/shops/$shopId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('shopName', data['name']);
        if (data['logo'] != null) await prefs.setString('shopLogo', data['logo']);

        if (!mounted) return;
        setState(() {
          shopName = data['name'];
          shopLogoBase64 = data['logo'];
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch hall info: $e');
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          Expanded(
            child: Container(
              color: Colors.white, // beige background below header
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: royal, // olive green header
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 35,
                          backgroundColor: royalLight, // muted tan
                          backgroundImage: shopLogoBase64 != null
                              ? MemoryImage(base64Decode(shopLogoBase64!))
                              : null,
                          child: shopLogoBase64 == null
                              ? const Icon(Icons.home_work_rounded,
                              size: 35, color: royal) // olive green
                              : null,
                        ),
                        const SizedBox(height: 10),
                        Flexible(
                          child: Text(
                            shopName,
                            style: const TextStyle(
                              color: Colors.white, // dark earthy text
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.person, color: royal),
                    title: const Text('Profile',
                        style: TextStyle(color: royal)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ProfilePage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit, color: royal),
                    title: const Text('Edit profile',
                        style: TextStyle(color: royal)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const EditProfilePage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.lock, color: royal),
                    title: const Text('Change Password',
                        style: TextStyle(color: royal)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ChangePasswordPage()),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: royal),
                    title: const Text('Logout',
                        style: TextStyle(color: royal)),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            color: Colors.white, // beige footer background
            child: Text(
              '© ${DateTime.now().year} Ramchin Technologies Private Limited',
              style: TextStyle(color: royal, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
