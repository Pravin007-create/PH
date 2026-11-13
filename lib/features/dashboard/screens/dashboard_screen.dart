import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/features/dashboard/providers/dashboard_provider.dart';
import 'package:pg_hostel_management/core/router.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dashboardProvider);
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
                    data['totalRooms'] ?? 0,
                    Icons.room,
                    const Color(0xFF1976D2),
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Total Beds',
                    data['totalBeds'] ?? 0,
                    Icons.bed,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Available Beds',
                    data['availableBeds'] ?? 0,
                    Icons.check_circle,
                    Colors.green,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Occupied Beds',
                    data['occupiedBeds'] ?? 0,
                    Icons.remove_circle,
                    Colors.red,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Total Tenants',
                    data['totalTenants'] ?? 0,
                    Icons.person,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Monthly Revenue',
                    data['monthlyRevenue'] ?? 0.0,
                    Icons.monetization_on,
                    Colors.orange,
                  ),
                  const SizedBox(height: 12),
                  _buildKPICard(
                    context,
                    'Outstanding Balance',
                    data['outstandingBalance'] ?? 0.0,
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
                    data['recentPayments'] ?? [],
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
                    data['recentExpenses'] ?? [],
                    Icons.receipt,
                    Colors.blue,
                    'expense',
                  ),
                ],
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
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
