import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PG Hostel Manager'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Clear activation and return to activation screen
              // In a real app, would clear secure storage
              context.go('/activation');
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Navigation drawer
          _buildNavigationDrawer(context),
          const VerticalDivider(width: 1, thickness: 1),
          // Main content
          Expanded(
            child: _buildMainContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationDrawer(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF1976D2),
            ),
            child: Text(
              'Menu',
              style: TextStyle(color: Colors.white, fontSize: 20),
            ),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.home,
            label: 'Dashboard',
            onTap: () => context.go('/dashboard'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.apartment,
            label: 'PG Profile',
            onTap: () => context.go('/pg-profile'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.room,
            label: 'Room Management',
            onTap: () => context.go('/room-management'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.bed,
            label: 'Bed Management',
            onTap: () => context.go('/bed-management'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.person,
            label: 'Tenant Management',
            onTap: () => context.go('/tenant-management'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.money,
            label: 'Rent Payments',
            onTap: () => context.go('/rent-payment'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.electric_bolt,
            label: 'Electricity Bills',
            onTap: () => context.go('/electricity-bills'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.receipt,
            label: 'Expenses',
            onTap: () => context.go('/expenses'),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.backup,
            label: 'Backup/Restore',
            onTap: () => context.go('/backup-restore'),
          ),
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: Text(
              'PG Hostel Manager v1.0.0',
              style: TextStyle(color: Colors.black87, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final isSelected = false; // Simplified for now
    return ListTile(
      leading: Icon(icon, color: Colors.black87),
      title: Text(label, style: const TextStyle(color: Colors.black87)),
      selected: isSelected,
      onTap: onTap,
    );
  }

  Widget _buildMainContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to PG Hostel Manager',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          _buildFeatureCard(
            context,
            icon: Icons.bar_chart,
            title: 'Dashboard',
            subtitle: 'View reports and statistics',
            onTap: () => context.go('/dashboard'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.apartment,
            title: 'PG Profile',
            subtitle: 'Manage PG details and preferences',
            onTap: () => context.go('/pg-profile'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.room,
            title: 'Room Management',
            subtitle: 'Add, edit, and deactivate rooms',
            onTap: () => context.go('/room-management'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.bed,
            title: 'Bed Management',
            subtitle: 'Manage beds and their status',
            onTap: () => context.go('/bed-management'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.person,
            title: 'Tenant Management',
            subtitle: 'Add and manage tenants',
            onTap: () => context.go('/tenant-management'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.money,
            title: 'Rent Payments',
            subtitle: 'Track rent collections',
            onTap: () => context.go('/rent-payment'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.electric_bolt,
            title: 'Electricity Bills',
            subtitle: 'Track electricity charges',
            onTap: () => context.go('/electricity-bills'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.receipt,
            title: 'Expenses',
            subtitle: 'Record and track expenses',
            onTap: () => context.go('/expenses'),
          ),
          const SizedBox(height: 12),
          _buildFeatureCard(
            context,
            icon: Icons.backup,
            title: 'Backup/Restore',
            subtitle: 'Backup and restore data',
            onTap: () => context.go('/backup-restore'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1976D2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF1976D2), size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
