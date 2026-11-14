/// Plain data classes, stored on the device as JSON.

class Room {
  final String id;
  final String number;
  final String floor;
  final int beds;

  /// Default monthly rent per bed (pre-fills new tenants in this room).
  final double rent;
  final bool isAC;

  /// Electricity is billed separately and split between the room's tenants.
  final bool separateElectricity;
  final String notes;

  const Room({
    required this.id,
    required this.number,
    this.floor = '',
    required this.beds,
    required this.rent,
    this.isAC = false,
    this.separateElectricity = false,
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'separateElectricity': separateElectricity,
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
        separateElectricity: (j['separateElectricity'] ?? false) as bool,
        notes: (j['notes'] ?? '') as String,
      );
}

/// One deduction line at move-out (cleaning, damage, ...).
class Deduction {
  const Deduction(this.label, this.amount, {this.type, this.month});
  final String label;
  final double amount;

  /// Recorded as this payment type / month (e.g. an electricity share).
  /// Defaults to "Other" in the move-out month.
  final PaymentType? type;
  final DateTime? month;

  Map<String, dynamic> toJson() => {'label': label, 'amount': amount};
  factory Deduction.fromJson(Map<String, dynamic> j) =>
      Deduction(j['label'] as String, (j['amount'] as num).toDouble());
}

/// Final account when a tenant moves out: advance minus dues = refund.
class Settlement {
  const Settlement({
    required this.date,
    required this.deposit,
    this.collectedNow = 0,
    required this.rentAdjusted,
    required this.rentMonths,
    this.deductions = const [],
    required this.refund,
    this.stillOwed = 0,
    this.waivedMonths = const [],
  });

  final DateTime date;

  /// Advance held when moving out.
  final double deposit;

  /// Cash collected at move-out when the advance wasn't enough.
  final double collectedNow;

  /// Pending rent cleared from the advance.
  final double rentAdjusted;

  /// e.g. ["October 2026", "November 2026"]
  final List<String> rentMonths;
  final List<Deduction> deductions;

  /// Amount returned to the tenant.
  final double refund;

  /// Dues the advance + cash didn't cover.
  final double stillOwed;

  /// Rent months the owner chose not to charge (first day of month).
  final List<DateTime> waivedMonths;

  double get deductionsTotal => deductions.fold(0, (s, d) => s + d.amount);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'deposit': deposit,
        'collectedNow': collectedNow,
        'rentAdjusted': rentAdjusted,
        'rentMonths': rentMonths,
        'deductions': deductions.map((d) => d.toJson()).toList(),
        'refund': refund,
        'stillOwed': stillOwed,
        'waivedMonths': waivedMonths.map((m) => m.toIso8601String()).toList(),
      };

  factory Settlement.fromJson(Map<String, dynamic> j) => Settlement(
        date: DateTime.parse(j['date'] as String),
        deposit: (j['deposit'] as num).toDouble(),
        collectedNow: ((j['collectedNow'] ?? 0) as num).toDouble(),
        rentAdjusted: (j['rentAdjusted'] as num).toDouble(),
        rentMonths: List<String>.from((j['rentMonths'] ?? const []) as List),
        deductions: [
          for (final d in (j['deductions'] ?? const []) as List)
            Deduction.fromJson(Map<String, dynamic>.from(d as Map))
        ],
        refund: (j['refund'] as num).toDouble(),
        stillOwed: ((j['stillOwed'] ?? 0) as num).toDouble(),
        waivedMonths: [
          for (final m in (j['waivedMonths'] ?? const []) as List)
            DateTime.parse(m as String)
        ],
      );
}

/// An ID proof / document photo (or PDF) attached to a tenant.
class TenantDocument {
  const TenantDocument({
    required this.id,
    required this.label,
    required this.path,
    required this.addedAt,
  });

  final String id;

  /// e.g. "Aadhaar card".
  final String label;

  /// File name inside the app's tenant_docs folder (see documents.dart).
  final String path;
  final DateTime addedAt;

