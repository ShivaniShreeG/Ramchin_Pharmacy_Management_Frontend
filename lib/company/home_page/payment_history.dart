import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../public/config.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class TransactionHistoryPage extends StatefulWidget {
  final dynamic hall;

  const TransactionHistoryPage({super.key, required this.hall});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  List<dynamic> transactions = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
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

  Future<void> _fetchTransactions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/app-payment/history/${widget.hall['shop_id']}'),
      );

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        setState(() {
          transactions = data;
          loading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          transactions = [];
          loading = false;
        });
      } else {
        setState(() {
          _showMessage("Failed to load: ${response.body}");
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

  String _formatDate(String iso) {
    try {
      final date = DateTime.parse(iso);
      return "${date.day.toString().padLeft(2, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.year}";
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Transactions - ${widget.hall['name'] ?? 'Shop'}",
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: royal,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: royal))
          : error != null
          ? Center(
        child: Text(
          error!,
          style: const TextStyle(color: royal),
        ),
      )
          : transactions.isEmpty
          ? const Center(
        child: Text(
          "No transactions found.",
          style: TextStyle(color: royal, fontSize: 16),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(12),
        child: ListView.separated(
          padding: const EdgeInsets.only(bottom: 80, top: 12),
          itemCount: transactions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12), 
          itemBuilder: (context, index) {
            final tx = transactions[index];

            final baseAmount = tx['BaseAmount'] ?? 0;
            final gstAmount = tx['gstAmount'] ?? 0;
            final total = tx['totalAmount'] ?? 0;
            final status = tx['status'] ?? 'N/A';
            final transactionId = tx['transactionId'] ?? '-';
            final paidAt = _formatDate(tx['paidAt']);
            final start = _formatDate(tx['periodStart']);
            final end = _formatDate(tx['periodEnd']);

            return Card(
              elevation: 2,
              shadowColor: royal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: royal, width: 1),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Transaction ID:",
                          style: TextStyle(
                            color: royal,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          transactionId,
                          style: const TextStyle(color: royal,),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Paid At:", style: TextStyle(color: royal)),
                        Text(paidAt, style: TextStyle(color: royal)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Period Start:", style: TextStyle(color: royal)),
                        Text(start, style: TextStyle(color: royal)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Period End:", style: TextStyle(color: royal)),
                        Text(end, style: TextStyle(color: royal)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Base Amount:", style: TextStyle(color: royal)),
                        Text("₹${baseAmount.toStringAsFixed(2)}", style: TextStyle(color: royal)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("GST (18%):", style: TextStyle(color: royal)),
                        Text("₹${gstAmount.toStringAsFixed(2)}", style: TextStyle(color: royal)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Total:", style: TextStyle(color: royal, fontWeight: FontWeight.bold)),
                        Text("₹${total.toStringAsFixed(2)}",
                            style: const TextStyle(color: royal,fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Status:", style: TextStyle(color: royal)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: status == "COMPLETED"
                                ? Colors.green[100]
                                : Colors.red[100],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              color: status == "COMPLETED"
                                  ? Colors.green[700]
                                  : Colors.red[700],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),


                  ],

                ),

              ),

            );

          },

        ),
      ),

    );
  }
}
