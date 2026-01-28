import 'package:flutter/material.dart';
import 'bulk_upload_exist.dart';
import 'bulk_existing_batch.dart';

class BulkUploadExistTabsPage extends StatelessWidget {
  const BulkUploadExistTabsPage({super.key});

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
                BulkUploadMedicineExistPage(),
                BulkUploadExistBatchPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
