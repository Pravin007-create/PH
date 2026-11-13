import 'package:pg_hostel_management/features/electricity_bills/models/electricity_bill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/securestorage/securestorage_service.dart';

final electricityBillProvider = StateNotifierProvider<ElectricityBillNotifier, List<ElectricityBill>>((ref) {
  final storage = SecureStorageService();
  return ElectricityBillNotifier(storage);
});

class ElectricityBillNotifier extends StateNotifier<List<ElectricityBill>> {
  final SecureStorageService _storage;

  ElectricityBillNotifier(this._storage) : super(const []);

  void addBill(ElectricityBill bill) {
    state = [...state, bill];
    _saveBills();
  }

  void updateBill(ElectricityBill bill) {
    final index = state.indexWhere((b) => b.tenantName == bill.tenantName && b.roomNumber == bill.roomNumber && b.bedNumber == bill.bedNumber && b.month == bill.month);
    if (index >= 0) {
      state = [...state..index = bill];
      _saveBills();
    }
  }

  void removeBill(String tenantName, String roomNumber, String bedNumber, String month) {
    state = state.where((b) => !(b.tenantName == tenantName && b.roomNumber == roomNumber && b.bedNumber == bedNumber && b.month == month)).toList();
    _saveBills();
  }

  List<ElectricityBill> getBillsByTenant(String tenantName) {
    return state.where((b) => b.tenantName == tenantName).toList();
  }

  List<ElectricityBill> getBillsByMonth(String month) {
    return state.where((b) => b.month == month).toList();
  }

  double getTotalBillsForMonth(String month) {
    return state.where((b) => b.month == month).fold(0.0, (sum, b) => sum + b.amount);
  }

  void _saveBills() {
    final billData = state.map((bill) => bill.toMap()).toList();
    _storage.write(key: 'saved_bills', value: billData.toString());
  }
}