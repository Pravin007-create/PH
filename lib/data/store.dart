import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Overridden in main() with the real instance (and in tests with a mock).
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('prefsProvider must be overridden'),
);

/// A list of records saved on the device as JSON under [key].
class ListStore<T> extends StateNotifier<List<T>> {
  ListStore(this._prefs, this.key, T Function(Map<String, dynamic>) fromJson,
      this._toJson, this._idOf)
      : super(_load(_prefs, key, fromJson));

  final SharedPreferences _prefs;
  final String key;
  final Map<String, dynamic> Function(T) _toJson;
  final String Function(T) _idOf;

  static List<T> _load<T>(SharedPreferences prefs, String key,
      T Function(Map<String, dynamic>) fromJson) {
    final raw = prefs.getString(key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  T? byId(String? id) {
    if (id == null) return null;
    for (final item in state) {
      if (_idOf(item) == id) return item;
    }
    return null;
  }

  /// Adds the item, or replaces the existing item with the same id.
  void save(T item) {
    final id = _idOf(item);
    final i = state.indexWhere((e) => _idOf(e) == id);
    state = i < 0 ? [...state, item] : ([...state]..[i] = item);
    _persist();
  }

  void remove(String id) {
    state = state.where((e) => _idOf(e) != id).toList();
    _persist();
  }

  void _persist() =>
      _prefs.setString(key, jsonEncode(state.map(_toJson).toList()));
}

final roomsProvider = StateNotifierProvider<ListStore<Room>, List<Room>>(
  (ref) => ListStore(ref.watch(prefsProvider), 'rooms', Room.fromJson,
      (r) => r.toJson(), (r) => r.id),
);

final tenantsProvider = StateNotifierProvider<ListStore<Tenant>, List<Tenant>>(
  (ref) => ListStore(ref.watch(prefsProvider), 'tenants', Tenant.fromJson,
      (t) => t.toJson(), (t) => t.id),
);

final paymentsProvider =
    StateNotifierProvider<ListStore<Payment>, List<Payment>>(
  (ref) => ListStore(ref.watch(prefsProvider), 'payments', Payment.fromJson,
      (p) => p.toJson(), (p) => p.id),
);

final expensesProvider =
    StateNotifierProvider<ListStore<Expense>, List<Expense>>(
  (ref) => ListStore(ref.watch(prefsProvider), 'expenses', Expense.fromJson,
      (e) => e.toJson(), (e) => e.id),
);

class ProfileStore extends StateNotifier<PgProfile> {
  ProfileStore(this._prefs) : super(_load(_prefs));
  final SharedPreferences _prefs;

  static PgProfile _load(SharedPreferences prefs) {
    final raw = prefs.getString('profile');
    if (raw == null) return const PgProfile();
    try {
      return PgProfile.fromJson(Map<String, dynamic>.from(jsonDecode(raw)));
    } catch (_) {
      return const PgProfile();
    }
  }

  void save(PgProfile profile) {
    state = profile;
    _prefs.setString('profile', jsonEncode(profile.toJson()));
  }
}

final profileProvider = StateNotifierProvider<ProfileStore, PgProfile>(
  (ref) => ProfileStore(ref.watch(prefsProvider)),
);
