import 'package:validatorator/validatorator.dart';

class ValidationUtils {
  static String? validateName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Name is required';
    }
    if (value.length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  static String? validateMobile(String? value) {
    if (value == null || value.isEmpty) {
      return 'Mobile number is required';
    }
    if (value.length != 10) {
      return 'Mobile number must be 10 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'Mobile number must contain only digits';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validateOTP(String? value) {
    if (value == null || value.isEmpty) {
      return 'OTP is required';
    }
    if (value.length != 6) {
      return 'OTP must be 6 digits';
    }
    if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
      return 'OTP must contain only digits';
    }
    return null;
  }

  static String? validateRoomNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Room number is required';
    }
    return null;
  }

  static String? validateRentAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Rent amount is required';
    }
    final double? = double.tryParse(value);
    if ( == null || <= 0) {
      return 'Enter a valid rent amount';
    }
    return null;
  }

  static String? validateExpenseAmount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Expense amount is required';
    }
    final double? = double.tryParse(value);
    if ( == null || <= 0) {
      return 'Enter a valid expense amount';
    }
    return null;
  }
}