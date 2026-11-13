import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/theme/app_theme.dart';
import 'package:pg_hostel_management/features/tenant_management/models/tenant.dart';
import 'package:pg_hostel_management/features/tenant_management/providers/tenant_provider.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';
import 'package:pg_hostel_management/core/router/app_router.dart';

class TenantManagementScreen extends StatefulWidget {
  const TenantManagementScreen({super.key});

  @override
  State<TenantManagementScreen> createState() => _TenantManagementScreenState();
}

class _TenantManagementScreenState extends State<TenantManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _bedNumberController = TextEditingController();
  final _searchController = TextEditingController();

  late final TenantNotifier _notifier;
  late final SecureStorageService _storage;
  List<Tenant> _tenants = [];
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _notifier = context.read<TenantNotifier>();
    _loadTenants();
  }

  Future<void> _loadTenants() async {
    final saved = await _storage.read(key: 'saved_tenants');
    if (saved != null) {
      // Parse tenants from stored data
    }
    setState(() {
      _tenants = [];
    });
  }

  void _addTenant() {
    if (_formKey.currentState!.validate()) {
      final tenant = Tenant(
        name: _nameController.text,
        mobileNumber: _mobileController.text,
        email: _emailController.text,
        address: _addressController.text,
        roomNumber: _roomNumberController.text,
        bedNumber: _bedNumberController.text,
        moveInDate: DateTime.now().toIso8601String(),
        rentPaid: 0.0,
        depositPaid: 0.0,
        outstandingBalance: 0.0,
      );

      _notifier.addTenant(tenant);
      _nameController.clear();
      _mobileController.clear();
      _emailController.clear();
      _addressController.clear();
      _roomNumberController.clear();
      _bedNumberController.clear();
      
      _loadTenants(); // Refresh the list
    }
  }

  void _editTenant(Tenant tenant) {
    _nameController.text = tenant.name;
    _mobileController.text = tenant.mobileNumber;
    _emailController.text = tenant.email;
    _addressController.text = tenant.address;
    _roomNumberController.text = tenant.roomNumber;
    _bedNumberController.text = tenant.bedNumber;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Tenant'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Tenant Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      ValidationUtils.validateName(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) =>
                      ValidationUtils.validateMobile(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) =>
                      ValidationUtils.validateEmail(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      ValidationUtils.validateName(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _roomNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Room Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      ValidationUtils.validateRoomNumber(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bedNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Bed Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      ValidationUtils.validateRoomNumber(value),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedTenant = tenant.copyWith(
                name: _nameController.text,
                mobileNumber: _mobileController.text,
                email: _emailController.text,
                address: _addressController.text,
                roomNumber: _roomNumberController.text,
                bedNumber: _bedNumberController.text,
              );
              _notifier.updateTenant(updatedTenant);
              Navigator.of(context).pop();
              _loadTenants();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteTenant(String name, String roomNumber, String bedNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tenant'),
        content: const Text('Are you sure you want to delete this tenant?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notifier.removeTenant(name, roomNumber, bedNumber);
              Navigator.of(context).pop();
              _loadTenants();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tenant removed successfully'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tenant Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addTenant,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Tenants',
                border: OutlineInputBorder(),
                hintText: 'Enter tenant name to search',
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Tenants list
          Expanded(
            child: _tenants.isEmpty
                ? const Center(
                    child: Text(
                      'No tenants found. Add a tenant to get started.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _tenants.length,
                    itemBuilder: (context, index) {
                      final tenant = _tenants[index];
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text('${tenant.name}'),
                          subtitle: Text(
                            'Room: ${tenant.roomNumber} | Bed: ${tenant.bedNumber} | '
                            'Mobile: ${tenant.mobileNumber}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF1976D2)),
                                onPressed: () => _editTenant(tenant),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteTenant(tenant.name, tenant.roomNumber, tenant.bedNumber),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}