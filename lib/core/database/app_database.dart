import 'package:drift/drift.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../features/activation/activation_screen.dart';
import '../features/pg_profile/models/pg_profile.dart';
import '../features/room_management/models/room.dart';
import '../features/bed_management/models/bed.dart';
import '../features/tenant_management/models/tenant.dart';
import '../features/rent_payment/models/rent_payment.dart';
import '../features/electricity_bills/models/electricity_bill.dart';
import '../features/expenses/models/expense.dart';

class AppDatabase extends DatabaseContract {
  @override
  get tables => [
    pgProfiles,
    rooms,
    beds,
    tenants,
    rentPayments,
    electricityBills,
    expenses,
  ];

  @override
  get migrations => [];
}

class DatabaseContract {
  final List<Table> tables;
  final List<Migration> migrations;

  DatabaseContract({
    required this.tables,
    required this.migrations,
  });
}

class _PGProfiles extends Table {
  TextColumn get ownerName => text()('owner_name');
  TextColumn get pgName => text()('pg_name');
  TextColumn get address => text()('address');
  TextColumn get mobileNumber => text()('mobile_number');
  TextColumn get email => text()('email');
  TextColumn get numberOfRooms => integer()('number_of_rooms');
  TextColumn get facilities => text()('facilities');
  TextColumn get billingPreferences => text()('billing_preferences');
  TextColumn get isActivated => boolean()('is_activated');
  TextColumn get activationOTP => text()('activation_otp');
  TextColumn get activationOTPExpiry => text()('activation_otp_expiry');

  @override
  String get name => 'pg_profiles';

  @override
  Set<Column> get primaryKey => {ownerName}; // Single PG owner primary key
}

class _Rooms extends Table {
  TextColumn get roomNumber => text()('room_number');
  TextColumn get floor => text()('floor');
  TextColumn get isAC => boolean()('is_ac');
  TextColumn get sharingType => text()('sharing_type');
  TextColumn get totalCapacity => integer()('total_capacity');
  TextColumn get numberOfBeds => integer()('number_of_beds');
  TextColumn get roomFacilities => text()('room_facilities');
  TextColumn get monthlyRent => double()('monthly_rent');
  TextColumn get electricityBillingType => text()('electricity_billing_type');
  TextColumn get roomStatus => text()('room_status');
  TextColumn get pgOwner => text()('pg_owner');

  @override
  String get name => 'rooms';

  @override
  Set<Column> get primaryKey => {roomNumber};
}

class _Beds extends Table {
  TextColumn get bedNumber => text()('bed_number');
  TextColumn get roomNumber => text()('room_number');
  TextColumn get status => text()('status');

  @override
  String get name => 'beds';

  @override
  Set<Column> get primaryKey => {bedNumber};
}

class _Tenants extends Table {
  TextColumn get name => text()('name');
  TextColumn get mobileNumber => text()('mobile_number');
  TextColumn get email => text()('email');
  TextColumn get address => text()('address');
  TextColumn get roomNumber => text()('room_number');
  TextColumn get bedNumber => text()('bed_number');
  TextColumn get moveInDate => text()('move_in_date');
  TextColumn get moveOutDate => text()('move_out_date');
  TextColumn get rentPaid => double()('rent_paid');
  TextColumn get depositPaid => double()('deposit_paid');
  TextColumn get outstandingBalance => double()('outstanding_balance');
  TextColumn get pgOwner => text()('pg_owner');

  @override
  String get name => 'tenants';

  @override
  Set<Column> get primaryKey => {name, roomNumber, bedNumber};
}

class _RentPayments extends Table {
  TextColumn get tenantName => text()('tenant_name');
  TextColumn get roomNumber => text()('room_number');
  TextColumn get bedNumber => text()('bed_number');
  TextColumn get amount => double()('amount');
  TextColumn get paymentDate => text()('payment_date');
  TextColumn get month => text()('month');
  TextColumn get pgOwner => text()('pg_owner');

  @override
  String get name => 'rent_payments';

  @override
  Set<Column> get primaryKey => {tenantName, roomNumber, bedNumber, month};
}

class _ElectricityBills extends Table {
  TextColumn get tenantName => text()('tenant_name');
  TextColumn get roomNumber => text()('room_number');
  TextColumn get bedNumber => text()('bed_number');
  TextColumn get amount => double()('amount');
  TextColumn get billDate => text()('bill_date');
  TextColumn get month => text()('month');
  TextColumn get pgOwner => text()('pg_owner');

  @override
  String get name => 'electricity_bills';

  @override
  Set<Column> get primaryKey => {tenantName, roomNumber, bedNumber, month};
}

class _Expenses extends Table {
  TextColumn get description => text()('description');
  TextColumn get amount => double()('amount');
  TextColumn get date => text()('date');
  TextColumn get category => text()('category');
  TextColumn get pgOwner => text()('pg_owner');

  @override
  String get name => 'expenses';

  @override
  Set<Column> get primaryKey => {description};
}

class AppDatabase extends $_AppDatabase {
  AppDatabase() : super(_initializeTables());

  static Schema _initializeTables() {
    return Schema({
      _PGProfiles().createIfNotExists,
      _Rooms().createIfNotExists,
      _Beds().createIfNotExists,
      _Tenants().createIfNotExists,
      _RentPayments().createIfNotExists,
      _ElectricityBills().createIfNotExists,
      _Expenses().createIfNotExists,
    });
  }
}