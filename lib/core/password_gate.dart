import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';
import 'package:pg_hostel_management/core/router/app_router.dart';
import 'package:pg_hostel_management/core/theme/app_theme.dart';

const developerPassword = 'R@kshu@263108##';

class PasswordGate extends StatefulWidget {
  const PasswordGate({super.key});

  @override
  State<PasswordGate> createState() => _PasswordGateState();
}

class _PasswordGateState extends State<PasswordGate> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _verifyAndProceed() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Compare entered password with developer password
    final enteredPassword = _passwordController.text;
    final isCorrect = enteredPassword == developerPassword;

    if (isCorrect) {
      // Save that password has been verified
      await SecureStorageService().write(
        key: 'developer_password_verified',
        value: 'true',
      );

      // Proceed to normal app flow
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/');
    } else {
      // Show error and allow retry
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid developer password. Access denied.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PG Hostel Manager'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Color(0xFF1976D2),
                ),
                const SizedBox(height: 24),
                const Text(
                  'PG Hostel Manager',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter Developer Password',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Developer Password',
                    hintText: 'Enter password to access app',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.remove_red_eye),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _verifyAndProceed,
                        child: const Text('Unlock Application'),
                      ),
                const SizedBox(height: 16),
                const Text(
                  'Password is set by developer and stored securely after entry',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}