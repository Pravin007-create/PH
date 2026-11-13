import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/utils/validation_utils.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';
import 'package:pg_hostel_management/features/pg_profile/models/pg_profile.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameController = TextEditingController();
  final _pgNameController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  String _generatedOTP = '';
  int _otpAttempts = 0;
  DateTime? _otpSentTime;
  bool _isSendingOTP = false;
  bool _isActivated = false;

  @override
  void initState() {
    super.initState();
    _checkExistingActivation();
  }

  Future<void> _checkExistingActivation() async {
    final isActivated = await SecureStorageService().isActivated();
    if (isActivated) {
      _navigateToHome();
    }
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSendingOTP = true);

    // Generate random 6-digit OTP
    final random = DateTime.now().millisecondsSinceEpoch.remainder(900000) + 100000;
    _generatedOTP = random.toString();
    _otpSentTime = DateTime.now();

    // Simulate sending OTP to business email
    // In a real implementation, this would use the device's email/sms capability
    _showOTPSentDialog();

    setState(() => _isSendingOTP = false);
  }

  void _showOTPSentDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OTP Sent'),
        content: const Text(
          'A 6-digit OTP has been sent to your business email. '
          'Please check your email and enter the OTP below.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _verifyOTP(String otp) async {
    if (_otpAttempts >= 3) {
      _showMaxAttemptsDialog();
      return;
    }

    final expiry = await SecureStorageService().getOTPExpiry();
    if (expiry != null) {
      final expiryTime = DateTime.parse(expiry);
      if (DateTime.now().isAfter(expiryTime)) {
        _showOTPExpiredDialog();
        return;
      }
    }

    setState(() {
      _otpAttempts++;
    });

    if (otp == _generatedOTP) {
      // OTP verified - activate the application
      await _activateApplication();
    } else {
      _showInvalidOTPDialog();
    }
  }

  Future<void> _activateApplication() async {
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

    final storage = SecureStorageService();
    await storage.saveActivationStatus(
      isActivated: true,
      ownerName: profile.ownerName,
      pgName: profile.pgName,
      mobileNumber: profile.mobileNumber,
    );
    await storage.saveOTP(
      otp: _generatedOTP,
      expiry: DateTime.now().add(const Duration(minutes: 10)).toIso8601String(),
    );

    setState(() => _isActivated = true);
    _navigateToHome();
  }

  void _showMaxAttemptsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Maximum Attempts Reached'),
        content: const Text(
          'You have exceeded the maximum OTP verification attempts. '
          'Please restart the application or contact support.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).popAndPushNamed('/activation'),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showOTPExpiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('OTP Expired'),
        content: const Text('The OTP has expired. Please request a new one.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _sendOTP();
            },
            child: const Text('Resend'),
          ),
        ],
      ),
    );
  }

  void _showInvalidOTPDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invalid OTP'),
        content: const Text('The OTP you entered is incorrect. Please try again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacementNamed('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PG Hostel Manager'),
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
              const SizedBox(height: 40),
              const Icon(
                Icons.business,
                size: 80,
                color: Color(0xFF1976D2),
              ),
              const SizedBox(height: 24),
              const Text(
                'Owner Registration & Activation',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Please fill in the details below to activate the application',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _ownerNameController,
                decoration: const InputDecoration(
                  labelText: 'Owner Name',
                  hintText: 'Enter owner name',
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
                  hintText: 'Enter PG/Hostel name',
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
                  hintText: 'Enter mobile number',
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
                  hintText: 'Enter business email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    ValidationUtils.validateEmail(value),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'PG Address',
                  hintText: 'Enter PG/Hostel address',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    ValidationUtils.validateName(value),
              ),
              const SizedBox(height: 32),
              _isSendingOTP
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      onPressed: _sendOTP,
                      child: const Text('Send OTP & Activate'),
                    ),
              const SizedBox(height: 24),
              // Manual OTP entry section
              _isActivated
                  ? const Column()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                        'Enter OTP received via email:',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                        const SizedBox(height: 8),
                        TextFormField(
                          decoration: const InputDecoration(
                            hintText: '123456',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          maxLength: 6,
                          validator: (value) =>
                              ValidationUtils.validateOTP(value),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              final otp = _ownerNameController.text; // Using controller as placeholder
                              // In real app, get OTP from the text field
                              _verifyOTP(otp);
                            }
                          },
                          child: const Text('Verify OTP'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
