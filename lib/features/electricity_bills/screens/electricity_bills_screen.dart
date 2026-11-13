import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/utils/validation_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/features/electricity_bills/models/electricity_bill.dart';
import 'package:pg_hostel_management/features/electricity_bills/providers/electricity_bill_provider.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';
import 'package:pg_hostel_management/core/constants/app_constants.dart';

class ElectricityBillsScreen extends StatefulWidget {
  const ElectricityBillsScreen({super.key});

  @override
  State<ElectricityBillsScreen> createState() => _ElectricityBillsScreenState();
}

class _ElectricityBillsScreenState extends State<ElectricityBillsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantNameController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _bedNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _billDateController = TextEditingController();
  final _monthController = TextEditingController();
  final _searchController = TextEditingController();

  late final ElectricityBillNotifier _notifier;
  late final SecureStorageService _storage;
  List<ElectricityBill> _bills = [];
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _notifier = ProviderScope.containerOf(context, listen: false).read(electricityBillProvider.notifier);
    _loadBills();
    _initializeDateFields();
  }

  void _initializeDateFields() {
    final now = DateTime.now();
    _billDateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _monthController.text = AppConstants.paymentMonths[now.month - 1];
  }

  Future<void> _loadBills() async {
    final saved = await _storage.read(key: 'saved_bills');
    if (saved != null) {
      // Parse bills from stored data
    }
    setState(() {
      _bills = [];
    });
  }

  void _addBill() {
    if (_formKey.currentState!.validate()) {
      final bill = ElectricityBill(
        tenantName: _tenantNameController.text,
        roomNumber: _roomNumberController.text,
        bedNumber: _bedNumberController.text,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        billDate: _billDateController.text,
        month: _monthController.text,
      );

      _notifier.addBill(bill);
      _tenantNameController.clear();
      _roomNumberController.clear();
      _bedNumberController.clear();
      _amountController.clear();
      
      _loadBills(); // Refresh the list
    }
  }

  void _editBill(ElectricityBill bill) {
    _tenantNameController.text = bill.tenantName;
    _roomNumberController.text = bill.roomNumber;
    _bedNumberController.text = bill.bedNumber;
    _amountController.text = bill.amount.toString();
    _billDateController.text = bill.billDate;
    _monthController.text = bill.month;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Electricity Bill'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tenantNameController.text.isNotEmpty ? _tenantNameController.text : null,
                  decoration: const InputDecoration(
                    labelText: 'Tenant Name',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'John Doe', child: Text('John Doe')),
                    DropdownMenuItem(value: 'Jane Smith', child: Text('Jane Smith')),
                  ],
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _tenantNameController.text = newValue;
                    }
                  },
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
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) => ValidationUtils.validateExpenseAmount(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _billDateController,
                  decoration: const InputDecoration(
                    labelText: 'Bill Date',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    // Open date picker
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _monthController.text.isNotEmpty ? _monthController.text : AppConstants.paymentMonths.first,
                  decoration: const InputDecoration(
                    labelText: 'Month',
                    border: OutlineInputBorder(),
                  ),
                  items: AppConstants.paymentMonths.map((month) => DropdownMenuItem(
                    value: month,
                    child: Text(month),
                  )).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      _monthController.text = newValue;
                    }
                  },
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
              final updatedBill = bill.copyWith(
                tenantName: _tenantNameController.text,
                roomNumber: _roomNumberController.text,
                bedNumber: _bedNumberController.text,
                amount: double.tryParse(_amountController.text) ?? bill.amount,
                billDate: _billDateController.text,
                month: _monthController.text,
              );
              _notifier.updateBill(updatedBill);
              Navigator.of(context).pop();
              _loadBills();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteBill(String tenantName, String roomNumber, String bedNumber, String month) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Electricity Bill'),
        content: const Text('Are you sure you want to delete this bill record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notifier.removeBill(tenantName, roomNumber, bedNumber, month);
              Navigator.of(context).pop();
              _loadBills();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Electricity bill record deleted successfully'),
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
        title: const Text('Electricity Bills'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addBill,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary section
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: _buildBillSummary(
                    context,
                    'Total Bills',
                    _bills.length.toString(),
                    Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextFormField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'Search Bills',
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
          // Bills list
          Expanded(
            child: _bills.isEmpty
                ? const Center(
                    child: Text(
                      'No electricity bill records found. Add a bill to get started.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _bills.length,
                    itemBuilder: (context, index) {
                      final bill = _bills[index];
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text('${bill.tenantName} - ${bill.month}'),
                          subtitle: Text(
                            'Amount: \$${bill.amount.toStringAsFixed(2)} | Date: ${bill.billDate}',
                          ),
                          trailing: Text(
                            '\$${bill.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1976D2)),
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

  Widget _buildBillSummary(BuildContext context, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
