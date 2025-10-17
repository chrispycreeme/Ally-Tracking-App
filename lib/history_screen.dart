import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import 'map_handlers/history_entry.dart';
import 'map_handlers/history_service.dart';
import 'map_handlers/student_model.dart';

class HistoryScreen extends StatefulWidget {
  final Student viewer; // the logged-in user (student or teacher)
  final List<Student>? teacherStudents; // when viewer is teacher

  const HistoryScreen({super.key, required this.viewer, this.teacherStudents});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with SingleTickerProviderStateMixin {
  final HistoryService _historyService = HistoryService();
  String? _selectedStudentId; // for teacher view
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Enhanced color palette matching the main app
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _secondaryColor = Color(0xFF8B5CF6);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    _animationController.forward();

    if (!widget.viewer.isTeacher) {
      _selectedStudentId = widget.viewer.id;
    } else {
      final students = widget.teacherStudents ?? [];
      if (students.isNotEmpty) {
        _selectedStudentId = students.first.id;
      } else {
        _selectedStudentId = null; // No students available yet
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = widget.viewer.isTeacher;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // _surfaceColor equivalent
  floatingActionButton: isTeacher ? _buildExportFab() : null,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(isTeacher),
          if (isTeacher) _buildStudentPickerSliver(),
          _buildHistoryListSliver(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isTeacher) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.transparent,
  // Removed small popup export here; replaced by a large floating button for visibility.
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_primaryColor, _secondaryColor],
          ),
        ),
        child: FlexibleSpaceBar(
          title: FadeTransition(
            opacity: _fadeAnimation,
            child: Text(
              isTeacher ? 'Class Activity' : 'Activity History',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ),
          centerTitle: true,
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildExportFab() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        onPressed: _openExportSheet,
        backgroundColor: _primaryColor,
        elevation: 0,
        icon: const Icon(Icons.download_rounded, size: 22),
        label: const Text(
          "Export History",
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.3),
        ),
      ),
    );
  }

  void _openExportSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) {
        final hasSelected = _selectedStudentId != null && _selectedStudentId!.isNotEmpty;
        final total = (widget.teacherStudents ?? []).length;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.download_rounded, color: _primaryColor),
                    SizedBox(width: 12),
                    Text(
                      'Export Today\'s Activity',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  DateFormat('MMMM d, yyyy').format(DateTime.now()),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    decoration: BoxDecoration(
                      color: _primaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.person, color: _primaryColor),
                  ),
                  title: const Text("Selected Student", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    hasSelected ? 'Exports only the chosen student\'s logs for today' : 'Select a student first',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  enabled: hasSelected,
                  onTap: hasSelected
                      ? () {
                          Navigator.pop(ctx);
                          _exportTodayForSelected();
                        }
                      : null,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    decoration: BoxDecoration(
                      color: _secondaryColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(10),
                    child: const Icon(Icons.people_alt_rounded, color: _secondaryColor),
                  ),
                  title: const Text("All Students", style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    total > 0 ? 'Exports today\'s logs for $total students' : 'No students loaded',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  enabled: total > 0,
                  onTap: total > 0
                      ? () {
                          Navigator.pop(ctx);
                          _exportTodayForAll();
                        }
                      : null,
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                ),
                const SizedBox(height: 24),
                Text(
                  'CSV columns: studentId, timestamp (ISO), type, status, message, placeName, latitude, longitude',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _exportTodayForSelected() async {
    final studentId = _selectedStudentId;
    if (studentId == null) return;
    try {
      final entries = await _historyService.fetchTodayHistory(studentId);
      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No activity for today to export')));
        }
        return;
      }
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('studentId,timestamp,type,status,message,placeName,latitude,longitude');
      for (final e in entries) {
        final tsIso = e.timestamp.toIso8601String();
        final lat = e.location?.latitude.toStringAsFixed(6) ?? '';
        final lng = e.location?.longitude.toStringAsFixed(6) ?? '';
        final safe = (String? s) => s?.replaceAll(',', ' ').replaceAll('\n', ' ').trim() ?? '';
        csvBuffer.writeln([
          safe(e.studentId),
          tsIso,
          safe(e.type),
            safe(e.status),
          '"${safe(e.message)}"',
          safe(e.placeName),
          lat,
          lng,
        ].join(','));
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'activity_${studentId}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvBuffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: 'Today\'s activity for student $studentId');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _exportTodayForAll() async {
    final students = widget.teacherStudents ?? [];
    if (students.isEmpty) return;
    try {
      final ids = students.map((s) => s.id).toList();
      final entries = await _historyService.fetchTodayHistoryForStudents(ids);
      if (entries.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No activity for today to export')));
        }
        return;
      }
      final csvBuffer = StringBuffer();
      csvBuffer.writeln('studentId,timestamp,type,status,message,placeName,latitude,longitude');
      for (final e in entries) {
        final tsIso = e.timestamp.toIso8601String();
        final lat = e.location?.latitude.toStringAsFixed(6) ?? '';
        final lng = e.location?.longitude.toStringAsFixed(6) ?? '';
        final safe = (String? s) => s?.replaceAll(',', ' ').replaceAll('\n', ' ').trim() ?? '';
        csvBuffer.writeln([
          safe(e.studentId),
          tsIso,
          safe(e.type),
          safe(e.status),
          '"${safe(e.message)}"',
          safe(e.placeName),
          lat,
          lng,
        ].join(','));
      }
      final dir = await getTemporaryDirectory();
      final fileName = 'activity_all_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(csvBuffer.toString());
      await Share.shareXFiles([XFile(file.path)], text: "Today's activity for all students");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Widget _buildStudentPickerSliver() {
    final students = widget.teacherStudents ?? [];
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
              spreadRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      FontAwesomeIcons.users,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Select Student',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
  Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: DropdownButtonFormField<String>(
          value: (widget.teacherStudents ?? []).any((s) => s.id == _selectedStudentId)
            ? _selectedStudentId
            : (widget.teacherStudents?.isNotEmpty == true
              ? widget.teacherStudents!.first.id
              : null),
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    hintText: 'Choose a student',
                    hintStyle: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  selectedItemBuilder: (context) => students
                      .map((s) => Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: _primaryColor.withOpacity(0.15),
                                child: Text(
                                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '${s.name}  •  ${s.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                  items: students
                      .map((s) => DropdownMenuItem(
                            value: s.id,
                            child: ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 16,
                                backgroundColor: _primaryColor.withOpacity(0.1),
                                child: Text(
                                  s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                  style: TextStyle(
                                    color: _primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              title: Text(
                                s.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                'ID: ${s.id}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStudentId = val),
                ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryListSliver() {
  if (_selectedStudentId == null || _selectedStudentId!.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.userSlash,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                'No student selected',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please select a student to view their activity history',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<HistoryEntry>>(
      stream: _historyService.streamStudentHistory(_selectedStudentId!),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading activity history...',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final items = snap.data ?? [];
  if (items.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    FontAwesomeIcons.clockRotateLeft,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No activity yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Activity history will appear here once there\'s some data',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // Group items by date
        final groupedItems = _groupItemsByDate(items);

        return SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dateKey = groupedItems.keys.elementAt(index);
                final dayItems = groupedItems[dateKey]!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDateHeader(dateKey),
                    const SizedBox(height: 12),
                    ...dayItems.asMap().entries.map((entry) {
                      final itemIndex = entry.key;
                      final item = entry.value;
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 200 + (itemIndex * 50)),
                        curve: Curves.easeOutCubic,
                        child: _buildHistoryCard(item, itemIndex),
                      );
                    }).toList(),
                    if (index < groupedItems.length - 1) const SizedBox(height: 24),
                  ],
                );
              },
              childCount: groupedItems.length,
            ),
          ),
        );
      },
    );
  }

  Map<String, List<HistoryEntry>> _groupItemsByDate(List<HistoryEntry> items) {
    final Map<String, List<HistoryEntry>> grouped = {};
    late DateFormat dateFormat;
    try {
      dateFormat = DateFormat('MMMM d, yyyy', 'en_US');
    } catch (_) {
      // Fallback to numeric format if Intl symbols aren't ready
      dateFormat = DateFormat('yyyy-MM-dd');
    }

    for (final item in items) {
      String dateKey;
      try {
        dateKey = dateFormat.format(item.timestamp);
      } catch (_) {
        final d = item.timestamp;
        dateKey = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      }
      grouped.putIfAbsent(dateKey, () => []);
      grouped[dateKey]!.add(item);
    }

    return grouped;
  }

  Widget _buildDateHeader(String date) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _primaryColor.withOpacity(0.12),
            _secondaryColor.withOpacity(0.12),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _primaryColor.withOpacity(0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            size: 16,
            color: _primaryColor,
          ),
          const SizedBox(width: 8),
          Text(
            date,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(HistoryEntry entry, int index) {
    final isStatusChange = entry.type == 'status_change';
    final isAbsenceReason = entry.type == 'absence_reason';
    
    Color cardColor = Colors.white;
    Color accentColor = _primaryColor;
    IconData iconData = Icons.info_outline;
    
    if (isStatusChange) {
      if (entry.status?.toLowerCase().contains('inside') == true) {
        accentColor = _successColor;
        iconData = FontAwesomeIcons.schoolFlag;
      } else if (entry.status?.toLowerCase().contains('outside') == true) {
        accentColor = _warningColor;
        iconData = FontAwesomeIcons.locationCrosshairs;
      } else {
        iconData = FontAwesomeIcons.route;
      }
    } else if (isAbsenceReason) {
      accentColor = Colors.orange;
      iconData = FontAwesomeIcons.noteSticky;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 14, left: index.isEven ? 0 : 8, right: index.isOdd ? 0 : 8),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: accentColor.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accentColor, accentColor.withOpacity(0.7)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                  bottomLeft: Radius.circular(18),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            accentColor.withOpacity(0.12),
                            accentColor.withOpacity(0.08),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accentColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        iconData,
                        size: 22,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.message,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B),
                              letterSpacing: 0.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatEntrySubtitle(entry),
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 56,
                      child: Builder(builder: (_) {
                        String timeText;
                        try {
                          timeText = DateFormat('HH:mm').format(entry.timestamp);
                        } catch (_) {
                          final t = entry.timestamp;
                          timeText = '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                        }
                        return Text(
                          timeText,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500,
                          ),
                        );
                      }),
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

  String _formatEntrySubtitle(HistoryEntry entry) {
    final List<String> parts = [];
    
    if (entry.status != null && entry.status!.isNotEmpty) {
      parts.add(entry.status!);
    }
    
    if (entry.placeName != null && entry.placeName!.isNotEmpty) {
      parts.add('📍 ${entry.placeName!}');
    }
    
    if (entry.location != null) {
      parts.add('${entry.location!.latitude.toStringAsFixed(3)}, ${entry.location!.longitude.toStringAsFixed(3)}');
    }
    
    return parts.isEmpty ? 'No additional details' : parts.join(' • ');
  }

}
