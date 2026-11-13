import 'package:pg_hostel_management/features/rent_payment/models/rent_payment.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/securestorage/securestorage_service.dart';

final rentPaymentProvider = StateNotifierProvider<RentPaymentNotifier, List<RentPayment>>((ref) {
  final storage = SecureStorageService();
  return RentPaymentNotifier(storage);
});

class RentPaymentNotifier extends StateNotifier<List<RentPayment>> {
  final SecureStorageService _storage;

  RentPaymentNotifier(this._storage) : super(const []);

  void addPayment(RentPayment payment) {
    state = [...state, payment];
    _savePayments();
  }

  void updatePayment(RentPayment payment) {
    final index = state.indexWhere((p) => p.tenantName == payment.tenantName && p.roomNumber == payment.roomNumber && p.bedNumber == payment.bedNumber && p.month == payment.month);
    if (index >= 0) {
      state = [...state..index = payment];
      _savePayments();
    }
  }

  void removePayment(String tenantName, String roomNumber, String bedNumber, String month) {
    state = state.where((p) => !(p.tenantName == tenantName && p.roomNumber == roomNumber && p.bedNumber == bedNumber && p.month == month)).toList();
    _savePayments();
  }

  List<RentPayment> getPaymentsByTenant(String tenantName) {
    return state.where((p) => p.tenantName == tenantName).toList();
  }

  List<RentPayment> getPaymentsByMonth(String month) {
    return state.where((p) => p.month == month).toList();
  }

  double getTotalCollectedForMonth(String month) {
    return state.where((p) => p.month == month).fold(0.0, (sum, p) => sum + p.amount);
  }

  void _savePayments() {
    final paymentData = state.map((payment) => payment.toMap()).toList();
    _storage.write(key: 'saved_payments', value: paymentData.toString());
  }
}