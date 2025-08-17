import 'package:flutter/material.dart';

class AbsenceReasonDialog extends StatefulWidget {
  final String studentName;
  final Future<void> Function(String reason) onReasonSubmitted;

  const AbsenceReasonDialog({
    super.key,
    required this.studentName,
    required this.onReasonSubmitted,
  });

  @override
  State<AbsenceReasonDialog> createState() => _AbsenceReasonDialogState();
}

class _AbsenceReasonDialogState extends State<AbsenceReasonDialog> {
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isSubmitting = false;

  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _darkTextColor = Color(0xFF1E293B);
  static const Color _lightTextColor = Color(0xFF64748B);
  static const Color _errorColor = Color(0xFFEF4444);

  final List<String> _predefinedReasons = [
    'Absent - Unexcused',
    'Absent - Excused',
    'Sick',
    'Medical Appointment',
    'Family Emergency',
    'School Activity (Off-campus)',
    'Other (specify below)',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  void _submitReason() async {
    print('🔄 Submit reason called - mounted: $mounted, isSubmitting: $_isSubmitting');
    
    // Prevent multiple submissions
    if (_isSubmitting) {
      print('⚠️ Already submitting, ignoring duplicate request');
      return;
    }
    
    if (_selectedReason == null) {
      print('❌ No reason selected');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a reason'),
            backgroundColor: _errorColor,
          ),
        );
      }
      return;
    }

    String finalReason = _selectedReason!;
    if (_selectedReason == 'Other (specify below)') {
      if (_customReasonController.text.trim().isEmpty) {
        print('❌ Custom reason is empty');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please specify your custom reason'),
              backgroundColor: _errorColor,
            ),
          );
        }
        return;
      }
      finalReason = 'Other: ${_customReasonController.text.trim()}';
    }

    if (!mounted) {
      print('❌ Widget not mounted, aborting');
      return;
    }

    print('📤 Submitting reason: $finalReason');

    setState(() {
      _isSubmitting = true;
    });

    try {
      print('🔄 Calling onReasonSubmitted...');
      await widget.onReasonSubmitted(finalReason);
      print('✅ onReasonSubmitted completed successfully');
      
      // Add a small delay before closing to ensure all operations complete
      await Future.delayed(const Duration(milliseconds: 200));
      
      if (mounted && Navigator.canPop(context)) {
        print('📱 Closing dialog...');
        try {
          Navigator.of(context).pop();
          print('✅ Dialog closed');
        } catch (e) {
          print('❌ Error closing dialog: $e');
          // If normal pop fails, try using the navigator directly
          if (mounted && Navigator.canPop(context)) {
            Navigator.of(context, rootNavigator: true).pop();
          }
        }
      } else {
        print('⚠️ Widget unmounted or cannot pop, trying alternative close method');
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pop();
        }
      }
    } catch (e, stackTrace) {
      print('❌ Error in _submitReason: $e');
      print('📍 Stack trace: $stackTrace');
      
      setState(() {
        _isSubmitting = false;
      });
      
      if (!mounted) {
        print('⚠️ Widget unmounted, cannot show error message');
        return;
      }
      
      // Show user-friendly error message
      String errorMessage = 'Failed to submit absence reason.';
      if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
        errorMessage = 'Permission denied. Please try logging out and back in.';
      } else if (e.toString().contains('network') || e.toString().contains('connection') || e.toString().contains('UNAVAILABLE')) {
        errorMessage = 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('Student ID is missing') || e.toString().contains('Student ID cannot be empty')) {
        errorMessage = 'User session error. Please restart the app.';
      }
      
      try {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: _errorColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } catch (snackBarError) {
        print('❌ Failed to show error snackbar: $snackBarError');
      }
      // Don't close dialog on error - let user try again
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 10,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _surfaceColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primaryColor.withAlpha((255 * 0.1).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_off_outlined,
                    color: _primaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Outside School Area',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _darkTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Please provide a reason for being away during class hours',
                        style: TextStyle(
                          fontSize: 14,
                          color: _lightTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Reasons List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.05).toInt()),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: _predefinedReasons.map((reason) {
                  return RadioListTile<String>(
                    title: Text(
                      reason,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _darkTextColor,
                      ),
                    ),
                    value: reason,
                    groupValue: _selectedReason,
                    activeColor: _primaryColor,
                    onChanged: _isSubmitting ? null : (value) {
                      setState(() {
                        _selectedReason = value;
                      });
                    },
                  );
                }).toList(),
              ),
            ),
            
            // Custom reason input
            if (_selectedReason == 'Other (specify below)') ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.05).toInt()),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _customReasonController,
                  enabled: !_isSubmitting,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Please specify your reason...',
                    hintStyle: TextStyle(color: _lightTextColor),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  style: TextStyle(color: _darkTextColor),
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _isSubmitting ? null : () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        color: _lightTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitReason,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Submit',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}