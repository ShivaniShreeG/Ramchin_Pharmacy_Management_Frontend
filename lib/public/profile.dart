import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'config.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool isLoading = true;
  Map<String, dynamic>? profileData;
  String? errorMessage;

  int? shopId;
  String? userId;
  String? role;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }
  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent, // Let border container show
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: royal, width: 2), // 💙 Royal blue border
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

  Future<void> _initializeProfile() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    userId = prefs.getString('userId');
    role = prefs.getString('role');

    if (shopId != null && userId != null && role != null) {
      await _fetchProfile(shopId!, userId!, role!);
    } else {
      setState(() {
        isLoading = false;
        errorMessage = 'User data not found.';
      });
      _showMessage('User data not found. Please log in again.');
    }
  }

  Future<void> _fetchProfile(int shopId, String userId, String role) async {
    try {
      final url = Uri.parse('$baseUrl/profile/$role/$shopId/$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          profileData = data;
          isLoading = false;
        });
        _showMessage('Profile loaded successfully!');
      } else {
        setState(() {
          isLoading = false;
          errorMessage = 'Failed to load profile: ${response.statusCode}';
        });
        _showMessage('Failed to load profile (${response.statusCode}).');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        errorMessage = 'Error fetching profile: $e';
      });
      _showMessage('Error fetching profile. Please try again.');
    }
  }

  Widget _buildInfoRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: royal), // Olive Green 🌿
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: royal, // Earthy dark brown 🪵
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        backgroundColor: royal, // Warm Beige 🏡
        body: Center(
          child: CircularProgressIndicator(color: Colors.white), // Darker Olive 🌿
        ),
      );
    }

    if (profileData == null) {
      return Scaffold(
        backgroundColor: Colors.white, // Warm Beige 🏡
        appBar: AppBar(
          title: const Text(
            'Profile',
            style: TextStyle(
              color: Colors.white, // Muted Tan 🏺
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: royal, // Olive Green 🌿
          iconTheme: const IconThemeData(color: Colors.white), // Muted Tan 🏺
          centerTitle: true,
        ),
        body: Center(
          child: Text(
            errorMessage ?? 'No profile data found',
            style: const TextStyle(color: royal), // Olive 🌿
          ),
        ),
      );
    }

    final shop = profileData!['shop'] ?? {};
    final shopLogoBase64 = shop['logo'];
    final shopName = shop['name'] ?? 'shop';

    return Scaffold(
      backgroundColor: Colors.white, // Warm Beige 🏡
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Colors.white, // Muted Tan 🏺
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: royal, // Olive Green 🌿
        iconTheme: const IconThemeData(color: Colors.white), // Muted Tan 🏺
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(
                  color: royal, // 💙 Royal blue border
                  width: 1,
                ),
              ),
              color: Colors.white, // Slightly darker beige 🏡
              shadowColor: royal.withValues(alpha: 0.3),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: royalLight, // Muted Tan 🏺
                      backgroundImage: shopLogoBase64 != null
                          ? MemoryImage(base64Decode(shopLogoBase64))
                          : null,
                      child: shopLogoBase64 == null
                          ? const Icon(
                        Icons.home,
                        size: 50,
                        color: royal, // Olive Green 🌿
                      )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      shopName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: royal, // Olive Green 🌿
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Divider(
                      color: royal, // Slightly darker
                      thickness: 1.5,
                      height: 20,
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Personal Information',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: royal, // Olive Green 🌿
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildInfoRow(Icons.account_circle, profileData!['name'] ?? ''),
                    if (profileData!['role'] == 'ADMIN')
                      _buildInfoRow(Icons.badge, profileData!['designation'] ?? ''),
                    _buildInfoRow(Icons.phone, profileData!['phone'] ?? ''),
                    _buildInfoRow(Icons.email, profileData!['email'] ?? ''),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
