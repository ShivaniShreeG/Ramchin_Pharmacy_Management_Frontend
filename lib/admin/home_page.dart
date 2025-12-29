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
  String? shopName;
  String? shopAddress;
  String? shopLogo;
  bool isLoading = true;
  double totalIncome = 0.0;
  double totalExpense = 0.0;
  double drawingIn = 0.0;
  double drawingOut = 0.0;
  double currentBalance = 0.0;

  double overallValue = 0.0; // total stock value
  double totalSales = 0.0;
  double totalProfit = 0.0;
  int totalUnitsSold = 0;
  int totalBills = 0;
  int totalMedicineWithStock = 0;
  double cashIncome = 0.0;
  double onlineIncome = 0.0;

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
      await _fetchHallData();
      await fetchCurrentBalance(shopId);
      await fetchGoodsAndSales(shopId);
    } else {
      setState(() => isLoading = false);
      _showMessage("No Shop ID found in saved data", isError: true);
    }
  }

  Future<void> _fetchHallData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    if (shopId == null) {
      setState(() => isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/shops/$shopId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          shopName = data["name"];
          shopAddress = data["address"];
          shopLogo = data["logo"];
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchGoodsAndSales(int shopId) async {
    try {
      // Get current date in YYYY-MM-DD format
      final now = DateTime.now();
      final currentDate = "${now.year.toString().padLeft(4,'0')}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}";

      // Append date as query parameter
      final url = Uri.parse('$baseUrl/home/totals/$shopId?date=$currentDate');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          overallValue = (data['overallValue'] ?? 0).toDouble();
          totalMedicineWithStock = data['totalMedicinesWithStock'] ?? 0;
          totalSales = (data['totalSales'] ?? 0).toDouble();
          totalProfit = (data['totalProfit'] ?? 0).toDouble();
          totalUnitsSold = data['totalUnitsSold'] ?? 0;
          totalBills = data['totalBills'] ?? 0;
        });
      } else {
        _showMessage("Failed to fetch goods and sales", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching goods and sales: $e", isError: true);
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

          onlineIncome = (data['onlineIncome'] ?? 0).toDouble();
          cashIncome = (data['cashIncome'] ?? 0).toDouble();
        });
      } else {
        _showMessage("Failed to fetch current balance", isError: true);
      }
    } catch (e) {
      _showMessage("Error fetching current balance: $e", isError: true);
    }
  }

  Widget _buildStatsCards(double textScale) {
    final stats = [
      {"title": "Goods Value", "value": overallValue, "color": Colors.orange},
      {"title": "Total Medicine", "value": totalMedicineWithStock.toDouble(), "color": Colors.cyan},
      {"title": "Today Sales", "value": totalSales, "color": Colors.green},
      {"title": "Today Profit", "value": totalProfit, "color": Colors.blue},
      {"title": "Units Sold", "value": totalUnitsSold.toDouble(), "color": Colors.purple},
      {"title": "Total Bills", "value": totalBills.toDouble(), "color": Colors.teal},
    ];

    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          double maxWidth = constraints.maxWidth > 600 ? 600 : constraints.maxWidth;
          int cardsPerRow = 2; // Always 2 cards per row even on phones
          double spacing = 16;
          double cardWidth = (maxWidth - (spacing * (cardsPerRow - 1))) / cardsPerRow;

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Wrap(
              spacing: spacing,
              runSpacing: spacing,
              alignment: WrapAlignment.center,
              children: stats.map((stat) {
                return SizedBox(
                  width: cardWidth,
                  child: Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: royal, width: 1.5),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            stat["title"]?.toString() ?? '',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14 * textScale,
                              fontWeight: FontWeight.w500,
                              color: royal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(begin: 0, end: stat["value"] as double),
                            duration: const Duration(seconds: 1),
                            builder: (context, value, child) => Text(
                              (stat["title"] == "Units Sold" ||
                                  stat["title"] == "Total Bills" ||
                                  stat["title"] == "Total Medicine")
                                  ? value.toInt().toString()
                                  : "₹${value.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontSize: 18 * textScale,
                                fontWeight: FontWeight.bold,
                                color: stat["color"] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
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
      body: SafeArea(
        child: SingleChildScrollView(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: isLoading
                  ? const Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(color: royal),
              )
                  : Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHallCard(),
                    const SizedBox(height: 20),
                    _buildStatsCards(textScale, ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: EdgeInsets.only(top: 20 * textScale),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 600), // max width constraint
                          child: _buildCurrentBalanceBox(cashIncome, textScale, boxScale),
                        ),
                      ),
                    ),

                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHallCard() {
    final screenWidth = MediaQuery.of(context).size.width;

    // Responsive scale: phones → small, tablets/desktops → bigger
    double textScale = (screenWidth / 390).clamp(0.8, 1.4);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25 * textScale,
              backgroundColor: royalLight,
              backgroundImage: (shopLogo != null && shopLogo!.isNotEmpty)
                  ? MemoryImage(base64Decode(shopLogo!))
                  : null,
              child: (shopLogo == null || shopLogo!.isEmpty)
                  ? Icon(
                Icons.home_work_rounded,
                size: 25 * textScale,
                color: royal,
              )
                  : null,
            ),

            SizedBox(width: 16 * textScale),

            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shopName ?? "Unknown Shop",
                    style: TextStyle(
                      fontSize: 18 * textScale,   // ⬅ Responsive Title
                      fontWeight: FontWeight.bold,
                      color: royal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: 4 * textScale),

                  Text(
                    shopAddress ?? "No address available",
                    style: TextStyle(
                      fontSize: 14 * textScale,   // ⬅ Responsive Address
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


  Widget _buildCurrentBalanceBox(double cash, double textScale, double boxScale) {
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
                SizedBox(width: 1 * boxScale),
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
              tween: Tween<double>(begin: 0, end: cash),
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