  bool get isPdf => path.toLowerCase().endsWith('.pdf');

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'path': path,
        'addedAt': addedAt.toIso8601String(),
      };

  factory TenantDocument.fromJson(Map<String, dynamic> j) => TenantDocument(
        id: j['id'] as String,
        label: (j['label'] ?? 'Document') as String,
        path: j['path'] as String,
        addedAt: DateTime.parse(j['addedAt'] as String),
      );
}

const documentTypes = [
  'Aadhaar card',
  'PAN card',
  'Driving licence',
  'Passport',
  'Voter ID',
  'College / Office ID',
  'Rental agreement',
  'Photo',
  'Other',
];

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

  /// Planned last day of stay (notice given). Optional; the bed is shown as
  /// vacant from the next day. The tenant stays active until moved out.
  final DateTime? relievingDate;
  final String notes;

  /// When the tenant was added to the app. Unpaid rent from months before
  /// this is not counted as overdue (the owner may not have recorded it).
  final DateTime? createdAt;

  /// Filled in when the tenant moves out through the settlement screen.
  final Settlement? settlement;

  /// ID proof photos / PDFs.
  final List<TenantDocument> documents;

  /// Owner has collected the tenant's ID proof.
  final bool documentsSubmitted;

  const Tenant({
    required this.id,
    required this.name,
    required this.phone,
    this.roomId,
    required this.rent,
    this.deposit = 0,
    required this.joinDate,
    this.leaveDate,
    this.relievingDate,
    this.notes = '',
    this.createdAt,
    this.settlement,
    this.documents = const [],
    this.documentsSubmitted = false,
  });

  bool get isActive => leaveDate == null;

  /// First day the bed is free: the day after the relieving date.
  DateTime? get vacantFrom => relievingDate == null
      ? null
      : DateTime(
          relievingDate!.year, relievingDate!.month, relievingDate!.day + 1);

  /// createdAt, or recovered from the id (ids are creation timestamps).
  DateTime get addedOn {
    if (createdAt != null) return createdAt!;
    final micros = int.tryParse(id);
    if (micros != null && micros > 1000000000000000) {
      return DateTime.fromMicrosecondsSinceEpoch(micros);
    }
    return joinDate;
  }

  Tenant copyWith({
    DateTime? leaveDate,
    bool clearLeaveDate = false,
    Settlement? settlement,
    bool clearSettlement = false,
    bool clearRelievingDate = false,
    List<TenantDocument>? documents,
    bool? documentsSubmitted,
  }) =>
      Tenant(
        id: id,
        name: name,
        phone: phone,
        roomId: roomId,
        rent: rent,
        deposit: deposit,
        joinDate: joinDate,
        leaveDate: clearLeaveDate ? null : (leaveDate ?? this.leaveDate),
        relievingDate: clearRelievingDate ? null : relievingDate,
        notes: notes,
        createdAt: createdAt,
        settlement: clearSettlement ? null : (settlement ?? this.settlement),
        documents: documents ?? this.documents,
        documentsSubmitted: documentsSubmitted ?? this.documentsSubmitted,
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
        'relievingDate': relievingDate?.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt?.toIso8601String(),
        'settlement': settlement?.toJson(),
        'documents': documents.map((d) => d.toJson()).toList(),
        'documentsSubmitted': documentsSubmitted,
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
        relievingDate: j['relievingDate'] == null
            ? null
            : DateTime.parse(j['relievingDate'] as String),
        notes: (j['notes'] ?? '') as String,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.parse(j['createdAt'] as String),
        settlement: j['settlement'] == null
            ? null
            : Settlement.fromJson(
                Map<String, dynamic>.from(j['settlement'] as Map)),
        documents: [
          for (final d in (j['documents'] ?? const []) as List)
            TenantDocument.fromJson(Map<String, dynamic>.from(d as Map))
        ],
        documentsSubmitted: (j['documentsSubmitted'] ?? false) as bool,
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

/// Mode used for dues cleared from the tenant's advance at move-out.
const adjustedFromDeposit = 'Adjusted from deposit';

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

/// A payment that was deleted, kept as a log entry.
class DeletedPayment {
  const DeletedPayment({
    required this.payment,
    required this.deletedAt,
    this.tenantName = '',
    this.reason = '',
  });

  final Payment payment;
  final DateTime deletedAt;

  /// Saved in case the tenant is deleted later.
  final String tenantName;
  final String reason;

  String get id => payment.id;

  Map<String, dynamic> toJson() => {
        'payment': payment.toJson(),
        'deletedAt': deletedAt.toIso8601String(),
        'tenantName': tenantName,
        'reason': reason,
      };

  factory DeletedPayment.fromJson(Map<String, dynamic> j) => DeletedPayment(
        payment:
            Payment.fromJson(Map<String, dynamic>.from(j['payment'] as Map)),
        deletedAt: DateTime.parse(j['deletedAt'] as String),
        tenantName: (j['tenantName'] ?? '') as String,
        reason: (j['reason'] ?? '') as String,
      );
}

/// A room's electricity bill for one month, split equally between the
/// tenants staying in the room.
class ElectricityBill {
  const ElectricityBill({
    required this.id,
    required this.roomId,
    required this.month,
    required this.amount,
    required this.tenantIds,
    this.units = 0,
    required this.createdAt,
  });

  final String id;
  final String roomId;

  /// First day of the month the bill is for.
  final DateTime month;
  final double amount;

  /// Units consumed (optional, for reference).
  final double units;
  final List<String> tenantIds;
  final DateTime createdAt;

  /// Each tenant's share.
  double get share => tenantIds.isEmpty ? 0 : amount / tenantIds.length;

  Map<String, dynamic> toJson() => {
        'id': id,
        'roomId': roomId,
        'month': month.toIso8601String(),
        'amount': amount,
        'units': units,
        'tenantIds': tenantIds,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ElectricityBill.fromJson(Map<String, dynamic> j) => ElectricityBill(
        id: j['id'] as String,
        roomId: j['roomId'] as String,
        month: DateTime.parse(j['month'] as String),
        amount: (j['amount'] as num).toDouble(),
        units: ((j['units'] ?? 0) as num).toDouble(),
        tenantIds: List<String>.from((j['tenantIds'] ?? const []) as List),
        createdAt: DateTime.parse(j['createdAt'] as String),
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

/// When rent for a month is collected.
enum RentCycle {
  /// Rent for November is collected from 1 November.
  monthStart('Start of month'),

  /// Rent for October is collected at the end of October (paid by early Nov).
  monthEnd('End of month');

  const RentCycle(this.label);
  final String label;
}

class PgProfile {
  final String pgName;
  final String ownerName;
  final String phone;
  final String address;
  final RentCycle rentCycle;

  /// Days allowed to pay. Start of month + 5 → due by the 5th.
  /// End of month + 5 → due by the 5th of the next month.
  final int dueDays;

  const PgProfile({
    this.pgName = '',
    this.ownerName = '',
    this.phone = '',
    this.address = '',
    this.rentCycle = RentCycle.monthStart,
    this.dueDays = 5,
  });

  bool get isEmpty => pgName.isEmpty && ownerName.isEmpty;

  Map<String, dynamic> toJson() => {
        'pgName': pgName,
        'ownerName': ownerName,
        'phone': phone,
        'address': address,
        'rentCycle': rentCycle.name,
        'dueDays': dueDays,
      };

  factory PgProfile.fromJson(Map<String, dynamic> j) => PgProfile(
        pgName: (j['pgName'] ?? '') as String,
        ownerName: (j['ownerName'] ?? '') as String,
        phone: (j['phone'] ?? '') as String,
        address: (j['address'] ?? '') as String,
        rentCycle: RentCycle.values.firstWhere((c) => c.name == j['rentCycle'],
            orElse: () => RentCycle.monthStart),
        dueDays: ((j['dueDays'] ?? 5) as num).toInt().clamp(1, 28),
      );
}
