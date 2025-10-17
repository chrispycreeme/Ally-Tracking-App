import 'dart:async';

import 'package:flutter/material.dart';

import 'map_handlers/student_model.dart';
import 'map_handlers/map_service.dart';
import 'map_handlers/absence_reason_dialog.dart';
import 'map_handlers/history_service.dart';
import 'map_handlers/planned_absence_dialog.dart';
import 'map_handlers/attendance_service.dart';

// Ensure the AbsenceReasonDialog class is defined in the imported file or define it below if missing.
import 'login_service.dart';
import 'background_location_service.dart';
import 'ui_theme.dart';

class ProfilePage extends StatefulWidget {
  final Student student;
  final VoidCallback onLogout;
  final Function(Student) onProfileUpdated;
  final VoidCallback? onCleanupBeforeLogout;

  const ProfilePage({
    super.key,
    required this.student,
    required this.onLogout,
    required this.onProfileUpdated,
    this.onCleanupBeforeLogout,
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final LoginService _loginService = LoginService();
  final MapService _mapService = MapService(); // Initialize once
  final AttendanceService _attendanceService = AttendanceService();
  
  bool _isLoading = false;
  String _profileImageUrl = '';

  // Teacher attendance state
  AttendanceSummary? _realtimeSummary;
  AttendanceSummary? _todaySummary;
  bool _isLoadingRealtime = false;
  bool _isLoadingToday = false;
  DateTime? _lastAttendanceRefresh;
  
  // Enhanced color palette matching the main app
  static const Color _primaryColor = AllyTheme.primaryColor;
  static const Color _secondaryColor = AllyTheme.secondaryColor;
  static const Color _accentColor = AllyTheme.accentColor;
  static const Color _surfaceColor = AllyTheme.surfaceColor;
  static const Color _darkTextColor = AllyTheme.darkTextColor;
  static const Color _lightTextColor = AllyTheme.lightTextColor;
  static const Color _successColor = AllyTheme.successColor;
  static const Color _errorColor = AllyTheme.errorColor;
  static const Color _warningColor = AllyTheme.warningColor;

  @override
  void initState() {
    super.initState();
    _profileImageUrl = widget.student.profileImageUrl;
    if (widget.student.isTeacher) {
      // Kick off initial attendance loads
      Future.microtask(() async {
        await _refreshAttendance();
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      setState(() => _isLoading = true);
      
      // For now, just show a snackbar - we'll implement image picking later
      _showSnackBar('Image upload feature coming soon!', _accentColor);
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      _showSnackBar('Failed to update profile picture: $e', _errorColor);
    }
  }

  Future<void> _logout() async {
    try {
      setState(() => _isLoading = true);
      
      // Cleanup listeners first to prevent permission errors
      widget.onCleanupBeforeLogout?.call();
      
      // Add a small delay to ensure cleanup completes
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Sign out from Firebase
      await _loginService.signOut();
      
      // Reset loading state
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Call the logout callback which handles navigation
        widget.onLogout();
      }
    } catch (e) {
      print('Logout error: $e'); // Debug print
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('Failed to logout: $e', _errorColor);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted || !context.mounted) {
      print('⚠️ Cannot show snackbar: context not available');
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: color,
        ),
      );
    } catch (e) {
      print('❌ Failed to show snackbar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: _surfaceColor,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          _buildEnhancedBackground(),
          _buildScrollableContent(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((255 * 0.9).toInt()),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withAlpha((255 * 0.1).toInt()),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: _primaryColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((255 * 0.9).toInt()),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withAlpha((255 * 0.1).toInt()),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          'Profile',
          style: TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            color: _primaryColor,
            fontSize: 18,
          ),
        ),
      ),
      centerTitle: true,
    );
  }

