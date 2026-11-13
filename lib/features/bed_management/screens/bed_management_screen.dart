import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/utils/validation_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/features/bed_management/models/bed.dart';
import 'package:pg_hostel_management/features/bed_management/providers/bed_provider.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';

class BedManagementScreen extends StatefulWidget {
  const BedManagementScreen({super.key});

  @override
  State<BedManagementScreen> createState() => _BedManagementScreenState();
}

class _BedManagementScreenState extends State<BedManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bedNumberController = TextEditingController();
  final _roomNumberController = TextEditingController();
  final _searchController = TextEditingController();

  late final BedNotifier _notifier;
  late final SecureStorageService _storage;
  List<Bed> _beds = [];
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _notifier = ProviderScope.containerOf(context, listen: false).read(bedProvider.notifier);
    _loadBeds();
  }

  Future<void> _loadBeds() async {
    final saved = await _storage.read(key: 'saved_beds');
    if (saved != null) {
      // Parse beds from stored data
    }
    setState(() {
      _beds = [];
    });
  }

  void _addBed() {
    if (_formKey.currentState!.validate()) {
      final bedStatus = BedStatus.available;
      final bed = Bed(
        bedNumber: _bedNumberController.text,
        roomNumber: _roomNumberController.text,
        status: bedStatus,
      );

      _notifier.addBed(bed);
      _bedNumberController.clear();
      _roomNumberController.clear();
      
      _loadBeds(); // Refresh the list
    }
  }

  void _setBedStatus(String bedNumber, BedStatus status) {
    _notifier.setBedStatus(bedNumber, status);
    _loadBeds(); // Refresh the list
  }

  void _editBed(Bed bed) {
    _bedNumberController.text = bed.bedNumber;
    _roomNumberController.text = bed.roomNumber;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Bed'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
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
                  controller: _roomNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Room Number',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) =>
                      ValidationUtils.validateRoomNumber(value),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<BedStatus>(
                  initialValue: bed.status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: BedStatus.values.map((status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.value),
                  )).toList(),
                  onChanged: (BedStatus? newValue) {
                    if (newValue != null) {
                      _setBedStatus(bed.bedNumber, newValue);
                      Navigator.of(context).pop();
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
              final updatedBed = bed.copyWith(
                bedNumber: _bedNumberController.text.isNotEmpty
                    ? _bedNumberController.text
                    : bed.bedNumber,
                roomNumber: _roomNumberController.text.isNotEmpty
                    ? _roomNumberController.text
                    : bed.roomNumber,
              );
              _notifier.updateBed(updatedBed);
              Navigator.of(context).pop();
              _loadBeds();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteBed(String bedNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Bed'),
        content: const Text('Are you sure you want to delete this bed?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notifier.removeBed(bedNumber);
              Navigator.of(context).pop();
              _loadBeds();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Bed deleted successfully'),
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
    final availableBeds = _beds.where((b) => b.status == BedStatus.available.name).length;
    final occupiedBeds = _beds.where((b) => b.status == BedStatus.occupied.name).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bed Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addBed,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary stats
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatCard(
                  context,
                  'Available',
                  availableBeds.toString(),
                  Icons.check_circle,
                  Colors.green,
                ),
                _buildStatCard(
                  context,
                  'Occupied',
                  occupiedBeds.toString(),
                  Icons.remove_circle,
                  Colors.red,
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
                labelText: 'Search Beds',
                border: OutlineInputBorder(),
                hintText: 'Enter bed number to search',
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Beds list
          Expanded(
            child: _beds.isEmpty
                ? const Center(
                    child: Text(
                      'No beds found. Add a bed to get started.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _beds.length,
                    itemBuilder: (context, index) {
                      final bed = _beds[index];
                      final isAvailable = bed.status == BedStatus.available.name;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        color: isAvailable ? Colors.green[50] : Colors.red[50],
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isAvailable ? Colors.green : Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isAvailable ? Icons.check : Icons.close,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          title: Text('Bed ${bed.bedNumber}'),
                          subtitle: Text(
                            'Room: ${bed.roomNumber} | Status: ${bed.status}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF1976D2)),
                                onPressed: () => _editBed(bed),
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

  Widget _buildStatCard(BuildContext context, String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
