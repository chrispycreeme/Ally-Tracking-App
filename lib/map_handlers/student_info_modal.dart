// lib/student_info_modal.dart
import 'dart:ui'; // Required for BackdropFilter

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'student_model.dart'; // Student data model

class StudentInfoModal extends StatelessWidget {
  final Student student;
  final LatLng? userCurrentLocation;
  final String? currentPlaceName;
  final VoidCallback onClose;

  const StudentInfoModal({
    super.key,
    required this.student,
    required this.userCurrentLocation,
    required this.currentPlaceName,
    required this.onClose,
  });

  // Enhanced color palette for consistent UI theming
  static const Color _primaryColor = Color(0xFF6366F1); // Primary brand color (Indigo 500)
  static const Color _secondaryColor = Color(0xFF8B5CF6); // Secondary accent color (Violet 500)
  static const Color _accentColor = Color(0xFF06B6D4); // Tertiary accent color (Cyan 500)
  static const Color _surfaceColor = Color(0xFFF8FAFC); // Light surface background (Slate 50)
  static const Color _darkTextColor = Color(0xFF1E293B); // Dark text color (Slate 900)
  static const Color _lightTextColor = Color(0xFF64748B); // Lighter text color (Slate 500)
  static const Color _successColor = Color(0xFF10B981); // Green for success states (Emerald 500)
  static const Color _warningColor = Color(0xFFF59E0B); // Orange for warning states (Amber 500)

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: 1.0, // This widget is only built if modal is visible, so opacity is always 1
      duration: const Duration(milliseconds: 300),
      child: _buildDraggableSheet(context),
    );
  }

  /// Builds the draggable scrollable sheet for the modal content.
  Widget _buildDraggableSheet(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5, // Starts at 50% height
      minChildSize: 0.2, // Can be dragged down to 20%
      maxChildSize: 0.8, // Can be dragged up to 80%
      builder: (BuildContext context, ScrollController scrollController) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((255 * 0.1).toInt()), // Using withAlpha
                blurRadius: 30,
                offset: const Offset(0, -10),
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20.0, sigmaY: 20.0), // Blur effect
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((255 * 0.9).toInt()), // Using withAlpha
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: Colors.white.withAlpha((255 * 0.2).toInt()), // Using withAlpha
                    width: 1,
                  ),
                ),
                child: ListView(
                  controller: scrollController, // Connects to DraggableScrollableSheet
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  children: [
                    GestureDetector( // Added GestureDetector to close modal
                      onTap: onClose,
                      child: Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: _lightTextColor.withAlpha((255 * 0.3).toInt()), // Using withAlpha
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                    _buildSheetContent(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSheetContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("Current Location", Icons.location_on),
        const SizedBox(height: 12),
        _buildLocationCard(),
        const SizedBox(height: 32),
        _buildSectionHeader("Student Information", Icons.person),
        const SizedBox(height: 12),
        _buildStudentInfoGrid(),
        const SizedBox(height: 32),
        _buildSectionHeader("Recent Activity", Icons.history),
        const SizedBox(height: 12),
        _buildActivityTimeline(),
      ],
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withAlpha((255 * 0.1).toInt()), // Using withAlpha
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: _primaryColor, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: _darkTextColor,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((255 * 0.8).toInt()), // Using withAlpha
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withAlpha((255 * 0.5).toInt()), // Using withAlpha
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).toInt()), // Using withAlpha
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: _primaryColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  currentPlaceName ?? "Resolving location...", // Use currentPlaceName from props
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: _darkTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            userCurrentLocation != null
                ? "Lat: ${userCurrentLocation!.latitude.toStringAsFixed(4)}, Lon: ${userCurrentLocation!.longitude.toStringAsFixed(4)}"
                : "Fetching your location...",
            style: TextStyle(
              fontSize: 14,
              color: _lightTextColor,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentInfoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildInfoCard(FontAwesomeIcons.clock, "Class Hours", student.classHours)),
            const SizedBox(width: 12),
            Expanded(child: _buildInfoCard(FontAwesomeIcons.hourglassEnd, "Dismissal", student.dismissalTime)),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((255 * 0.8).toInt()), // Using withAlpha
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withAlpha((255 * 0.5).toInt()), // Using withAlpha
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((255 * 0.05).toInt()), // Using withAlpha
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _primaryColor, size: 20),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: _lightTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _darkTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityTimeline() {
    return Column(
      children: [
        _buildTimelineItem(
          icon: Icons.access_time_filled,
          time: "10:00 AM",
          title: "Class Started",
          description: "Regular class hours began",
          isActive: false,
        ),
        _buildTimelineItem(
          icon: Icons.location_on,
          time: "${student.lastUpdated.hour % 12}:${student.lastUpdated.minute.toString().padLeft(2, '0')} ${student.lastUpdated.hour < 12 ? 'AM' : 'PM'}",
          title: "Location Update",
          description: student.recentActivity,
          isActive: true,
        ),
      ],
    );
  }

  Widget _buildTimelineItem({
    required IconData icon,
    required String time,
    required String title,
    required String description,
    required bool isActive,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive ? _primaryColor : _lightTextColor.withAlpha((255 * 0.2).toInt()), // Using withAlpha
                  boxShadow: isActive ? [
                    BoxShadow(
                      color: _primaryColor.withAlpha((255 * 0.3).toInt()), // Using withAlpha
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ] : null,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : _lightTextColor,
                  size: 20,
                ),
              ),
              if (isActive)
                Container(
                  width: 2,
                  height: 20,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: _lightTextColor.withAlpha((255 * 0.2).toInt()), // Using withAlpha
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.8).toInt()), // Using withAlpha
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive ? _primaryColor.withAlpha((255 * 0.2).toInt()) : Colors.white.withAlpha((255 * 0.5).toInt()), // Using withAlpha
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.05).toInt()), // Using withAlpha
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        time,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isActive ? _primaryColor : _lightTextColor,
                        ),
                      ),
                      const Spacer(),
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _successColor.withAlpha((255 * 0.1).toInt()), // Using withAlpha
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "LIVE",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _successColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _darkTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: _lightTextColor,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
