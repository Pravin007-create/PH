import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/constants/app_constants.dart';
import 'package:pg_hostel_management/core/utils/validation_utils.dart';
import 'package:pg_hostel_management/features/room_management/providers/room_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/features/room_management/models/room.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';

class RoomManagementScreen extends StatefulWidget {
  const RoomManagementScreen({super.key});

  @override
  State<RoomManagementScreen> createState() => _RoomManagementScreenState();
}

class _RoomManagementScreenState extends State<RoomManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _roomNumberController = TextEditingController();
  final _floorController = TextEditingController();
  final _monthlyRentController = TextEditingController();
  final _searchController = TextEditingController();

  late final RoomNotifier _notifier;
  late final SecureStorageService _storage;
  List<Room> _rooms = [];
  String? _searchQuery;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _notifier = ProviderScope.containerOf(context, listen: false).read(roomProvider.notifier);
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    // In a full implementation, load from Drift database
    // For now, we'll try to load from secure storage
    final saved = await _storage.read(key: 'saved_rooms');
    if (saved != null) {
      // Parse rooms from stored data
    }
    // For now, keep the default empty list
    setState(() {
      _rooms = [];
    });
  }

  void _addRoom() {
    if (_formKey.currentState!.validate()) {
      final room = Room(
        roomNumber: _roomNumberController.text,
        floor: _floorController.text,
        isAC: false,
        sharingType: 'Single',
        totalCapacity: 1,
        numberOfBeds: 1,
        roomFacilities: '',
        monthlyRent: double.tryParse(_monthlyRentController.text) ?? 0.0,
        electricityBillingType: 'Monthly',
        roomStatus: AppConstants.roomStatusActive,
      );

      _notifier.addRoom(room);
      _roomNumberController.clear();
      _floorController.clear();
      _monthlyRentController.clear();
      
      _loadRooms(); // Refresh the list
    }
  }

  void _editRoom(Room room) {
    _roomNumberController.text = room.roomNumber;
    _floorController.text = room.floor;
    _monthlyRentController.text = room.monthlyRent.toString();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Room'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              children: [
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
                  controller: _floorController,
                  decoration: const InputDecoration(
                    labelText: 'Floor',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _monthlyRentController,
                  decoration: const InputDecoration(
                    labelText: 'Monthly Rent',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) =>
                      ValidationUtils.validateRentAmount(value),
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
              final updatedRoom = room.copyWith(
                roomNumber: _roomNumberController.text.isNotEmpty
                    ? _roomNumberController.text
                    : room.roomNumber,
                floor: _floorController.text.isNotEmpty
                    ? _floorController.text
                    : room.floor,
                monthlyRent: double.tryParse(_monthlyRentController.text) ?? room.monthlyRent,
              );
              _notifier.updateRoom(updatedRoom);
              Navigator.of(context).pop();
              _loadRooms();
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deleteRoom(String roomNumber) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Room'),
        content: const Text('Are you sure you want to delete this room?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _notifier.deleteRoom(roomNumber);
              Navigator.of(context).pop();
              _loadRooms();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Room deleted successfully'),
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
        title: const Text('Room Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addRoom,
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
                labelText: 'Search Rooms',
                border: OutlineInputBorder(),
                hintText: 'Enter room number to search',
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Rooms list
          Expanded(
            child: _rooms.isEmpty
                ? const Center(
                    child: Text(
                      'No rooms found. Add a room to get started.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: _rooms.length,
                    itemBuilder: (context, index) {
                      final room = _rooms[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          title: Text('Room ${room.roomNumber}'),
                          subtitle: Text(
                            'Floor: ${room.floor} | '
                            'AC: ${room.isAC ? 'Yes' : 'No'} | '
                            'Rent: \$${room.monthlyRent.toStringAsFixed(2)}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Color(0xFF1976D2)),
                                onPressed: () => _editRoom(room),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _deleteRoom(room.roomNumber),
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
