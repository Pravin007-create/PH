import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/theme/app_theme.dart';
import 'package:pg_hostel_management/features/rent_payment/models/rent_payment.dart';
import 'package:pg_hostel_management/features/rent_payment/providers/rent_payment_provider.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';
import 'package:pg_hostel_management/core/router/app_router.dart';
import 'package:pg_hostel_management/core/constants/app_constants.dart';

class RentPaymentScreen extends StatefulWidget {
  const RentPaymentScreen({super.key});

  @override
  State<RentPaymentScreen> createState() => _RentPaymentScreenState();
}

class _RentPaymentScreenState extends State<RentPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tenantNameController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _bedNumberController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentDateController = TextEditingController();
  final _monthController = TextEditingController();
  final _searchController = TextEditingController();

  late final RentPaymentNotifier _notifier;
  late final SecureStorageService _storage;
  List<RentPayment> _payments = [];
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _notifier = context.read<RentPaymentNotifier>();
    _loadPayments();
    _initializeDateFields();
  }

  void _initializeDateFields() {
    final now = DateTime.now();
    _paymentDateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _monthController.text = AppConstants.paymentMonths[now.month - 1];
  }

  Future<void> _loadPayments() async {
    final saved = await _storage.read(key: 'saved_payments');
    if (saved != null) {
      // Parse payments from stored data
    }
    setState(() {
      _payments = [];
    });
  }

  void _addPayment() {
    if (_formKey.currentState!.validate()) {
      final payment = RentPayment(
        tenantName: _tenantNameController.text,
        roomNumber: _roomNumberController.text,
        bedNumber: _bedNumberController.text,
        amount: double.tryParse(_amountController.text) ?? 0.0,
        paymentDate: _paymentDateController.text,
        month: _monthController.text,
      );

      _notifier.addPayment(payment);
      _tenantNameController.clear();
      _roomNumberController.clear();
      _bedNumberController.clear();
      _amountController.clear();
      
      _loadPayments(); // Refresh the list
    }
  }

  void _editPayment(RentPayment payment) {
    _tenantNameController.text = payment.tenantName;
    _roomNumberController.text = payment.roomNumber;
    _bedNumberController.text = payment.bedNumber;
    _amountController.text = payment.amount.toString();
    _paymentDateController.text = payment.paymentDate;
    _monthController.text = payment.month;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Rent Payment'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  value: _tenantNameController.isNotEmpty ? _tenantNameController.text : null,
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
                  keyboardType: const TextInputType(editor: TextInputType.number),
                  validator: (value) =>
                      ValidationUtils.validateRentAmount(value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _paymentDateController,
                  decoration: const InputDecoration(
                    labelText: 'Payment Date',
                    border: OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    // Open date picker
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _monthController.isNotEmpty ? _monthController.text : AppConstants.paymentMonths.first,
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
              final updatedPayment = payment.copyWith(
                tenantName: _tenantNameController.text,
                roomNumber: _roomNumberController.text,
                bedNumber: _bedNumberController.text,
                amount: double.tryParse(_amountController.text) ?? payment.amount,
                paymentDate: _paymentDateController.text,
                month: _monthController.text,
              );
              _notifier.updatePayment(updatedPayment);
              Navigator.of(context).pop();
              _loadPayments();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deletePayment(String tenantName, String roomNumber, String bedNumber, String month) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment Record'),
        content: const Text('Are you sure you want to delete this payment record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notifier.removePayment(tenantName, roomNumber, bedNumber, month);
              Navigator.of(context).pop();
              _loadPayments();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payment record deleted successfully'),
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
        title: const Text('Rent Payments'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addPayment,
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
                  child: _buildPaymentSummary(
                    context,
                    'Total Collected',
                    _payments.fold(0.0, (sum, p) => sum + p.amount).toStringAsFixed(2),
                    Colors.green,
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
                labelText: 'Search Payments',
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
          // Payments list
          Expanded(
            child: _payments.isEmpty
                ? const Center(
                    child: Text(
                      'No payment records found. Add a payment to get started.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text('${payment.tenantName} - ${payment.month}'),
                          subtitle: Text(
                            'Amount: \$${payment.amount.toStringAsFixed(2)} | Date: ${payment.paymentDate}',
                          ),
                          trailing: Text(
                            '\$${payment.amount.toStringAsFixed(2)}',
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

  Widget _buildPaymentSummary(BuildContext context, String label, String value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children [
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