import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../public/config.dart';
import '../../../../public/main_navigation.dart';
import 'sales_report.dart';

const Color royal = Color(0xFF875C3F);

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  bool loading = true;
  Map<String, dynamic>? reportData;
  DateTime selectedDate = DateTime.now();
  Map<String, dynamic>? shopDetails;
  bool reportFetched = false;

  @override
  void initState() {
    super.initState();
    fetchReport();
    _fetchHallDetails();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        backgroundColor: royal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _fetchHallDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");

    try {
      final url = Uri.parse('$baseUrl/shops/$shopId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        shopDetails = jsonDecode(response.body);
      }
    } catch (e) {
      _showMessage("Error fetching hall details: $e");
    } finally {
      setState(() {});
    }
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 95,
      decoration: BoxDecoration(
        color: royal,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: royal.withValues(alpha:0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ClipOval(
            child: hall['logo'] != null
                ? Image.memory(
              base64Decode(hall['logo']),
              width: 70,
              height: 70,
              fit: BoxFit.cover,
            )
                : Container(
              width: 70,
              height: 70,
              color: Colors.white, // 👈 soft teal background
              child: const Icon(
                Icons.home_work_rounded,
                color: royal,
                size: 35,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                hall['name']?.toString().toUpperCase() ?? "HALL NAME",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> fetchReport() async {
    setState(() {
      loading = true;
      reportFetched = false;
    });

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);

    try {
      final res = await http.get(
        Uri.parse("$baseUrl/sales/report/$shopId?date=$dateStr"),
      );

      if (res.statusCode == 200) {
        reportData = jsonDecode(res.body);
      } else {
        reportData = null;
      }
    } catch (e) {
      reportData = null;
      _showMessage("Error fetching report: $e");
    }

    setState(() {
      loading = false;
      reportFetched = true;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: royal, // header background color
              onPrimary: Colors.white, // header text color
              onSurface: royal, // calendar day numbers color
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: royal, // "OK" / "CANCEL" buttons
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      fetchReport();
    }
  }

  Widget _buildSummary() {
    if (reportData == null) return const SizedBox.shrink();
    final summary = reportData!['summary'];
    return Card(
      elevation: 3,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: royal.withValues(alpha:0.4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Text(
                "Summary",
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: royal),
              ),
            ),
            const SizedBox(height: 12),
            _buildSummaryRow("Total Sales", summary['totalSales']),
            _buildSummaryanother("Total Bills", summary['totalBills']),
            _buildSummaryRow("Total Profit", summary['totalProfit']),
            _buildSummaryanother("Units Sold", summary['totalUnitsSold']),
          ],
        ),
      ),
    );
  }

  bool get hasMedicineData {
    if (!reportFetched) return false;
    if (reportData == null) return false;

    final medicineWise = reportData!['medicineWise'];
    return medicineWise != null && medicineWise.isNotEmpty;
  }

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.medical_services_outlined, size: 70, color: royal),
          SizedBox(height: 16),
          Text(
            "No medicine found",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: royal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateAndPdfRow({required bool showPdf}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: royal,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _pickDate,
          child: Text(
            DateFormat('dd MMM yyyy').format(selectedDate),
            style: const TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),

        if (showPdf) ...[
          const SizedBox(height: 12),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: royal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
            label: const Text(
              "Generate PDF",
              style: TextStyle(fontSize: 16, color: Colors.white),
            ),
            onPressed: _goToPdfPage,
          ),
        ],
      ],
    );
  }

  void _goToPdfPage() {
    if (reportData == null || shopDetails == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No data available to generate PDF")),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SalesReportPdfPage(
          reportData: reportData!,      // ✅ force unwrap after check
          shopDetails: shopDetails!,    // ✅
          selectedDate: selectedDate,
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value is double ? '₹${value.toStringAsFixed(2)}' : '₹$value',
            style: const TextStyle(color: royal, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryanother(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(
            '$value',
            style: const TextStyle(color: royal, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineList() {
    if (reportData == null || reportData!['medicineWise'].isEmpty) {
      return Column(
        children: const [
          SizedBox(height: 50),
          Icon(Icons.medical_services_outlined, size: 64, color: royal),
          SizedBox(height: 12),
          Text(
            "No sales data found",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: royal),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(reportData!['medicineWise'].length, (index) {
        final med = reportData!['medicineWise'][index];
        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: royal.withValues(alpha:0.35)),
          ),
          child: ListTile(
            title: Text(med['medicine'], style: const TextStyle(fontWeight: FontWeight.bold, color: royal)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Units Sold: ${med['quantity_units']}"),
                Text("Strips Sold: ${med['quantity_strips'].toStringAsFixed(2)}"),
                Text("Sales: ₹${med['sales'].toStringAsFixed(2)}"),
                Text("Profit: ₹${med['profit'].toStringAsFixed(2)}"),
              ],
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text(
          "Sales Summary",
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(Icons.home, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MainNavigation(initialIndex: 2)),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: royal))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (shopDetails != null) _buildHallCard(shopDetails!),

            const SizedBox(height: 16),

            _buildDateAndPdfRow(showPdf: hasMedicineData),

            const SizedBox(height: 16),

            if (hasMedicineData) ...[
              _buildSummary(),

              const SizedBox(height: 12),

              const Center(
                child: Text(
                  "Medicine-wise List",
                  style: TextStyle(
                    color: royal,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              _buildMedicineList(),
            ] else ...[
              const SizedBox(height: 40),
              _buildNoDataView(),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
