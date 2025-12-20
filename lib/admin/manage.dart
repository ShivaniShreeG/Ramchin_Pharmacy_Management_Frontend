import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'manage/owner_manage.dart';
import 'manage/other_manage.dart';

class AdminManagePage extends StatefulWidget {
  const AdminManagePage({super.key});

  @override
  State<AdminManagePage> createState() => _AdminManagePageState();
}

class _AdminManagePageState extends State<AdminManagePage> {
  String? designation;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDesignation();
  }

  Future<void> _loadDesignation() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDesignation = prefs.getString('designation') ?? '';

    setState(() {
      designation = savedDesignation.trim().toLowerCase();
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (designation == null || designation!.isEmpty) {
      return const SizedBox.shrink();
    }

    if (designation == 'owner') {
      return const OwnerPage();
    } else {
      return const OtherManagePage();
    }
  }
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(
          "Welcome Admin! This is the regular admin page.",
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
