import 'dart:convert';

import 'package:pg_hostel_management/features/bed_management/models/bed.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';

final bedProvider = StateNotifierProvider<BedNotifier, List<Bed>>((ref) {
  final storage = SecureStorageService();
  return BedNotifier(storage);
});

class BedNotifier extends StateNotifier<List<Bed>> {
  final SecureStorageService _storage;

  BedNotifier(this._storage) : super(const []);

  void addBed(Bed bed) {
    state = [...state, bed];
    _saveBeds();
  }

  void updateBed(Bed bed) {
    final index = state.indexWhere((b) => b.bedNumber == bed.bedNumber);
    if (index >= 0) {
      state = [...state]..[index] = bed;
      _saveBeds();
    }
  }

  void setBedStatus(String bedNumber, BedStatus status) {
    final index = state.indexWhere((b) => b.bedNumber == bedNumber);
    if (index >= 0) {
      final updatedBed = state[index].copyWith(status: status);
      state = [...state]..[index] = updatedBed;
      _saveBeds();
    }
  }

  void removeBed(String bedNumber) {
    state = state.where((b) => b.bedNumber != bedNumber).toList();
    _saveBeds();
  }

  List<Bed> getAvailableBeds() {
    return state.where((bed) => bed.status == BedStatus.available).toList();
  }

  List<Bed> getOccupiedBeds() {
    return state.where((bed) => bed.status == BedStatus.occupied).toList();
  }

  void _saveBeds() {
    final bedData = state.map((bed) => bed.toMap()).toList();
    _storage.write(key: 'saved_beds', value: jsonEncode(bedData));
  }
}