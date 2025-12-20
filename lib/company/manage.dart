import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../public/config.dart';
import 'home.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> with RouteAware {
  List<dynamic> _halls = [];
  int totalUsers = 0;
  int totalBookings = 0;

  bool _showForm = false;
  bool _isLoading = false;

  final _hallIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  String? _pickedImageBase64;

  @override
  void initState() {
    super.initState();
    fetchHalls();
    fetchCounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    fetchHalls();
    fetchCounts();
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

  Future<void> fetchHalls() async {
    try {
      final url = Uri.parse('$baseUrl/shops');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _halls = jsonDecode(response.body);
        });
      } else {
        _showMessage('❌ Failed to fetch shops: ${response.body}');
      }
    } catch (e) {
      _showMessage('❌ Error: $e');
    }
  }

  Future<void> fetchCounts() async {
    try {
      final url = Uri.parse('$baseUrl/dashboard/counts');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          totalUsers = data['activeUsersCount'] ?? 0;
          totalBookings = data['totalBillingsCount'] ?? 0;
        });
      }
    } catch (e) {
      _showMessage('❌ Error: $e');
    }
  }

  Future<void> addHall() async {
    setState(() => _isLoading = true);

    int? shopId;
    if (_hallIdController.text.isNotEmpty) {
      shopId = int.tryParse(_hallIdController.text);
      if (shopId == null) {
        _showMessage('❌ Shop ID must be a number');
        setState(() => _isLoading = false);
        return;
      }
    }

    final hall = {
      if (shopId != null)'shop_id': shopId,
      'name': _nameController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'address': _addressController.text,
      'logo': _pickedImageBase64,
    };

    try {
      final url = Uri.parse('$baseUrl/shops');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(hall),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _hallIdController.clear();
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _addressController.clear();
        _pickedImageBase64 = null;
        setState(() => _showForm = false);

        fetchHalls();
        fetchCounts();
        _showMessage("✅ Shop registered successfully");
      } else {
        _showMessage('❌ Failed to add shop: ${response.body}');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showMessage('❌ Error: $e');
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _pickedImageBase64 = base64Encode(bytes);
      });
    }
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboard = TextInputType.text, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      style:  TextStyle(color: royal),
      cursorColor: royal,
      decoration: InputDecoration(
        labelText: label,
        labelStyle:  TextStyle(color: royal),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: royal, width: 1),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: royal, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildRegisterHallForm() {
    return Card(
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.white,
      shadowColor: royal.withValues(alpha:0.3),
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            _buildTextField(_hallIdController, 'Shop ID (optional)'),
            const SizedBox(height: 16),
            _buildTextField(_nameController, 'Name'),
            const SizedBox(height: 16),
            _buildTextField(_phoneController, 'Phone', keyboard: TextInputType.phone),
            const SizedBox(height: 16),
            _buildTextField(_emailController, 'Email', keyboard: TextInputType.emailAddress),
            const SizedBox(height: 16),
            _buildTextField(_addressController, 'Address', maxLines: 2),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.upload, color: royal),
              label: const Text("Upload Logo", style: TextStyle(color: royal)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
            ),
            if (_pickedImageBase64 != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor:Colors.white,
                  backgroundImage: MemoryImage(base64Decode(_pickedImageBase64!)),
                ),
              ),
            const SizedBox(height: 24),
            _isLoading
                ? const CircularProgressIndicator(color: royal)
                : ElevatedButton(
              onPressed: addHall,
              style: ElevatedButton.styleFrom(
                backgroundColor:  royal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text(
                "Submit",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountBox(String title, int count) {
    return Expanded(
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: Colors.white,
        shadowColor: royal.withValues(alpha:0.3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                count.toString(),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: royal,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: royal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHallCard(dynamic hall) {

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HomePageWithSelectedHall(selectedHall: hall),
          ),
        );
        fetchHalls();
        fetchCounts();
      },
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: royal,width: 1)),
        color: Colors.white,
        shadowColor: royal.withValues(alpha:0.3),
        margin: const EdgeInsets.symmetric(vertical: 10),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: royalLight.withValues(alpha: 0.3),
                backgroundImage: hall['logo'] != null
                    ? MemoryImage(base64Decode(hall['logo']))
                    : null,
                child: hall['logo'] == null
                    ? const Icon(Icons.home_work, size: 40, color: royal)
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hall['name'] ?? 'No Name',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: royal,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      hall['address'] ?? 'No Address',
                      style: const TextStyle(
                        fontSize: 14,
                        color: royal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: royalLight.withValues(alpha: 0.2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showForm = !_showForm;
                  if (_showForm) {
                    _hallIdController.clear();
                    _nameController.clear();
                    _phoneController.clear();
                    _emailController.clear();
                    _addressController.clear();
                    _pickedImageBase64 = null;
                  }
                });
              },
              icon: Icon(
                _showForm ? Icons.close : Icons.add_business,
                size: 24,
                color: Colors.white,
              ),
              label: Text(
                _showForm ? "Close Form" : "Register Shop",
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: royal,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_showForm) _buildRegisterHallForm(),
            const SizedBox(height: 16),
            Row(
              children: [
                _buildCountBox('Shops', _halls.length),
                const SizedBox(width: 12),
                _buildCountBox('Users', totalUsers),
                const SizedBox(width: 12),
                _buildCountBox('Billings', totalBookings),
              ],
            ),
            const SizedBox(height: 24),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Registered Shops",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: royal,
                ),
              ),
            ),
            const SizedBox(height: 12),
            ..._halls.map((hall) => _buildHallCard(hall)),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
