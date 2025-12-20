import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../public/config.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? selectedHall;
  bool _isLoading = true;
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double drawingIn = 0.0;
  double drawingOut = 0.0;
  double currentBalance = 0.0;
  List<dynamic> roomStats = [];

  @override
  void initState() {
    super.initState();
    _loadHall();
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: isError ? Colors.redAccent.shade400 : royal,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: royal,width: 2)
        ),
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadHall() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt('shopId');
    if (shopId != null) {
      await fetchHallDetails(shopId);
      await fetchCurrentBalance(shopId);
    } else {
      setState(() => _isLoading = false);
      _showMessage("No Shop ID found in saved data", isError: true);
    }
  }

  Future<void> fetchHallDetails(int shopId) async {
    try {
      final url = Uri.parse('$baseUrl/shops/$shopId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          selectedHall = jsonDecode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        _showMessage(
          "Failed to load shop details (Code: ${response.statusCode})",
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage("Error connecting to server: $e", isError: true);
    }
  }


  Future<void> fetchCurrentBalance(int shopId) async {
    try {
      final url = Uri.parse('$baseUrl/home/current-balance/$shopId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          totalIncome = (data['totalIncome'] ?? 0).toDouble();
          totalExpense = (data['totalExpense'] ?? 0).toDouble();
          drawingIn = (data['totalDrawingIn'] ?? 0).toDouble();
          drawingOut = (data['totalDrawingOut'] ?? 0).toDouble();
          currentBalance = (data['currentBalance'] ?? 0).toDouble();
        });
      } else {
        _showMessage("Failed to fetch current balance", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching current balance: $e", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final double screenWidth = size.width;
    final double screenHeight = size.height;
    double textScale = (screenWidth / 390).clamp(0.8, 1.4);
    double boxScale  = (screenHeight / 840).clamp(0.8, 1.4);


    return Scaffold(
      backgroundColor: royalLight.withValues(alpha: 0.2),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100), // Desktop width
          child: _isLoading
              ? const Center(
            child: CircularProgressIndicator(color: royal),
          )
              : SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  if (selectedHall != null)
                    Align(
                      alignment: Alignment.center,
                      child: _buildHallCard(selectedHall!, textScale, boxScale, screenWidth),
                    ),
                  Padding(
                    padding: EdgeInsets.only(top: 20 * textScale),
                    child: _buildCurrentBalanceBox(currentBalance, textScale, boxScale),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHallCard(
      Map<String, dynamic> hall,
      double textScale,
      double boxScale,
      double screenWidth,
      ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20 * boxScale),
        side: const BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16 * boxScale),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: (screenWidth > 900 ? 40 : 40) * boxScale,
              backgroundColor: royalLight,
              backgroundImage: hall['logo'] != null
                  ? MemoryImage(base64Decode(hall['logo']))
                  : null,
              child: hall['logo'] == null
                  ? Icon(Icons.home_work_rounded,
                  size: (screenWidth > 900 ? 40 : 40) * boxScale,
                  color: royal)
                  : null,
            ),
            SizedBox(width: 16 * boxScale),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hall['name'] ?? 'No Name',
                    style: TextStyle(
                      fontSize: 18 * textScale,
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4 * boxScale),
                  Text(
                    hall['address'] ?? 'No Address',
                    style: TextStyle(
                      fontSize: 14 * textScale,
                      color: royal,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentBalanceBox(double currentBalance, double textScale, double boxScale) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20 * boxScale),
        border: Border.all(
          color: royal,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 24 * boxScale,
          horizontal: 32 * boxScale,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 💰 Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 8 * boxScale),
                Text(
                  "Cash On Hand",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17 * textScale,
                    fontWeight: FontWeight.bold,
                    color: royal,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12 * boxScale),

            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: currentBalance),
              duration: const Duration(seconds: 1),
              builder: (context, value, child) => Text(
                "₹${value.toStringAsFixed(2)}",
                style: TextStyle(
                  fontSize: 34 * textScale,
                  fontWeight: FontWeight.w500,
                  color: royal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}