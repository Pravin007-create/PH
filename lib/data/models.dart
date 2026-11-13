/// Plain data classes, stored on the device as JSON.

class Room {
  final String id;
  final String number;
  final String floor;
  final int beds;

  /// Default monthly rent per bed (pre-fills new tenants in this room).
  final double rent;
  final bool isAC;
  final String notes;

  const Room({
    required this.id,
    required this.number,
    this.floor = '',
    required this.beds,
    required this.rent,
    this.isAC = false,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'floor': floor,
        'beds': beds,
        'rent': rent,
        'isAC': isAC,
        'notes': notes,
      };

  factory Room.fromJson(Map<String, dynamic> j) => Room(
        id: j['id'] as String,
        number: j['number'] as String,
        floor: (j['floor'] ?? '') as String,
        beds: (j['beds'] as num).toInt(),
        rent: (j['rent'] as num).toDouble(),
        isAC: (j['isAC'] ?? false) as bool,
        notes: (j['notes'] ?? '') as String,
      );
}

class Tenant {
  final String id;
  final String name;
  final String phone;
  final String? roomId;
  final double rent;
  final double deposit;
  final DateTime joinDate;

  /// Set when the tenant moves out. Null = currently staying.
  final DateTime? leaveDate;
  final String notes;

  const Tenant({
    required this.id,
    required this.name,
    required this.phone,
    this.roomId,
    required this.rent,
    this.deposit = 0,
    required this.joinDate,
    this.leaveDate,
    this.notes = '',
  });

  bool get isActive => leaveDate == null;

  Tenant copyWith({DateTime? leaveDate, bool clearLeaveDate = false}) => Tenant(
        id: id,
        name: name,
        phone: phone,
        roomId: roomId,
        rent: rent,
        deposit: deposit,
        joinDate: joinDate,
        leaveDate: clearLeaveDate ? null : (leaveDate ?? this.leaveDate),
        notes: notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'roomId': roomId,
        'rent': rent,
        'deposit': deposit,
        'joinDate': joinDate.toIso8601String(),
        'leaveDate': leaveDate?.toIso8601String(),
        'notes': notes,
      };

  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: (j['phone'] ?? '') as String,
        roomId: j['roomId'] as String?,
        rent: (j['rent'] as num).toDouble(),
        deposit: ((j['deposit'] ?? 0) as num).toDouble(),
        joinDate: DateTime.parse(j['joinDate'] as String),
        leaveDate: j['leaveDate'] == null
            ? null
            : DateTime.parse(j['leaveDate'] as String),
        notes: (j['notes'] ?? '') as String,
      );
}

enum PaymentType {
  rent('Rent'),
  electricity('Electricity'),
  deposit('Deposit'),
  other('Other');

  const PaymentType(this.label);
  final String label;
}

const paymentModes = ['Cash', 'UPI', 'Bank transfer', 'Other'];

class Payment {
  final String id;
  final String tenantId;
  final double amount;
  final PaymentType type;

  /// The month this payment is for (first day of month).
  final DateTime month;

  /// The day the money was received.
  final DateTime date;
  final String mode;
  final String note;

  const Payment({
    required this.id,
    required this.tenantId,
    required this.amount,
    required this.type,
    required this.month,
    required this.date,
    this.mode = 'Cash',
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'tenantId': tenantId,
        'amount': amount,
        'type': type.name,
        'month': month.toIso8601String(),
        'date': date.toIso8601String(),
        'mode': mode,
        'note': note,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        tenantId: j['tenantId'] as String,
        amount: (j['amount'] as num).toDouble(),
        type: PaymentType.values.firstWhere((t) => t.name == j['type'],
            orElse: () => PaymentType.other),
        month: DateTime.parse(j['month'] as String),
        date: DateTime.parse(j['date'] as String),
        mode: (j['mode'] ?? 'Cash') as String,
        note: (j['note'] ?? '') as String,
      );
}

const expenseCategories = [
  'Electricity',
  'Water',
  'Maintenance',
  'Groceries',
  'Salary',
  'Internet',
  'Rent / Lease',
  'Other',
];

class Expense {
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;
  final String note;

  const Expense({
    required this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        title: j['title'] as String,
        category: (j['category'] ?? 'Other') as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] ?? '') as String,
      );
}

class PgProfile {
  final String pgName;
  final String ownerName;
  final String phone;
  final String address;

  const PgProfile({
    this.pgName = '',
    this.ownerName = '',
    this.phone = '',
    this.address = '',
  });

  bool get isEmpty => pgName.isEmpty && ownerName.isEmpty;

  Map<String, dynamic> toJson() => {
        'pgName': pgName,
        'ownerName': ownerName,
        'phone': phone,
        'address': address,
      };

  factory PgProfile.fromJson(Map<String, dynamic> j) => PgProfile(
        pgName: (j['pgName'] ?? '') as String,
        ownerName: (j['ownerName'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        address: (j['address'] ?? '') as String,
      );
}
