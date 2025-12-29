import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import 'package:intl/intl.dart';
import '../../public/main_navigation.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class AppPaymentPage extends StatefulWidget {
  const AppPaymentPage({super.key});

  @override
  State<AppPaymentPage> createState() => _AppPaymentPageState();
}

class _AppPaymentPageState extends State<AppPaymentPage> {
  final Razorpay _razorpay = Razorpay();
  bool isLoading = true;
  Map<String, dynamic>? currentPayment;
  List<dynamic> paymentHistory = [];
  int? shopId;
  Map<String, dynamic>? shopData;

  
  String formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  void initState() {
    super.initState();
    _initHallAndData();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _initHallAndData() async {
    final prefs = await SharedPreferences.getInstance();
    shopId = prefs.getInt('shopId');
    if (shopId == null) {
      _showMessage("Shop ID not found in saved preferences.");
      return;
    }
    await _fetchPaymentData();
  }

  Future<void> _fetchPaymentData() async {
    setState(() => isLoading = true);
    try {
      final hallRes = await http.get(Uri.parse('$baseUrl/shops/$shopId'));
      shopData = hallRes.statusCode == 200 ? json.decode(hallRes.body) : null;

      final currentRes =
      await http.get(Uri.parse('$baseUrl/api/app-payment/current/$shopId'));
      currentPayment =
      currentRes.statusCode == 200 ? json.decode(currentRes.body) : null;

      final historyRes =
      await http.get(Uri.parse('$baseUrl/api/app-payment/history/$shopId'));
      paymentHistory = historyRes.statusCode == 200
          ? json.decode(historyRes.body)
          : [];
    } catch (e) {
      _showMessage("Error fetching payment data: $e");
    }
    setState(() => isLoading = false);
  }

  Future<void> _createPayment() async {
    if (shopId == null) return _showMessage("Invalid hall ID.");
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/app-payment/create/$shopId'),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final payment = json.decode(res.body);
        currentPayment = payment;
        _startRazorpay(payment);
      } else {
        final msg = json.decode(res.body);
        _showMessage(msg['message'] ?? "Unable to create payment.");
      }
    } catch (e) {
      _showMessage("Error creating payment: $e");
    }
  }

  void _handlePaymentAction() {
    if (currentPayment == null) {
      _createPayment();
      return;
    }

    final status = currentPayment!['status'];
    final canRenew = currentPayment!['canRenew'] == true;

    if (status == 'PENDING' || status == 'FAILED') {
      _startRazorpay(currentPayment!);
    } else if (canRenew) {
      _createPayment();
    } else {
      _showMessage("Payment already completed and next year not yet available.");
    }
  }

  void _startRazorpay(Map<String, dynamic> payment) {
    final total = payment['totalAmount'] ?? payment['amount'] ?? 0;

    final options = {
      'key': 'rzp_live_RTDsYRSviCdE7N',
      'amount': (total * 100).toInt(),
      'name': 'Ramchin Shop Management',
      'description': '',
      'prefill': {'contact': '', 'email': ''},
      'external': {'wallets': ['paytm']},
      'theme.color': '#19527A',
      'notes': {'shop_id': shopId.toString()},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      _showMessage("Razorpay error: $e");
    }
  }

  Future<void> _handlePaymentSuccess(PaymentSuccessResponse response) async {
    _showMessage("✅ Payment Successful!");
    if (currentPayment != null) {
      await _updatePaymentStatus(
        currentPayment!['id'],
        'COMPLETED',
        response.paymentId,
      );
    }
    await _fetchPaymentData();
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    _showMessage("❌ Payment Failed: ${response.message}");
    if (currentPayment != null) {
      await _updatePaymentStatus(currentPayment!['id'], 'FAILED', null);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    _showMessage("External Wallet: ${response.walletName}");
  }

  Future<void> _updatePaymentStatus(
      int paymentId, String status, String? transactionId)
  async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/app-payment/update-status/$paymentId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'status': status,
          'transactionId': transactionId,
        }),
      );
      debugPrint(res.body);
    } catch (e) {
      _showMessage("Error updating payment: $e");
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style:  TextStyle(
            color: royal,
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

  bool canPay() {
    if (currentPayment == null) return true;
    return currentPayment!['canRenew'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("App Payment"),
        backgroundColor: royal,
        foregroundColor: Colors.white,
        centerTitle: true,
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
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: royal))
          : RefreshIndicator(
          color: royal,
          backgroundColor: Colors.white,
          onRefresh: _fetchPaymentData,
          child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 600, // 👈 works perfectly on all devices
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if(shopData!=null)
              _buildStatusCard(),
            if (currentPayment != null &&
                currentPayment!['status'] != 'COMPLETED')
              _buildCurrentPaymentCard(),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: Text(
                currentPayment != null
                    ? "Pay ₹${currentPayment!['totalAmount'] ?? currentPayment!['amount']} (incl. GST)"
                    : "Pay Yearly Fee",
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: canPay() ? royal : Colors.grey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              onPressed: canPay() ? _handlePaymentAction : null,
            ),

            const SizedBox(height: 24),
            Text(
              "Payment History",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: royal,
              ),
            ),
            const SizedBox(height: 8),
            paymentHistory.isEmpty
                ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  "No payment history found.",
                  style: TextStyle(
                    color: royal,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
            )
                : Column(
              children:
              paymentHistory.map((p) => _buildHistoryTile(p)).toList(),
            ),
            const SizedBox(height: 70),
          ],
        ),
      ),
                ),
              ),
          ),
      ),
    );
  }

  Widget _buildCurrentPaymentCard() {
    final p = currentPayment!;
    final base = p['baseAmount'] ?? 0;
    final gst = p['gstAmount'] ?? 0;
    final total = p['totalAmount'] ?? p['amount'] ?? 0;
    final duedate = p['duedate'] ?? p['periodStart'];
    final status = p['status'];

    String title;
    if (status == 'COMPLETED') {
      title = "Next Payment";
    } else if (status == 'PENDING') {
      title = "Current Payment";
    } else if (status == 'FAILED') {
      title = "Retry Payment";
    } else {
      title = "Payment Plan";
    }

    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: royal, width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: royal,
              ),
            ),
            const SizedBox(height: 8),
            _infoRow("Due Date", formatDate(duedate)),
            _infoRow("Status", status),
            _infoRow("Base Amount", "₹$base"),
            _infoRow("GST", "₹$gst"),
            _infoRow("Total Payable", "₹$total"),
            _infoRow("Period", "${formatDate(p['periodStart'])} → ${formatDate(p['periodEnd'])}"),
            if (p['transactionId'] != null)
              _infoRow("Txn ID", p['transactionId']),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
              TextStyle(color: royal, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: royal)),
        ],
      ),
    );
  }

  Widget _buildHistoryTile(dynamic p) {
    final base = p['BaseAmount'] ?? 0;
    final gst = p['gstAmount'] ?? 0;
    final total = p['amount'] ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: royal, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: royal.withValues(alpha:0.2),
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ExpansionTile(
        leading: Icon(Icons.receipt_long, color: royal),
        title: Text(
          "₹$total - ${p['status']}",
          style: TextStyle(
            color: royal,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: Text(
          "From ${formatDate(p['periodStart'])} to ${formatDate(p['periodEnd'])}",
          style: TextStyle(color: royal.withValues(alpha:0.9)),
        ),
        childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _infoRow("Base Amount", "₹$base"),
          _infoRow("GST", "₹$gst"),
          _infoRow("Total Paid", "₹$total"),
          _infoRow("Status", p['status']),
          _infoRow("Period Start", formatDate(p['periodStart'])),
          _infoRow("Period End", formatDate(p['periodEnd'])),
          if (p['createdAt'] != null)
            _infoRow("Paid On", formatDate(p['createdAt'])),
        ],
      ),
    );
  }

  Widget _buildStatusCard() {
    if (shopData == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final hallDueStr = shopData?['duedate'];
    final hallDueDate = hallDueStr != null ? DateTime.tryParse(hallDueStr) : null;
    final createdAt = shopData?['created_at'];
    final created = formatDate(createdAt ?? '');

    if (paymentHistory.isEmpty) {
      if (hallDueDate != null && now.isBefore(hallDueDate)) {
        return _statusCard(
          title: "Trial Period",
          rows: [
            _infoRow("Shop Created", created),
            _infoRow("Trial Ends", formatDate(hallDueStr)),
          ],
          statusText: "TRIAL ACTIVE",
          statusColor: royal,
        );
      } else {
        return _statusCard(
          title: "Trial Expired",
          rows: [
            _infoRow("Trial Ended", formatDate(hallDueStr)),
          ],
          statusText: "TRIAL EXPIRED – PAYMENT DUE",
          statusColor: Colors.red[800],
        );
      }
    }

    paymentHistory.sort((a, b) {
      final aStart = DateTime.tryParse(a['periodStart'] ?? '') ?? DateTime(2000);
      final bStart = DateTime.tryParse(b['periodStart'] ?? '') ?? DateTime(2000);
      return bStart.compareTo(aStart);
    });
    final failedPayment = paymentHistory.firstWhere(
          (p) => (p['status'] ?? '').toString().toLowerCase() == 'failed',
      orElse: () => {},
    );

    if (failedPayment.isNotEmpty) {
      return _statusCard(
        title: "Payment Failed",
        rows: [
          _infoRow("Attempted On", formatDate(failedPayment['createdAt'] ?? '')),
          _infoRow("Reason", "Payment was not successful"),
        ],
        statusText: "PAYMENT FAILED – TRY AGAIN",
        statusColor: Colors.red[800],
      );
    }

    final activePlan = paymentHistory.firstWhere(
          (p) {
        final s = DateTime.tryParse(p['periodStart'] ?? '');
        final e = DateTime.tryParse(p['periodEnd'] ?? '');
        return s != null && e != null && now.isAfter(s) && now.isBefore(e);
      },
      orElse: () => {},
    );

    final nextPlan = paymentHistory.firstWhere(
          (p) {
        final s = DateTime.tryParse(p['periodStart'] ?? '');
        return s != null && s.isAfter(now);
      },
      orElse: () => {},
    );

    if (activePlan.isNotEmpty) {
      final current = activePlan;

      String label = "Next Due Date";
      String value = formatDate(current['periodEnd']);

      if (nextPlan.isNotEmpty) {
        label = "Next Plan Starts On";
        value = formatDate(nextPlan['periodStart']);
      }

      return _statusCard(
        title: "Current Plan",
        rows: [
          _infoRow(
            "Plan Period",
            "${formatDate(current['periodStart'])} → ${formatDate(current['periodEnd'])}",
          ),
          _infoRow(label, value),
        ],
        statusText: "ACTIVE",
        statusColor: Colors.green[800],
      );
    }

    final last = paymentHistory.first;
    if (hallDueDate != null && now.isBefore(hallDueDate)) {
      if (nextPlan.isNotEmpty) {
        return _statusCard(
          title: "Trial Period (Before Next Plan)",
          rows: [
            _infoRow("Trial Ends", formatDate(nextPlan['periodStart'])),
            _infoRow("Upcoming Plan Starts", formatDate(nextPlan['periodStart'])),
          ],
          statusText: "TRIAL ACTIVE",
          statusColor: royal,
        );
      } else {
        return _statusCard(
          title: "Trial Period (Post Plan)",
          rows: [
            _infoRow("Trial Ends", formatDate(hallDueStr)),
            _infoRow("Last Plan Ended", formatDate(last['periodEnd'])),
          ],
          statusText: "TRIAL ACTIVE",
          statusColor: royal,
        );
      }
    }
    else if (nextPlan.isNotEmpty) {
      final n = nextPlan;
      return _statusCard(
        title: "Next Plan (Paid)",
        rows: [
          _infoRow("Next Plan Starts", formatDate(n['periodStart'])),
          _infoRow("Next Plan Ends", formatDate(n['periodEnd'])),
        ],
        statusText: "UPCOMING PLAN CONFIRMED",
        statusColor: Colors.orange[800],
      );
    } else {
      return _statusCard(
        title: "Plan Expired",
        rows: [
          _infoRow("Last Plan Ended", formatDate(last['periodEnd'])),
        ],
        statusText: "EXPIRED – PAYMENT DUE",
        statusColor: Colors.red[800],
      );
    }
  }

  Widget _statusCard({
    required String title,
    required List<Widget> rows,
    required String statusText,
    Color? statusColor,
  }) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: royal, width: 1),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: royal,
              ),
            ),
            const SizedBox(height: 8),
            ...rows,
            const SizedBox(height: 8),
            Text(
              "Status: $statusText",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: statusColor ?? royal,
              ),
            ),
          ],
        ),
      ),
    );
  }

}
