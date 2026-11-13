import 'package:pg_hostel_management/features/bed_management/models/bed.dart';

class AppConstants {
  static const String appName = 'PG Hostel Manager';
  static const String version = '1.0.0';

  // OTP settings
  static const int otpLength = 6;
  static const Duration otpExpiryDuration = Duration(minutes: 10);
  static const int maxOTPAttempts = 3;

  // Database table names
  static const String pgProfilesTable = 'pg_profiles';
  static const String roomsTable = 'rooms';
  static const String bedsTable = 'beds';
  static const String tenantsTable = 'tenants';
  static const String rentPaymentsTable = 'rent_payments';
  static const String electricityBillsTable = 'electricity_bills';
  static const String expensesTable = 'expenses';

  // Status values
  static const String roomStatusActive = 'Active';
  static const String roomStatusInactive = 'Inactive';
  static const BedStatus available = BedStatus.available;
  static const BedStatus occupied = BedStatus.occupied;
  static const BedStatus maintenance = BedStatus.maintenance;
  static const BedStatus deactivated = BedStatus.deactivated;

  // Categories
  static const List<String> expenseCategories = [
    'Maintenance',
    'Utilities',
    'Food',
    'Other',
  ];

  // Payment months
  static const List<String> paymentMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
}