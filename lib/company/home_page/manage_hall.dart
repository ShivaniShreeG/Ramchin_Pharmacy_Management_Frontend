import 'package:flutter/material.dart';
import 'create_admin.dart';
import 'block_page.dart';
import 'edit_hall.dart';
import 'payment_history.dart';
import 'add_message.dart';
import 'view_tickets.dart';

const Color royalblue = Color(0xFF854929);
const Color royal = Color(0xFF875C3F);
const Color royalLight = Color(0xFF916542);

class ManagePage extends StatelessWidget {
  final dynamic selectedHall;

  const ManagePage({super.key, required this.selectedHall});

  @override
  Widget build(BuildContext context) {
    if (selectedHall == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            "⚠ No shop selected",
            style: TextStyle(
              color: royal,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: royalLight.withValues(alpha: 0.3),
      appBar: AppBar(
        title: Text(
          "Manage ${selectedHall['name'] ?? 'Shop'}",
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: royal,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(20),
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),

            _buildMainCard(
              context,
              title: "Create",
              icon: Icons.person_add,
              label: "Admin",
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CreateAdminPage(hall: selectedHall),
                  ),
                );
              },
            ),

            const SizedBox(height: 25),

            _buildActionCard(context),
            const SizedBox(height: 25),

            _buildViewCard(context),

          ],
        ),
      ),
    );
  }

  Widget _buildMainCard(
      BuildContext context, {
        required String title,
        required IconData icon,
        required String label,
        required VoidCallback onTap,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;

    return SizedBox(
      height: 260,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: royal,width: 1.5)
        ),
        elevation: 2,
        shadowColor: royal,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: royal,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 0),
                  const Icon(Icons.arrow_drop_down, color: royal, size: 28),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  width: screenWidth * 0.20,
                  height: screenWidth * 0.20,
                  decoration: BoxDecoration(
                    color: royalLight.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: royal,
                      width: 1.5 ,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: royal.withValues(alpha:0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(icon, size: 44, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: const TextStyle(
                  color: royal,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context) {
    final actions = [
      {
        'icon': Icons.block,
        'label': 'Block',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => BlockHallPage(hall: selectedHall)),
          );
        },
      },
      {
        'icon': Icons.edit,
        'label': 'Edit',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EditHallPage(hall: selectedHall)),
          );
        },
      },
      {
        'icon': Icons.message,
        'label': 'Message',
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => HallMessagesPage(hall: selectedHall)),
          );
        },
      },
    ];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: royal,width: 1.5)
      ),
      elevation: 2,
      shadowColor: royal,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  "Actions",
                  style: TextStyle(
                    color: royal,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.arrow_drop_down, color: royal, size: 28),
              ],
            ),
            const SizedBox(height: 20),

            Wrap(
              spacing: 20,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: actions
                  .map(
                    (action) => _buildActionButton(
                  context,
                  icon: action['icon'] as IconData,
                  label: action['label'] as String,
                  onTap: action['onTap'] as VoidCallback,
                  color: royalLight.withValues(alpha: 0.9),
                ),
              )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewCard(BuildContext context) {

    return SizedBox(
      height: 260,
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: royal,width: 1.5)
        ),
        elevation: 2,
        shadowColor: royal,
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    "View",
                    style: TextStyle(
                      color: royal,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 0),
                  Icon(Icons.arrow_drop_down, color: royal, size: 28),
                ],
              ),
              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    context,
                    icon: Icons.history,
                    label: "Payment history",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TransactionHistoryPage(hall: selectedHall),
                        ),
                      );
                    },
                    color: royal,
                  ),
                  const SizedBox(width: 20),
                  _buildActionButton(
                    context,
                    icon: Icons.confirmation_num,
                    label: "Tickets",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ViewTicketsPage(hall: selectedHall),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onTap,
        Color? color,
      }) {
    final screenWidth = MediaQuery.of(context).size.width;
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: screenWidth * 0.20,
            height: screenWidth * 0.20,
            decoration: BoxDecoration(
              color: royalLight.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(20),
                border:Border.all(color: royal,width: 1.5),
                boxShadow: [
                BoxShadow(
                  color: royal.withValues(alpha:0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(icon, size: 42, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: royal,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}
