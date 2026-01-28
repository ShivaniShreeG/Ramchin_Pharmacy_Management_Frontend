import 'package:flutter/material.dart';
import 'bulk_upload_batch.dart';
import 'bulk_upload_medicine.dart';

class BulkUploadNewTabsPage extends StatelessWidget {
  const BulkUploadNewTabsPage({super.key});

  static const Color royal = Color(0xFF875C3F);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          Material(
            color: royal,
            child: const TabBar(
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: "Medicine Wise"),
                Tab(text: "Batch Wise"),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                BulkUploadMedicinePage(),
                BulkUploadBatchPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
