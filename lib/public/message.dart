import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/config.dart';
import '../admin/manage/app_payment.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class AdminMessagesPage extends StatefulWidget {
  const AdminMessagesPage({super.key});

  @override
  State<AdminMessagesPage> createState() => _AdminMessagesPageState();
}

class _AdminMessagesPageState extends State<AdminMessagesPage> {

  bool _isLoading = true;
  List<dynamic> _messages = [];
  String? _errorMessage;
  Map<String, dynamic>? shopDetails;
  String? _dueMessage; // 🧾 For Payment Reminder
  Color? _dueColor; // 🎨 For dynamic color (orange/red)

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _fetchHallDetails();
  }
  // void _showMessage(String message) {
  //   ScaffoldMessenger.of(context).hideCurrentSnackBar();
  //   ScaffoldMessenger.of(context).showSnackBar(
  //     SnackBar(
  //       backgroundColor: Colors.transparent, // Let border container show
  //       elevation: 0,
  //       behavior: SnackBarBehavior.floating,
  //       margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //       duration: const Duration(seconds: 3),
  //       content: Container(
  //         decoration: BoxDecoration(
  //           color: Colors.white,
  //           borderRadius: BorderRadius.circular(12),
  //           border: Border.all(color: royal, width: 2), // 💙 Royal blue border
  //         ),
  //         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //         child: Text(
  //           message,
  //           style: const TextStyle(
  //             color: royal,
  //             fontSize: 16,
  //             fontWeight: FontWeight.w600,
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  Future<void> _fetchHallDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt('shopId');
    if (shopId == null) return;

    try {
      final res = await http.get(Uri.parse('$baseUrl/shops/$shopId'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          shopDetails = data;
        });

        // 🕒 Check Due Date and Create Reminder
        if (data['duedate'] != null && data['duedate'].toString().isNotEmpty) {
          final duedate = DateTime.tryParse(data['duedate']);
          if (duedate != null) {
            final now = DateTime.now();
            final daysLeft = duedate.difference(now).inDays;
            final formattedDate =
                "${duedate.day.toString().padLeft(2, '0')}-${duedate.month.toString().padLeft(2, '0')}-${duedate.year}";

            if (daysLeft < 0) {
              // 🔴 Overdue
              setState(() {
                _dueMessage =
                "Your payment is overdue by ${daysLeft.abs()} days.\nIt was due on $formattedDate.\nPlease make the payment as soon as possible.";
                _dueColor = Colors.red.shade700;
              });
            } else if (daysLeft <= 30) {
              // 🟧 Upcoming due within 30 days
              setState(() {
                _dueMessage =
                "Only $daysLeft days remaining before the due date.\nPlease ensure payment by $formattedDate.";
                _dueColor = Colors.orange.shade800;
              });
            } else {
              // ✅ Not due soon
              setState(() {
                _dueMessage = null;
                _dueColor = null;
              });
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching shop details: $e");
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final shopId = prefs.getInt('shopId');

      if (shopId == null) {
        setState(() {
          _errorMessage = "❌ Shop ID not found in preferences.";
          _isLoading = false;
        });
        return;
      }

      final response =
      await http.get(Uri.parse('$baseUrl/message/shop/$shopId'));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _messages = data is List ? data : [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
          "❌ Failed to load messages (${response.statusCode}).";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "❌ Error fetching messages: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        foregroundColor: Colors.white,
        title: const Text("Messages"),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.white,
            onPressed: () async {
              await _fetchMessages();
              await _fetchHallDetails();
            },
          ),
        ],
      ),

      // 📱 Body Section
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
        child: Text(
          _errorMessage!,
          textAlign: TextAlign.center,
          style: TextStyle(color: royal, fontSize: 16),
        ),
      )
          : RefreshIndicator(
          color: royal,
          backgroundColor: Colors.white,
          onRefresh: () async {
            await _fetchMessages();
            await _fetchHallDetails();
          },
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
            // 💳 Payment Due Card (only if due or overdue)
            if (_dueMessage != null)
              Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: royal, width: 1.2),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: _dueColor ?? royal,
                              size: 22),
                          const SizedBox(width: 8),
                          Text(
                            "Payment Reminder",
                            style: TextStyle(
                              color: _dueColor ?? royal,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _dueMessage!,
                        style: TextStyle(
                          color: _dueColor ?? royal,
                          fontSize: 15,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 👉 CLICK HERE TO PAY
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AppPaymentPage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payment),
                          label: const Text(
                            "Click here to pay",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: _dueColor ?? royal,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 💬 Messages List
            if (_messages.isEmpty && _dueMessage == null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    "No messages found for this shop.",
                    style:
                    TextStyle(color: royal, fontSize: 16),
                  ),
                ),
              )
            else
              ..._messages.map((msg) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: royal, width: 1.2),
                ),
                child: Text(
                  msg['message'] ?? '',
                  style: TextStyle(
                    color: royal,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )),
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
