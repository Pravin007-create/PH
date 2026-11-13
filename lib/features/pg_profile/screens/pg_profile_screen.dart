import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/theme/app_theme.dart';
import 'package:pg_hostel_management/features/pg_profile/models/pg_profile.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';

class PGProfileScreen extends StatefulWidget {
  const PGProfileScreen({super.key});

  @override
  State<PGProfileScreen> createState() => _PGProfileScreenState();
}

class _PGProfileScreenState extends State<PGProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _pgNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailController = TextEditingController();

  late final PGProfileNotifier _notifier;
  late final SecureStorageService _storage;

  @override
  void initState() {
    super.initState();
    _storage = SecureStorageService();
    _notifier = context.read<PGProfileNotifier>();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final profile = await _storage.isActivated() ? PGProfile(
      ownerName: await _storage.getOwnerName() ?? '',
      pgName: await _storage.getPGName() ?? '',
      address: '',
      mobileNumber: await _storage.getMobileNumber() ?? '',
      email: '',
      numberOfRooms: 0,
      facilities: '',
      billingPreferences: '',
      isActivated: true,
    ) : const PGProfile(
      ownerName: '',
      pgName: '',
      address: '',
      mobileNumber: '',
      email: '',
      numberOfRooms: 0,
      facilities: '',
      billingPreferences: '',
      isActivated: false,
    );

    _ownerNameController.text = profile.ownerName;
    _pgNameController.text = profile.pgName;
    _addressController.text = profile.address;
    _mobileNumberController.text = profile.mobileNumber;
    _emailController.text = profile.email ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PG Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'PG Profile Information',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    ValidationUtils.validateName(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pgNameController,
                decoration: const InputDecoration(
                  labelText: 'PG Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    ValidationUtils.validateName(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'PG Address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    ValidationUtils.validateName(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileNumberController,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    ValidationUtils.validateMobile(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    ValidationUtils.validateEmail(value),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final profile = PGProfile(
                      ownerName: _ownerNameController.text,
                      pgName: _pgNameController.text,
                      address: _addressController.text,
                      mobileNumber: _mobileNumberController.text,
                      email: _emailController.text,
                      numberOfRooms: 0,
                      facilities: '',
                      billingPreferences: '',
                      isActivated: true,
                    );

                    _notifier.updateProfile(
                      ownerName: profile.ownerName,
                      pgName: profile.pgName,
                      address: profile.address,
                      mobileNumber: profile.mobileNumber,
                      isActivated: true,
                    );

                    _storage.saveActivationStatus(
                      isActivated: true,
                      ownerName: profile.ownerName,
                      pgName: profile.pgName,
                      mobileNumber: profile.mobileNumber,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PG Profile saved successfully'),
                        backgroundColor: Color(0xFF1976D2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: const Text('Save Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}