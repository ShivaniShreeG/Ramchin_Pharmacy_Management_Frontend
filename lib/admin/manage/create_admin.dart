import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../public/config.dart';
import '../../public/main_navigation.dart';
import 'package:flutter/services.dart';

const Color royal= Color(0xFF875C3F);

class CreateAdminPage extends StatefulWidget {
  const CreateAdminPage({super.key});

  @override
  State<CreateAdminPage> createState() => _CreateAdminPageState();
}

class _CreateAdminPageState extends State<CreateAdminPage> {
  final _formKey = GlobalKey<FormState>();

  final _userIdController = TextEditingController();
  final _passwordController = TextEditingController(text: "abc123");
  String _designation = "Staff";
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isUserIdAvailable = false;
  bool _isCheckingUserId = false;
  String? _userIdError;
  final _userIdFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _designationFocus = FocusNode();
  final _nameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();

  bool _isLoading = false;
  bool _isLoadingAdmins = true;
  bool _showForm = false;
  List<Map<String, dynamic>> _admins = [];
  Map<String, dynamic>? shopDetails;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _userIdFocus.dispose();
    _passwordFocus.dispose();
    _designationFocus.dispose();
    _nameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    super.dispose();
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

  Future<void> _checkUserIdUnique(String userId) async {
    if (userId.isEmpty) return;

    setState(() {
      _isCheckingUserId = true;
      _isUserIdAvailable = false;
      _userIdError = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/users/$shopId/check-user/$userId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _isUserIdAvailable = data["available"] == true;
          _userIdError =
          _isUserIdAvailable ? null : "User ID already exists";
        });
      }
    } catch (e) {
      setState(() {
        _userIdError = "Error checking User ID";
      });
    } finally {
      setState(() {
        _isCheckingUserId = false;
      });
    }
  }

  bool get _canSubmit {
    return _userIdController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty &&
        _nameController.text.isNotEmpty &&
        _isUserIdAvailable &&
        !_isLoading &&
        !_isCheckingUserId;
  }

  bool get _isDesktop {
    return MediaQuery.of(context).size.width >= 800;
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId != null) {
      await _fetchHallDetails(shopId);
      await _fetchAdmins();
    }
  }

  Future<void> _fetchAdmins() async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/admins/$shopId");
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _admins = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      _showMessage("Error fetching admins: $e");
    } finally {
      setState(() {
        _isLoadingAdmins = false;
      });
    }
  }

  Future<void> _createAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) {
      _showMessage("❌ shop ID not found in session");
      setState(() => _isLoading = false);
      return;
    }

    try {
      final url = Uri.parse("$baseUrl/users/$shopId/admin");
      final body = jsonEncode({
        "user_id": _userIdController.text.trim(),
        "password": _passwordController.text.trim(),
        "designation": _designation,
        "name": _nameController.text.trim(),
        "phone": _phoneController.text.trim(),
        "email": _emailController.text.trim(),
        "is_active": true
      });

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _showMessage("✅ Admin created successfully");
        _formKey.currentState!.reset();
        _userIdController.clear();
        _passwordController.clear();
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        setState(() {
          _designation = "Staff";
          _showForm = false;
        });
        await _fetchAdmins();

      } else {
        _showMessage("❌ Failed: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error creating admin: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAdmin(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final shopId = prefs.getInt("shopId");
    if (shopId == null) return;

    try {
      final url = Uri.parse("$baseUrl/admins/$shopId/admin/$userId");
      final response = await http.delete(url);

      if (response.statusCode == 200) {
        setState(() {
          _admins.removeWhere((admin) => admin["user_id"] == userId);
        });
        _showMessage("✅ Admin $userId deleted successfully");
       
      } else {
        _showMessage("❌ Failed to delete admin: ${response.body}");
      }
    } catch (e) {
      _showMessage("❌ Error deleting admin: $e");
    }
  }

  void _showDeleteDialog(String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: royal,
            width: 1.5,
          ),
        ),
        title: Text("Delete Admin", style: TextStyle(color: royal)),
        content: Text("Do you want to delete admin with User ID $userId?",
            style: TextStyle(color: royal)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: royal)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: royal),
            onPressed: () {
              Navigator.pop(context);
              _deleteAdmin(userId);
            },
            child: Text("Confirm", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminForm() {

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _isDesktop ? 800 : double.infinity,
        ),
        child: Card(
            elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: royal,
            width: 1,
          ),
        ),
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 12),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _isDesktop
                  ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        labeledTanRow(
                          label: "USER ID",
                          controller: _userIdController,
                          inputType: TextInputType.number,
                          hintText: "Enter User ID",
                          focusNode: _userIdFocus,
                          nextFocusNode: _passwordFocus,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          onChanged: (value) {
                            if (value.length >= 3) {
                              _checkUserIdUnique(value);
                            } else {
                              setState(() {
                                _isUserIdAvailable = false;
                                _userIdError = null;
                              });
                            }
                          },
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Enter user ID";
                            if (!_isUserIdAvailable) return _userIdError;
                            return null;
                          },
                        ),
                        labeledTanRow(
                          label: "PASSWORD",
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          showPasswordToggle: true,
                          hintText: "Enter Password",
                          focusNode: _passwordFocus,
                          nextFocusNode: _nameFocus,
                          validator: (v) =>
                          v == null || v.isEmpty ? "Enter password" : null,
                        ),
                        labeledTanRow(
                          label: "DESIGNATION",
                          dropdownItems: const [
                            DropdownMenuItem(
                                value: "Staff", child: Text("Staff")),
                            DropdownMenuItem(
                                value: "Owner", child: Text("Owner")),
                          ],
                          dropdownValue: _designation,
                          onDropdownChanged: (val) =>
                              setState(() => _designation = val ?? "Staff"),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 50),

                  Expanded(
                    child: Column(
                      children: [
                        labeledTanRow(
                          label: "NAME",
                          controller: _nameController,
                          hintText: "Enter Name",
                          focusNode: _nameFocus,
                          nextFocusNode: _phoneFocus,
                        ),
                        labeledTanRow(
                          label: "PHONE",
                          controller: _phoneController,
                          inputType: TextInputType.phone,
                          hintText: "(Optional) Enter Phone Number",
                          maxLength: 10,
                          focusNode: _phoneFocus,
                          nextFocusNode: _emailFocus,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (v) {
                            if (v != null && v.isNotEmpty) {
                              if (!RegExp(r'^\d+$').hasMatch(v)) {
                                return "Digits only";
                              }
                              if (v.length != 10) {
                                return "10 digits required";
                              }
                            }
                            return null;
                          },
                        ),
                        labeledTanRow(
                          label: "EMAIL",
                          controller: _emailController,
                          inputType: TextInputType.emailAddress,
                          focusNode: _emailFocus,
                          hintText: "(Optional) Enter Email Address",
                          validator: (v) {
                            if (v != null && v.isNotEmpty) {
                              if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$')
                                  .hasMatch(v)) {
                                return "Enter a valid email address";
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              )
                  : Column(
                children: [
                  labeledTanRow(
                    label: "USER ID",
                    controller: _userIdController,
                    inputType: TextInputType.number,
                    hintText: "Enter User ID",
                    maxLength: 10,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ],
                    onChanged: (value) {
                      if (value.length >= 3) {
                        _checkUserIdUnique(value);
                      } else {
                        setState(() {
                          _isUserIdAvailable = false;
                          _userIdError = null;
                        });
                      }
                    },
                    validator: (v) {
                      if (v == null || v.isEmpty) return "Enter user ID";
                      if (!_isUserIdAvailable) return _userIdError;
                      return null;
                    },
                  ),
                  labeledTanRow(
                    label: "PASSWORD",
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    showPasswordToggle: true,
                    hintText: "Enter Password",
                  ),
                  labeledTanRow(
                    label: "DESIGNATION",
                    dropdownItems: const [
                      DropdownMenuItem(value: "Staff", child: Text("Staff")),
                      DropdownMenuItem(value: "Owner", child: Text("Owner")),
                    ],
                    dropdownValue: _designation,
                    onDropdownChanged: (val) =>
                        setState(() => _designation = val ?? "Staff"),
                  ),
                  labeledTanRow(
                    label: "NAME",
                    controller: _nameController,
                    hintText: "Enter Name",
                  ),
                  labeledTanRow(
                    label: "PHONE",
                    controller: _phoneController,
                    inputType: TextInputType.phone,
                    hintText: "Enter Phone number",
                  ),
                  labeledTanRow(
                    label: "EMAIL",
                    controller: _emailController,
                    inputType: TextInputType.emailAddress,
                    hintText: "Enter email",
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // 🔘 CENTERED BUTTONS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 48,
                    width: 180,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canSubmit ? royal : Colors.grey,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _canSubmit ? _createAdmin : null,
                      child: _isLoading
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                          : const Text(
                        "Create Admin",
                        style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    height: 48,
                    width: 90,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: royal,
                        side: BorderSide(color: royal),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => setState(() => _showForm = false),
                      child: const Text("Close"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

      ),
        ),
      ),
    );
  }

  Widget _buildHallCard(Map<String, dynamic> hall) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
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
              color: Colors.white,
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
                hall['name']?.toString().toUpperCase() ?? "SHOP NAME",
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

  Widget _buildAdminCard(Map<String, dynamic> admin) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: royal,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.person, color: royal, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "User ID: ${admin["user_id"] ?? "N/A"}",
                    style: TextStyle(color: royal, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Name: ${admin["name"]?.isNotEmpty == true ? admin["name"] : "-"}",
                    style: TextStyle(color: royal),
                    softWrap: true,
                  ),
                  Text(
                    "Phone: ${admin["phone"]?.isNotEmpty == true ? admin["phone"] : "-"}",
                    style: TextStyle(color: royal),
                    softWrap: true,
                  ),
                  Text(
                    "Email: ${admin["email"]?.isNotEmpty == true ? admin["email"] : "-"}",
                    style: TextStyle(color: royal),
                    softWrap: true,
                  ),
                  Text(
                    "Designation: ${admin["designation"] ?? "-"}",
                    style: TextStyle(color: royal),
                    softWrap: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _showDeleteDialog(admin["user_id"]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminsResponsive(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // breakpoint
    final isWide = screenWidth >= 700;

    // card width
    final cardWidth = isWide
        ? (screenWidth - 16 * 2 - 12) / 2 // 2 per row
        : screenWidth; // 1 per row

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: _admins.map((admin) {
        return SizedBox(
          width: isWide ? cardWidth : double.infinity,
          child: _buildAdminCard(admin),
        );
      }).toList(),
    );
  }

  Future<void> _fetchHallDetails(int shopId) async {
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

  Widget labeledTanRow({
    required String label,
    TextEditingController? controller,
    String? hintText,
    String? Function(String?)? validator,
    TextInputType inputType = TextInputType.text,
    bool obscureText = false,
    bool showPasswordToggle = false,
    void Function(String)? onChanged,
    List<DropdownMenuItem<String>>? dropdownItems,
    String? dropdownValue,
    void Function(String?)? onDropdownChanged,
    int? maxLength,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    TextInputAction textInputAction = TextInputAction.next,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: royal, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 300 : double.infinity,
                ),
                child: dropdownItems != null
                    ? DropdownButtonFormField<String>(
                  initialValue: dropdownValue,
                  onChanged: onDropdownChanged,
                  items: dropdownItems,
                  style: TextStyle(color: royal),
                  dropdownColor: Colors.white,
                  decoration: _inputDecoration(hintText,isDropdown: true,),
                )
                    : TextFormField(
                  controller: controller,
                  validator: validator,
                  keyboardType: inputType,
                  obscureText: obscureText,
                  onChanged: onChanged,
                  cursorColor: royal,
                  maxLength: maxLength,
                  inputFormatters: inputFormatters,
                  style: TextStyle(color: royal),
                  focusNode: focusNode,
                  textInputAction: textInputAction,
                  onFieldSubmitted: (_) {
                    if (nextFocusNode != null) {
                      FocusScope.of(context).requestFocus(nextFocusNode);
                    } else {
                      FocusScope.of(context).unfocus();
                    }
                  },
                  decoration: _inputDecoration(
                    hintText,
                    controller: controller,
                    showPasswordToggle: showPasswordToggle,
                    obscureText: obscureText,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(
      String? hintText, {
        TextEditingController? controller,
        bool showPasswordToggle = false,
        bool obscureText = false,
        bool isDropdown = false, // 👈 ADD THIS
      }) {
    return InputDecoration(
      counterText: "",
      hintText: hintText,
      hintStyle: TextStyle(color: royal.withValues(alpha: 0.6)),
      filled: true,

      // ✅ FORCE WHITE BACKGROUND FOR DROPDOWN
      fillColor: isDropdown ? Colors.white : royalLight.withValues(alpha: 0.05),

      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal),
        borderRadius: BorderRadius.circular(12),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: royal, width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      suffixIcon: controller == _userIdController
          ? (_isCheckingUserId
          ? const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: royal,
          ),
        ),
      )
          : _userIdController.text.isEmpty
          ? null
          : Icon(
        _isUserIdAvailable
            ? Icons.check_circle
            : Icons.cancel,
        color: _isUserIdAvailable
            ? Colors.green
            : Colors.red,
      ))
          : showPasswordToggle
          ? IconButton(
        icon: Icon(
          obscureText
              ? Icons.visibility_off
              : Icons.visibility,
          color: royal,
        ),
        onPressed: () {
          setState(() {
            _obscurePassword = !_obscurePassword;
          });
        },
      )
          : null,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: royal,
        title: const Text("Admins", style: TextStyle(color: Colors.white)),
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
      body: _isLoadingAdmins
          ? Center(child: CircularProgressIndicator(color: royal))
          : _admins.isEmpty && !_showForm
          ? Center(

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
            Text(
              "No admins found.",
              style: TextStyle(
                color: royal,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: royal,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                setState(() => _showForm = true);
              },
              child: const Text("Create Admin"),
            ),
          ],
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            if (shopDetails != null) _buildHallCard(shopDetails!),
            const SizedBox(height: 16),
            if (!_showForm)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: royal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  setState(() => _showForm = true);
                },
                icon: const Icon(Icons.add),
                label: const Text(
                  "Create Admin",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            if (_showForm)
              _buildAdminForm(),
              // Center(
              //   child: Container(
              //     constraints: const BoxConstraints(
              //       maxWidth: 500, // 👈 always max 600, mobile will shrink
              //     ),
              //     width: double.infinity,
              //     child: _buildAdminForm(),
              //   ),
              // ),
            const SizedBox(height: 16),
            _buildAdminsResponsive(context),
          ],
        ),
      ),
    );
  }
}
