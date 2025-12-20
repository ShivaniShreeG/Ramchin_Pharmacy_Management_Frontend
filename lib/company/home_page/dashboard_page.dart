import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';
import '../../public/config.dart';
import 'package:intl/intl.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class DashboardPage extends StatefulWidget {
  final dynamic selectedHall;

  const DashboardPage({super.key, required this.selectedHall});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? stats;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchHallStats();
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

  Future<void> _fetchHallStats() async {
    try {
      final shopId =
          widget.selectedHall['shopId'] ?? widget.selectedHall['shop_id'];
      final response =
      await http.get(Uri.parse("$baseUrl/dashboard/$shopId/stats"));

      if (response.statusCode == 200) {
        setState(() {
          stats = jsonDecode(response.body);
          loading = false;
        });
      } else {
        setState(() {
          _showMessage("Failed to fetch stats: ${response.statusCode}");
          loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _showMessage("Error: $e");
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hall = widget.selectedHall;
    String formattedDueDate = "No Due Date";
    if (hall['duedate'] != null && hall['duedate'].toString().isNotEmpty) {
      try {
        DateTime parsedDate = DateTime.parse(hall['duedate']);
        formattedDueDate = DateFormat('dd MMM yyyy').format(parsedDate);
      } catch (e) {
        formattedDueDate = hall['duedate'].toString();
      }
    }

    return Scaffold(
      backgroundColor: royalLight.withValues(alpha: 0.3),
      appBar: AppBar(
        title: const Text(
          "Dashboard",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: royal,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),
      body: hall == null
          ? const Center(
        child: Text(
          "No shop selected",
          style: TextStyle(fontSize: 16, color: royal),
        ),
      )
          : loading
          ? const Center(
        child: CircularProgressIndicator(color: royal),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Revenue vs Expenses",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: royal,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: _getPieSections(),
                  centerSpaceRadius: 0,
                  sectionsSpace: 6,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegend(
                    Colors.green,
                    "Revenue ₹${(stats?['totalIncome'] ?? 0).toStringAsFixed(2)}",
                  ),
                  const SizedBox(height: 8),
                  _buildLegend(
                    Colors.red,
                    "Expenses ₹${(stats?['totalExpense'] ?? 0).toStringAsFixed(2)}",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Card(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (hall['logo'] != null)
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: MemoryImage(base64Decode(hall['logo'])),
                        backgroundColor: royal,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      hall['name'] ?? "No Name",
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: royal,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Hall ID row added here
                    _buildDetailRow(
                        icon: Icons.perm_identity,
                        text: "Shop ID: ${hall['shopId'] ?? hall['shop_id'] ?? 'N/A'}"),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                        icon: Icons.location_on,
                        text: hall['address'] ?? "No Address"),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                        icon: Icons.phone,
                        text: hall['phone'] ?? "No Phone"),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                        icon: Icons.email,
                        text: hall['email'] ?? "No Email"),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      icon: Icons.date_range,
                      text: "Due Date: $formattedDueDate",
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, color: royal),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: const TextStyle(fontSize: 16, color: royal)),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
              color: royal, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  List<PieChartSectionData> _getPieSections() {
    final revenue = (stats?['totalIncome'] ?? 0).toDouble();
    final expenses = (stats?['totalExpense'] ?? 0).toDouble();
    final total = revenue + expenses;

    if (total == 0) {
      return [
        PieChartSectionData(
          color: Colors.white,
          value: 1,
          title: "No Data",
          radius: 100,
          titleStyle: const TextStyle(
              color: royal, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ];
    }

    double revenuePercent = (revenue / total) * 100;
    double expensesPercent = (expenses / total) * 100;

    return [
      PieChartSectionData(
        color: Colors.green,
        value: revenue,
        title: "${revenuePercent.toStringAsFixed(1)}%",
        radius: 100,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
      PieChartSectionData(
        color: Colors.red,
        value: expenses,
        title: "${expensesPercent.toStringAsFixed(1)}%",
        radius: 100,
        titleStyle: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    ];
  }
}

