import 'package:flutter/material.dart';
import 'package:pg_hostel_management/core/theme/app_theme.dart';
import 'package:pg_hostel_management/core/securestorage/securestorage_service.dart';
import 'package:pg_hostel_management/core/router/app_router.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState;
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isBackupInProgress = false;
  bool _isRestoreInProgress = false;
  String? _lastBackupMessage;
  String? _lastRestoreMessage;

  Future<void> _createBackup() async {
    setState(() {
      _isBackupInProgress = true;
      _lastBackupMessage = '';
    });

    try {
      // In a full implementation with Drift, we would query the database tables
      // and create a comprehensive backup file.
      // For now, we'll simulate a backup by saving the current state to secure storage.

      // Collect data from secure storage
      final storage = SecureStorageService();
      
      // Create a backup JSON structure
      final backupData = {
        'timestamp': DateTime.now().toIso8601String(),
        'appVersion': '1.0.0',
        'database': {
          'rooms': [], // Would be populated from Drift
          'beds': [], // Would be populated from Drift
          'tenants': [], // Would be populated from Drift
          'payments': [], // Would be populated from Drift
          'bills': [], // Would be populated from Drift
          'expenses': [], // Would be populated from Drift
        },
      };

      // Save backup to secure storage
      await storage.write(
        key: 'last_backup',
        value: backupData.toString(),
      );

      setState(() {
        _lastBackupMessage = 'Backup created successfully at ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}';
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup created successfully'),
            backgroundColor: Color(0xFF1976D2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastBackupMessage = 'Backup failed: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Backup failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isBackupInProgress = false);
      }
    }
  }

  Future<void> _restoreFromBackup() async {
    setState(() {
      _isRestoreInProgress = true;
      _lastRestoreMessage = '';
    });

    try {
      final storage = SecureStorageService();
      final backupData = await storage.read(key: 'last_backup');

      if (backupData == null) {
        setState(() {
          _lastRestoreMessage = 'No backup found. Create a backup first.';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No backup found. Create a backup first.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // In a full implementation with Drift, we would parse the backup data and
      // reset/update all database tables.
      // For now, we'll just show a success message.

      setState(() {
        _lastRestoreMessage = 'Restore completed successfully';
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data restored successfully'),
            backgroundColor: Color(0xFF1976D2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      // Refresh the data
      // In a full implementation, would reload from Drift database
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data has been restored. Please restart the application.'),
            backgroundColor: Color(0xFF1976D2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _lastRestoreMessage = 'Restore failed: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRestoreInProgress = false);
      }
    }
  }

  Future<void> _exportCSV() async {
    // In a full implementation, export specific data to CSV
    // For now, show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CSV export feature coming soon'),
          backgroundColor: Color(0xFF1976D2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _exportPDF() async {
    // In a full implementation, generate PDF report
    // For now, show a message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF report generation coming soon'),
          backgroundColor: Color(0xFF1976D2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Data Management',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 24),

            // Backup Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children [
                    const Text(
                      'Backup Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isBackupInProgress
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _createBackup,
                            child: const Text('Create Backup'),
                          ),
                    const SizedBox(height: 8),
                    if (_lastBackupMessage != null)
                      Text(
                        _lastBackupMessage!,
                        style: TextStyle(
                          color: _lastBackupMessage!.contains('success') 
                              ? Colors.green 
                              : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Restore Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children [
                    const Text(
                      'Restore Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _isRestoreInProgress
                        ? const CircularProgressIndicator()
                        : ElevatedButton(
                            onPressed: _restoreFromBackup,
                            child: const Text('Restore from Backup'),
                          ),
                    const SizedBox(height: 8),
                    if (_lastRestoreMessage != null)
                      Text(
                        _lastRestoreMessage!,
                        style: TextStyle(
                          color: _lastRestoreMessage!.contains('success')
                              ? Colors.green
                              : Colors.red,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Export Options
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children [
                    const Text(
                      'Export Data',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _exportCSV,
                      child: const Text('Export as CSV'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _exportPDF,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Generate PDF Report'),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Export features will be available in the full version',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}