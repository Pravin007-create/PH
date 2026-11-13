import 'package:pg_hostel_management/features/tenant_management/models/tenant.dart';
import 'package:riverpod_state_notifier/riverpod_state_notifier.dart';
import 'core/securestorage/securestorage_service.dart';

final tenantProvider = StateNotifierProvider<TenantNotifier, List<Tenant>>((ref) {
  final storage = SecureStorageService();
  return TenantNotifier(storage);
});

class TenantNotifier extends StateNotifier<List<Tenant>> {
  final SecureStorageService _storage;

  TenantNotifier(this._storage) : super(const []);

  void addTenant(Tenant tenant) {
    state = [...state, tenant];
    _saveTenants();
  }

  void updateTenant(Tenant tenant) {
    final index = state.indexWhere((t) => t.name == tenant.name && t.roomNumber == tenant.roomNumber && t.bedNumber == tenant.bedNumber);
    if (index >= 0) {
      state = [...state..index = tenant];
      _saveTenants();
    }
  }

  void removeTenant(String name, String roomNumber, String bedNumber) {
    state = state.where((t) => !(t.name == name && t.roomNumber == roomNumber && t.bedNumber == bedNumber)).toList();
    _saveTenants();
  }

  Tenant? getTenant(String name, String roomNumber, String bedNumber) {
    return firstWhere((t) => t.name == name && t.roomNumber == roomNumber && t.bedNumber == bedNumber, orElse: () => Tenant(
      name: '',
      mobileNumber: '',
      email: '',
      address: '',
      roomNumber: '',
      bedNumber: '',
      moveInDate: '',
      rentPaid: 0,
      depositPaid: 0,
      outstandingBalance: 0,
    ));
  }

  List<Tenant> getTenantsByRoom(String roomNumber) {
    return state.where((t) => t.roomNumber == roomNumber).toList();
  }

  void _saveTenants() {
    final tenantData = state.map((tenant) => tenant.toMap()).toList();
    _storage.write(key: 'saved_tenants', value: tenantData.toString());
  }
}