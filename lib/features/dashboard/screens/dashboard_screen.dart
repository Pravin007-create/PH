import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/theme/app_theme.dart';
import 'package:pg_hostel_management/features/dashboard/providers/dashboard_provider.dart';
import 'package:pg_hostel_management/core/router/app_router.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState;
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardNotifier _notifier;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _notifier = context.read<DashboardNotifier>();
    _loadData();
  }

  Future<void> _loadData() async {
    await _notifier.loadData();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // KPI Cards
                  const Text(
                    'Key Metrics',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildKPICard(
                    context,
                    'Total Rooms',
                    _notifier.state['totalRooms'] ?? 0,
                    Icons.room,
                    const Color(0xFF1976D2),
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Total Beds',
                    _notifier.state['totalBeds'] ?? 0,
                    Icons.bed,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Available Beds',
                    _notifier.state['availableBeds'] ?? 0,
                    Icons.check_circle,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Occupied Beds',
                    _notifier.state['occupiedBeds'] ?? 0,
                    Icons.remove_circle,
                    Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Total Tenants',
                    _notifier.state['totalTenants'] ?? 0,
                    Icons.person,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Monthly Revenue',
                    _notifier.state['monthlyRevenue'] ?? 0.0,
                    Icons.monetization_on,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Outstanding Balance',
                    _notifier.state['outstandingBalance'] ?? 0.0,
                    Icons.warning,
                    Colors.red,
                  ),
                  const SizedBox(height: 24),

                  // Recent Payments
                  const Text(
                    'Recent Rent Payments',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRecentList(
                    context,
                    _notifier.state['recentPayments'] ?? [],
                    Icons.money,
                    Colors.green,
                    'payment',
                  ),

                  const SizedBox(height: 24),

                  // Recent Expenses
                  const Text(
                    'Recent Expenses',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildRecentList(
                    context,
                    _notifier.state['recentExpenses'] ?? [],
                    Icons.receipt,
                    Colors.blue,
                    'expense',
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildKPICard(
    BuildContext context,
    String label,
    dynamic value,
    IconData icon,
    Color color,
  ) {
    final String valueText = value is double
        ? '\$${value.toStringAsFixed(2)}'
        : value.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    valueText,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentList(
    BuildContext context,
    List items,
    IconData icon,
    Color color,
    String type,
  ) {
    if (items.isEmpty) {
      return const Text(
        'No records found.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length > 5 ? 5 : items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final title = type == 'payment'
            ? '${item['tenant_name'] ?? 'N/A'} - ${item['month'] ?? 'N/A'}'
            : '${item['description'] ?? 'N/A'}';
        final subtitle = type == 'payment'
            ? 'Date: ${item['payment_date'] ?? 'N/A'}'
            : 'Date: ${item['date'] ?? 'N/A'}';

        return ListTile(
          leading: Icon(icon, color: color),
          title: Text(title),
          subtitle: Text(subtitle),
        );
      },
    );
  }
}