  Widget _buildEnhancedBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withAlpha((255 * 0.08).toInt()),
            _surfaceColor,
            _secondaryColor.withAlpha((255 * 0.06).toInt()),
            _accentColor.withAlpha((255 * 0.04).toInt()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: const [0.0, 0.3, 0.7, 1.0],
        ),
      ),
    );
  }

  Widget _buildScrollableContent() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 20.0),
        child: Column(
          children: [
            SizedBox(height: isSmallScreen ? 12 : 20),

            // Teacher attendance section
            if (widget.student.isTeacher) _buildTeacherAttendanceSection(),
            if (widget.student.isTeacher) SizedBox(height: isSmallScreen ? 16 : 24),

            // Absence Reason Section - Only show if student is outside during class hours
            if (!widget.student.isTeacher && 
                widget.student.status == LocationStatus.outsideSchool &&
                widget.student.isDuringClassHours)
              _buildAbsenceStatusSection(),
            if (!widget.student.isTeacher && 
                widget.student.status == LocationStatus.outsideSchool &&
                widget.student.isDuringClassHours)
              SizedBox(height: isSmallScreen ? 16 : 24),

            // Planned Absence (students can submit for tomorrow or future date)
            if (!widget.student.isTeacher) _buildPlannedAbsenceSection(),
            if (!widget.student.isTeacher) SizedBox(height: isSmallScreen ? 16 : 24),
            
            // Profile Picture Section
            _buildEnhancedProfileSection(),
            SizedBox(height: isSmallScreen ? 16 : 24),
            
            // User Information Section
            _buildEnhancedUserInfoSection(),
            SizedBox(height: isSmallScreen ? 16 : 24),
            
            // Stats Section (if student)
            if (!widget.student.isTeacher) _buildStatsSection(),
            if (!widget.student.isTeacher) SizedBox(height: isSmallScreen ? 16 : 24),
            
            // Action Buttons Section
            _buildEnhancedActionButtonsSection(),
            SizedBox(height: isSmallScreen ? 24 : 40),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshAttendance() async {
    if (!widget.student.isTeacher) return;
    setState(() {
      _isLoadingRealtime = true;
      _isLoadingToday = true;
    });
    try {
      await Future.wait([
        _loadRealtime(),
        _loadToday(),
      ]);
      setState(() {
        _lastAttendanceRefresh = DateTime.now();
      });
    } catch (e) {
      _showSnackBar('Failed to refresh attendance: $e', _errorColor);
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingRealtime = false;
          _isLoadingToday = false;
        });
      }
    }
  }

  Future<void> _loadRealtime() async {
    try {
      final s = await _attendanceService.computeRealtimeForTeacher(
        widget.student.id,
        countOnlyDuringClassHours: true,
      );
      if (!mounted) return;
      setState(() => _realtimeSummary = s);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _loadToday() async {
    try {
      final s = await _attendanceService.computeDailyForTeacher(
        widget.student.id,
        date: DateTime.now(),
        requireMinimumMinutesInside: 0,
        requireOnlineForPresent: true,
      );
      if (!mounted) return;
      setState(() => _todaySummary = s);
    } catch (e) {
      rethrow;
    }
  }

  Widget _buildTeacherAttendanceSection() {
    final rt = _realtimeSummary;
    final td = _todaySummary;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.06).toInt()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _primaryColor.withAlpha((255 * 0.1).toInt()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.insights, color: _primaryColor),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Attendance Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: _isLoadingRealtime || _isLoadingToday ? null : _refreshAttendance,
                  icon: _isLoadingRealtime || _isLoadingToday
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _attendanceStatCard(
                    title: 'Realtime',
                    subtitle: _formatAsOf(rt?.asOf),
                    value: rt == null
                        ? '--%'
                        : '${rt.percentage.toStringAsFixed(0)}%',
          chip: rt == null
            ? '—'
            : '${rt.onlineCount} online • ${rt.presentCount}/${rt.eligibleCount} present',
                    color: _primaryColor,
                    onTap: rt == null ? null : () => _showAttendanceDetails(rt, 'Realtime Attendance'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _attendanceStatCard(
                    title: "Today's", 
                    subtitle: _formatAsOf(td?.asOf),
                    value: td == null
                        ? '--%'
                        : '${td.percentage.toStringAsFixed(0)}%',
          chip: td == null
            ? '—'
            : '${td.onlineCount} online • ${td.presentCount}/${td.eligibleCount} present',
                    color: _secondaryColor,
                    onTap: td == null ? null : () => _showAttendanceDetails(td, "Today's Attendance"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              "Today's rule: present requires being online during class hours",
              style: TextStyle(color: _lightTextColor, fontSize: 11),
            ),
            if (_lastAttendanceRefresh != null) ...[
              const SizedBox(height: 8),
              Text(
                'Last updated: ${_formatAsOf(_lastAttendanceRefresh)}',
                style: TextStyle(color: _lightTextColor, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _attendanceStatCard({
    required String title,
    required String? subtitle,
    required String value,
    required String chip,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha((255 * 0.06).toInt()),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withAlpha((255 * 0.25).toInt())),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: color.withAlpha((255 * 0.12).toInt()),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(chip, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(subtitle, style: const TextStyle(fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }

  String? _formatAsOf(DateTime? dt) {
    if (dt == null) return null;
    final d = dt;
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
  }

  void _showAttendanceDetails(AttendanceSummary summary, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Present: ${summary.presentCount}/${summary.eligibleCount} • Excused: ${summary.excusedCount} • Assigned: ${summary.totalAssigned}',
                  style: TextStyle(color: _lightTextColor),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: summary.details.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final d = summary.details[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          d.present
                              ? Icons.check_circle_rounded
                              : (d.excused ? Icons.info_rounded : Icons.cancel_rounded),
                          color: d.present ? _successColor : (d.excused ? _warningColor : _errorColor),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text('${d.studentId}  •  ${d.name}')),
                            if (d.online) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.circle, size: 10, color: _successColor),
                            ]
                          ],
                        ),
                        subtitle: Text(
                          d.counted
                              ? (d.present
                                  ? 'Present'
                                  : (d.excused ? 'Absent (Excused)' : 'Absent'))
                              : 'Not in class hours',
                        ),
                        trailing: d.presentDurationMinutes != null
                            ? Text('${d.presentDurationMinutes} min')
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showPlannedAbsenceDialog() {
    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PlannedAbsenceDialog(
        studentName: widget.student.name,
      ),
    ).then((result) async {
      if (result == null) return;
      final forDate = result['forDate'] as DateTime?;
      final reason = result['reason'] as String?;
      final startMap = result['forStartTime'] as Map<String, dynamic>?;
      final endMap = result['forEndTime'] as Map<String, dynamic>?;
      DateTime? startDateTime;
      DateTime? endDateTime;
      if (forDate != null && startMap != null && startMap.containsKey('hour') && startMap.containsKey('minute')) {
        startDateTime = DateTime(forDate.year, forDate.month, forDate.day, (startMap['hour'] as int), (startMap['minute'] as int));
      }
      if (forDate != null && endMap != null && endMap.containsKey('hour') && endMap.containsKey('minute')) {
        endDateTime = DateTime(forDate.year, forDate.month, forDate.day, (endMap['hour'] as int), (endMap['minute'] as int));
      }
      if (forDate == null || reason == null) return;
      await _handlePlannedAbsenceSubmission(forDate, reason, forStartTime: startDateTime, forEndTime: endDateTime);
    });
  }

  Widget _buildPlannedAbsenceSection() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: _primaryColor.withAlpha((255 * 0.15).toInt())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryColor.withAlpha((255 * 0.1).toInt()),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.event_busy, color: _primaryColor),
              ),
              const SizedBox(width: 12),
              const Text('Planned Absence', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Plan an absence for a future date with a reason.',
            style: TextStyle(color: _lightTextColor, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _showPlannedAbsenceDialog,
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Plan Absence'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handlePlannedAbsenceSubmission(DateTime forDate, String reason, {DateTime? forStartTime, DateTime? forEndTime}) async {
    try {
      if (reason.trim().isEmpty) throw Exception('Reason cannot be empty');
      if (widget.student.id.trim().isEmpty) throw Exception('Student ID is missing');
      setState(() => _isLoading = true);
      final now = DateTime.now();
      // For compatibility we still pass the date; also pass optional start/end datetimes
      await _mapService.addPlannedAbsence(
        widget.student.id,
        forDate,
        reason,
        now,
        forStartTime: forStartTime,
        forEndTime: forEndTime,
      );
      unawaited(reevaluateBackgroundTracking());
      // Log to history for visibility
      try {
        await HistoryService().addAbsenceReason(
          studentId: widget.student.id,
          timestamp: now,
          reason: 'Planned for ${forDate.year}-${forDate.month.toString().padLeft(2, '0')}-${forDate.day.toString().padLeft(2, '0')}${forStartTime != null ? ' ${forStartTime.hour.toString().padLeft(2, '0')}:${forStartTime.minute.toString().padLeft(2, '0')}' : ''}${forEndTime != null ? ' - ${forEndTime.hour.toString().padLeft(2, '0')}:${forEndTime.minute.toString().padLeft(2, '0')}' : ''}: $reason',
        );
      } catch (_) {}
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSnackBar('Planned absence submitted.', _successColor);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showSnackBar('Failed to submit planned absence: $e', _errorColor);
        });
      }
    }
  }

  Widget _buildEnhancedProfileSection() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 22 : 32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withAlpha((255 * 0.97).toInt()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withAlpha((255 * 0.12).toInt()),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).toInt()),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile Image with animated ring
          Stack(
            alignment: Alignment.center,
            children: [
              // Animated ring
              Container(
                width: isSmallScreen ? 116 : 144,
                height: isSmallScreen ? 116 : 144,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withAlpha((255 * 0.3).toInt()),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              // Profile image container
              Container(
                width: isSmallScreen ? 104 : 132,
                height: isSmallScreen ? 104 : 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.1).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: _isLoading
                      ? Container(
                          color: Colors.grey[100],
                          child: Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(_primaryColor),
                              strokeWidth: 3,
                            ),
                          ),
                        )
                      : Image.network(
                          _profileImageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            color: _surfaceColor,
                            child: Icon(
                              Icons.person,
                              size: isSmallScreen ? 48 : 64,
                              color: _lightTextColor,
                            ),
                          ),
                        ),
                ),
              ),
              // Camera button
              if (!_isLoading)
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: _pickAndUploadImage,
                    child: Container(
                      padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_primaryColor, _secondaryColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _primaryColor.withAlpha((255 * 0.5).toInt()),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: isSmallScreen ? 18 : 22,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 18 : 24),
          
          // Name and Role
          Text(
            widget.student.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 22 : 26,
              fontWeight: FontWeight.w800,
              color: _darkTextColor,
              fontFamily: 'Inter',
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isSmallScreen ? 8 : 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _primaryColor.withAlpha((255 * 0.12).toInt()),
                  _secondaryColor.withAlpha((255 * 0.12).toInt()),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _primaryColor.withAlpha((255 * 0.3).toInt()),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withAlpha((255 * 0.1).toInt()),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  widget.student.isTeacher ? Icons.school : Icons.person,
                  size: 18,
                  color: _primaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.student.isTeacher ? 'Teacher' : 'Student',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _primaryColor,
                    fontFamily: 'Inter',
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 10 : 14),
          Text(
            'Tap the camera icon to update your profile picture',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _lightTextColor,
              fontSize: 12,
              fontFamily: 'Inter',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedUserInfoSection() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 18 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            Colors.white.withAlpha((255 * 0.98).toInt()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withAlpha((255 * 0.08).toInt()),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.04).toInt()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_primaryColor, _secondaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withAlpha((255 * 0.3).toInt()),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_outline,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Account Information',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: _darkTextColor,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 16 : 24),
          _buildEnhancedInfoRow('Name', widget.student.name, Icons.badge),
          _buildEnhancedInfoRow('ID', widget.student.id, Icons.fingerprint),
          _buildEnhancedInfoRow(
            'Role', 
            widget.student.isTeacher ? 'Teacher' : 'Student', 
            widget.student.isTeacher ? Icons.school : Icons.person
          ),
          if (!widget.student.isTeacher) ...[
            _buildEnhancedInfoRow('Grade Level', widget.student.gradeLevel, Icons.grade),
            _buildEnhancedInfoRow('Class Hours', widget.student.classHours, Icons.schedule),
            _buildEnhancedInfoRow('Dismissal Time', widget.student.dismissalTime, Icons.logout),
          ],
        ],
      ),
    );
  }

  Widget _buildEnhancedInfoRow(String label, String value, IconData icon) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 20),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          color: _surfaceColor.withAlpha((255 * 0.3).toInt()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _primaryColor.withAlpha((255 * 0.1).toInt()),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
              decoration: BoxDecoration(
                color: _primaryColor.withAlpha((255 * 0.1).toInt()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: isSmallScreen ? 16 : 18,
                color: _primaryColor,
              ),
            ),
            SizedBox(width: isSmallScreen ? 12 : 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w500,
                      color: _lightTextColor,
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 3 : 4),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w700,
                      color: _darkTextColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour % 12}:${dateTime.minute.toString().padLeft(2, '0')} ${dateTime.hour < 12 ? 'AM' : 'PM'}';
  }

  Widget _buildAbsenceStatusSection() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    final hasReasonToday = widget.student.absenceReason != null && 
        widget.student.absenceReasonSubmittedAt != null &&
        _isSameDay(widget.student.absenceReasonSubmittedAt!, DateTime.now());
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _warningColor.withAlpha((255 * 0.1).toInt()),
            _warningColor.withAlpha((255 * 0.05).toInt()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _warningColor.withAlpha((255 * 0.3).toInt()),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _warningColor.withAlpha((255 * 0.1).toInt()),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                decoration: BoxDecoration(
                  color: _warningColor.withAlpha((255 * 0.2).toInt()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.location_off_outlined,
                  color: _warningColor,
                  size: isSmallScreen ? 22 : 28,
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Outside School Area',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: _warningColor,
                        fontFamily: 'Inter',
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    Text(
                      'During class hours',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
                        color: _lightTextColor,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 12, vertical: isSmallScreen ? 4 : 6),
                decoration: BoxDecoration(
                  color: _warningColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'ABSENT',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 10 : 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 16 : 20),
          
          // Current Status or Reason
          if (hasReasonToday) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.8).toInt()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _warningColor.withAlpha((255 * 0.2).toInt()),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today\'s Absence Reason:',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      fontWeight: FontWeight.w600,
                      color: _warningColor,
                      fontFamily: 'Inter',
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  Text(
                    widget.student.absenceReason!,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: _darkTextColor,
                      fontFamily: 'Inter',
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 6 : 8),
                  Text(
                    'Submitted: ${_formatDateTime(widget.student.absenceReasonSubmittedAt!)}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 12,
                      color: _lightTextColor,
                      fontFamily: 'Inter',
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            
            // Update button
            SizedBox(
              width: double.infinity,
              height: isSmallScreen ? 42 : 48,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _showAbsenceReasonDialog,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _warningColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(Icons.edit_outlined, color: _warningColor, size: isSmallScreen ? 16 : 18),
                label: Text(
                  'Update Reason',
                  style: TextStyle(
                    color: _warningColor,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                    fontSize: isSmallScreen ? 14 : 16,
                  ),
                ),
              ),
            ),
          ] else ...[
            // No reason provided yet
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.8).toInt()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _warningColor.withAlpha((255 * 0.2).toInt()),
                  width: 1,
                ),
              ),
              child: Text(
                'Please provide a reason for being absent during class hours.',
                style: TextStyle(
                  fontSize: 14,
                  color: _darkTextColor,
                  fontFamily: 'Inter',
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Provide reason button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _showAbsenceReasonDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _warningColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_comment_outlined, size: 18),
                label: Text(
                  'Provide Absence Reason',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showAbsenceReasonDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AbsenceReasonDialog(
        studentName: widget.student.name,
        onReasonSubmitted: _handleAbsenceReasonSubmission,
      ),
    );
  }

  Future<void> _handleAbsenceReasonSubmission(String reason) async {
    try {
      // Validate input
      if (reason.trim().isEmpty) {
        throw Exception('Absence reason cannot be empty');
      }
      
      if (widget.student.id.trim().isEmpty) {
        throw Exception('Student ID is missing');
      }
      
      setState(() => _isLoading = true);
      
      final now = DateTime.now();
      print('🔄 Starting absence reason submission for student: ${widget.student.id}');
      print('📝 Reason: $reason');
      
      // Update Firestore with the absence reason
      try {
        await _mapService.updateAbsenceReason(widget.student.id, reason, now);
        print('✅ Firestore update completed');
        // Also log to history (best-effort)
        try {
          await HistoryService().addAbsenceReason(
            studentId: widget.student.id,
            timestamp: now,
            reason: reason,
            location: widget.student.currentLocation,
          );
        } catch (e) {
          print('⚠️ Failed to log history for absence reason: $e');
        }
      } catch (e) {
        print('❌ Firestore update failed: $e');
        throw Exception('Failed to save absence reason: $e');
      }
      
      // Update the local student object and notify parent
      try {
        final updatedStudent = widget.student.copyWith(
          absenceReason: reason,
          absenceReasonSubmittedAt: now,
          recentActivity: 'Outside school: $reason',
        );
        print('✅ Student object updated locally');
        
        // Update parent state with additional safety check
        try {
          widget.onProfileUpdated(updatedStudent);
          print('✅ Parent state updated');
        } catch (e) {
          print('❌ Parent callback failed: $e');
          // Don't fail the whole operation if parent callback fails
          print('⚠️ Continuing despite parent callback failure...');
        }
      } catch (e) {
        print('❌ Local state update failed: $e');
        throw Exception('Failed to update local state: $e');
      }
      
      // Show success message with a delay to ensure dialog is closed and context is stable
      if (mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted && context.mounted) {
          try {
            _showSnackBar('Absence reason submitted successfully', _successColor);
            print('✅ Success message shown');
          } catch (e) {
            print('❌ Failed to show success message: $e');
            // Don't fail the operation if we can't show the message
          }
        }
      }
    } catch (e) {
      print('❌ Error submitting absence reason: $e');
      if (mounted && context.mounted) {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted && context.mounted) {
          try {
            _showSnackBar('Error submitting reason: ${e.toString()}', _errorColor);
          } catch (snackBarError) {
            print('❌ Failed to show error message: $snackBarError');
          }
        }
      }
      // Don't rethrow - let the dialog handle the error gracefully
    } finally {
      if (mounted) {
        try {
          setState(() => _isLoading = false);
          print('✅ Loading state reset');
        } catch (e) {
          print('❌ Failed to reset loading state: $e');
        }
      }
    }
  }

  Widget _buildStatsSection() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _accentColor.withAlpha((255 * 0.05).toInt()),
            _primaryColor.withAlpha((255 * 0.03).toInt()),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withAlpha((255 * 0.1).toInt()),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: _accentColor.withAlpha((255 * 0.2).toInt()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_accentColor, _primaryColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Quick Stats',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 20,
                  fontWeight: FontWeight.bold,
                  color: _darkTextColor,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Status',
                  widget.student.statusDisplay,
                  widget.student.status.toString().contains('inside') 
                      ? _successColor : Colors.orange,
                  Icons.location_on,
                ),
              ),
              SizedBox(width: isSmallScreen ? 12 : 16),
              Expanded(
                child: _buildStatCard(
                  'Last Update',
                  _formatLastUpdate(widget.student.lastUpdated),
                  _lightTextColor,
                  Icons.access_time,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((255 * 0.8).toInt()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withAlpha((255 * 0.2).toInt()),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 20 : 24,
            color: color,
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11 : 12,
              fontWeight: FontWeight.w500,
              color: _lightTextColor,
              fontFamily: 'Inter',
            ),
          ),
          SizedBox(height: isSmallScreen ? 3 : 4),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastUpdate(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Widget _buildEnhancedActionButtonsSection() {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.height < 700 || screenSize.width < 400;
    
    return Column(
      children: [
        // Logout Button
        Container(
          width: double.infinity,
          height: isSmallScreen ? 48 : 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: _errorColor.withAlpha((255 * 0.3).toInt()),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _logout,
            style: ElevatedButton.styleFrom(
              backgroundColor: _errorColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20 : 24, vertical: isSmallScreen ? 12 : 16),
            ),
            child: _isLoading
                ? SizedBox(
                    height: isSmallScreen ? 20 : 24,
                    width: isSmallScreen ? 20 : 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout, 
                        size: isSmallScreen ? 18 : 20,
                        color: Colors.white,
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 12),
                      Text(
                        'Logout',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: isSmallScreen ? 16 : 24),
        
        // App Version Info
        Container(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 20, vertical: isSmallScreen ? 10 : 12),
          decoration: BoxDecoration(
            color: _primaryColor.withAlpha((255 * 0.05).toInt()),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _primaryColor.withAlpha((255 * 0.1).toInt()),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: isSmallScreen ? 14 : 16,
                color: _primaryColor,
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Text(
                'Ally Tracking App v1.0.0',
                style: TextStyle(
                  fontSize: isSmallScreen ? 11 : 12,
                  fontWeight: FontWeight.w500,
                  color: _primaryColor,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}