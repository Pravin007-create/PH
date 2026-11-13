import 'dart:convert';

import 'package:pg_hostel_management/features/room_management/models/room.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';

final roomProvider = StateNotifierProvider<RoomNotifier, List<Room>>((ref) {
  final storage = SecureStorageService();
  return RoomNotifier(storage);
});

class RoomNotifier extends StateNotifier<List<Room>> {
  final SecureStorageService _storage;

  RoomNotifier(this._storage) : super(const []);

  void addRoom(Room room) {
    state = [...state, room];
    _saveRooms();
  }

  void updateRoom(Room room) {
    final index = state.indexWhere((r) => r.roomNumber == room.roomNumber);
    if (index >= 0) {
      state = [...state]..[index] = room;
      _saveRooms();
    }
  }

  void deleteRoom(String roomNumber) {
    state = state.where((r) => r.roomNumber != roomNumber).toList();
    _saveRooms();
  }

  void loadRooms() {
    // Load from storage - in a real app, this would load from DB
    // For now, we'll just initialize with empty list
  }

  void _saveRooms() {
    // In a full implementation, we'd save to Drift/secure storage
    // For now, we just persist the room list
    final roomData = state.map((room) => room.toMap()).toList();
    _storage.write(key: 'saved_rooms', value: jsonEncode(roomData));
  }

  void _loadRoomsFromStorage() {
    final saved = _storage.read(key: 'saved_rooms');
    // Parse and load rooms
  }
}