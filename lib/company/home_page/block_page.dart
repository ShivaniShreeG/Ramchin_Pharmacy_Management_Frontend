import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../public/config.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class BlockHallPage extends StatefulWidget {
  final dynamic hall;
  const BlockHallPage({super.key, required this.hall});

  @override
  State<BlockHallPage> createState() => _BlockHallPageState();
}

class _BlockHallPageState extends State<BlockHallPage> {
  final _reasonController = TextEditingController();
  bool _isBlocking = false;
  List<String> _blockReasons = [];
  bool? _isActive;
  bool _isLoading = true;

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

  @override
  void initState() {
    super.initState();
    _fetchHallDetails();
  }

  Future<void> _fetchHallDetails() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('$baseUrl/shops/${widget.hall['shop_id']}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isActive = data['is_active'] ?? true;
          _blockReasons = List<String>.from(data['block_reasons'] ?? []);
        });
      } else {
        _showMessage('Failed to load hall details');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _blockUnblockHall(bool block) async {
    final reason = _reasonController.text.trim();
    if (block && reason.isEmpty) {
      _showMessage('Please provide a reason to block the hall');
      return;
    }

    setState(() => _isBlocking = true);

    try {
      final url = Uri.parse('$baseUrl/shops/${widget.hall['shop_id']}/block');
      final response = await http.patch(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'block': block, 'reason': block ? reason : null}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _showMessage(data['message']);
        _reasonController.clear();

        setState(() {
          _isActive = !block;
          _blockReasons = block ? [reason] : [];
        });
      } else {
        _showMessage('Error: ${response.body}');
      }
    } catch (e) {
      _showMessage('Error: $e');
    } finally {
      setState(() => _isBlocking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
        appBar: _isLoading
    ? AppBar(
          backgroundColor: royal,
          title: const Text(
            'Loading...', style: TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color:Colors.white),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        )
        : AppBar(
          backgroundColor: royal,
          elevation: 6,
          title: Text(
            "${_isActive == true ? 'Block' : 'Unblock'} - ${widget.hall['name'] ?? 'Shop'}",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
          ),
        ),

    body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Colors.white),
      )
          : Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _isActive == true
                    ? 'Reason for blocking the shop:'
                    : 'Block Reason(s):',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: royal,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 12),

              SizedBox(
                width: 350,
                child: Card(
                  color: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: royal,width: 1)
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _isActive == true
                        ? TextField(
                      controller: _reasonController,
                      maxLines: 3,
                      cursorColor: royal,
                      decoration: const InputDecoration(
                        hintText: 'Enter reason...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: royal),
                      ),
                      style: const TextStyle(color: royal),
                    )
                        : _blockReasons.isEmpty
                        ? const Text(
                      'No reason provided',
                      style: TextStyle(color: royal),
                      textAlign: TextAlign.center,
                    )
                        : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _blockReasons
                          .map(
                            (r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            "• $r",
                            style: const TextStyle(color: royal),
                          ),
                        ),
                      )
                          .toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: 200,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isBlocking ? null : () => _blockUnblockHall(_isActive!),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: royal,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isBlocking
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                    _isActive == true ? 'Block Shop' : 'Unblock Shop',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
