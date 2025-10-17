import 'package:flutter/material.dart';

class PlannedAbsenceDialog extends StatefulWidget {
  final String studentName;

  const PlannedAbsenceDialog({
    super.key,
    required this.studentName,
  });

  @override
  State<PlannedAbsenceDialog> createState() => _PlannedAbsenceDialogState();
}

class _PlannedAbsenceDialogState extends State<PlannedAbsenceDialog> {
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _selectedStartTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _selectedEndTime = const TimeOfDay(hour: 12, minute: 0);
  String? _selectedReason;
  final TextEditingController _customReasonController = TextEditingController();
  bool _isSubmitting = false;

  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _darkTextColor = Color(0xFF1E293B);
  static const Color _lightTextColor = Color(0xFF64748B);
  static const Color _errorColor = Color(0xFFEF4444);

  final List<String> _predefinedReasons = const [
    'Absent - Excused',
    'Sick',
    'Medical Appointment',
    'Family Commitment',
    'School Activity (Off-campus)',
    'Other (specify below)',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _selectedDate.isAfter(now)
        ? _selectedDate
        : DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day).add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) async {
    return await showTimePicker(context: context, initialTime: initial);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason'), backgroundColor: _errorColor),
      );
      return;
    }
    // Validate time range
    final startMinutes = _selectedStartTime.hour * 60 + _selectedStartTime.minute;
    final endMinutes = _selectedEndTime.hour * 60 + _selectedEndTime.minute;
    if (endMinutes <= startMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time'), backgroundColor: _errorColor),
      );
      return;
    }
    String finalReason = _selectedReason!;
    if (_selectedReason == 'Other (specify below)') {
      if (_customReasonController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please specify your custom reason'), backgroundColor: _errorColor),
        );
        return;
      }
      finalReason = 'Other: ${_customReasonController.text.trim()}';
    }
    // Immediately close the dialog with result data; parent will perform async work.
    setState(() => _isSubmitting = true);
    if (mounted) {
      Navigator.of(context).pop({
        // Return date and start/end times so caller can store precise excused datetimes
        'forDate': DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day),
        'forStartTime': {'hour': _selectedStartTime.hour, 'minute': _selectedStartTime.minute},
        'forEndTime': {'hour': _selectedEndTime.hour, 'minute': _selectedEndTime.minute},
        'reason': finalReason,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 10,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // Keep dialog within viewport and allow scroll if needed
            maxHeight: size.height * 0.85,
            maxWidth: size.width * 0.95,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _primaryColor.withAlpha((255 * 0.1).toInt()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.event_busy, color: _primaryColor, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Plan an Absence', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _darkTextColor)),
                      const SizedBox(height: 4),
                      Text('Submit your reason ahead of time', style: TextStyle(fontSize: 14, color: _lightTextColor)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Date and time range picker
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
                BoxShadow(color: Colors.black.withAlpha((255 * 0.05).toInt()), blurRadius: 10, offset: const Offset(0, 2)),
              ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      TextButton.icon(onPressed: _isSubmitting ? null : _pickDate, icon: const Icon(Icons.edit_calendar), label: const Text('Change')),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () async {
                                      final picked = await _pickTime(_selectedStartTime);
                                      if (picked != null) setState(() => _selectedStartTime = picked);
                                    },
                              icon: const Icon(Icons.play_arrow, size: 18),
                              label: Text('From ${_selectedStartTime.format(context)}'),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isSubmitting
                                  ? null
                                  : () async {
                                      final picked = await _pickTime(_selectedEndTime);
                                      if (picked != null) setState(() => _selectedEndTime = picked);
                                    },
                              icon: const Icon(Icons.stop, size: 18),
                              label: Text('To ${_selectedEndTime.format(context)}'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Reasons
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
                BoxShadow(color: Colors.black.withAlpha((255 * 0.05).toInt()), blurRadius: 10, offset: const Offset(0, 2)),
              ]),
              child: Column(
                children: _predefinedReasons.map((r) => RadioListTile<String>(
                      title: Text(r, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _darkTextColor)),
                      value: r,
                      groupValue: _selectedReason,
                      activeColor: _primaryColor,
                      onChanged: _isSubmitting ? null : (v) => setState(() => _selectedReason = v),
                    )).toList(),
              ),
            ),

            if (_selectedReason == 'Other (specify below)') ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [
                  BoxShadow(color: Colors.black.withAlpha((255 * 0.05).toInt()), blurRadius: 10, offset: const Offset(0, 2)),
                ]),
                child: TextField(
                  controller: _customReasonController,
                  enabled: !_isSubmitting,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Please specify your reason...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ],

              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: TextStyle(color: _lightTextColor, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(backgroundColor: _primaryColor, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                      child: _isSubmitting
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
