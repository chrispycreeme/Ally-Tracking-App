import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart'; // For location services
import 'package:geocoding/geocoding.dart'; // Import for geocoding

import 'map_handlers/map_service.dart'; // Service to fetch map data
import 'map_handlers/student_model.dart'; // Student data model
import 'map_handlers/student_info_modal.dart'; // New import for the separated modal widget
import 'map_handlers/absence_reason_dialog.dart'; // Import for absence reason dialog
import 'notification_service.dart';
import 'map_handlers/teacher_assignment_service.dart';
import 'profile_page.dart'; // Import for profile page
import 'main.dart'; // Import main.dart to access LoginScreen

/// Main StatefulWidget for the map screen.
class FixedMapScreen extends StatefulWidget {
  final Student student; // Accepts a Student object
  const FixedMapScreen({super.key, required this.student, required String studentLrn});

  @override
  State<FixedMapScreen> createState() => _FixedMapScreenState();
}

/// State class for FixedMapScreen, handling map logic, location, and animations.
class _FixedMapScreenState extends State<FixedMapScreen>
    with TickerProviderStateMixin<FixedMapScreen> {
  // Service and controller instances
  final MapService _mapService = MapService();
  final MapController _mapController = MapController();
  final TeacherAssignmentService _assignmentService = TeacherAssignmentService();

  // Student data for the logged-in user
  late Student _student;

  // School boundary coordinates and real-world radii
  static const LatLng _schoolCoordinates = LatLng(14.838537, 120.313376);
  static const double _insideSchoolRadiusMeters = 100; // meters
  // Additional radius outside the school within which a student's marker remains visible.
  // Once a student goes beyond insideSchoolRadius + _privacyExtraVisibleRadiusMeters,
  // their marker will be hidden from the map for privacy.
  static const double _privacyExtraVisibleRadiusMeters = 300; // meters beyond school radius

  // Instance of SchoolBoundary to check location status
  late final SchoolBoundary _schoolBoundary;
  // Distance calculator for privacy filtering
  final Distance _distance = const Distance();

  // State variables for map data and UI
  List<Polygon> _buildingPolygons = [];
  bool _isLoading = true;
  bool _isMapReady = false;
  bool _isModalVisible = false;
  // Bottom sheet state for teacher student list filtering
  String _lrnFilterQuery = '';
  final TextEditingController _lrnFilterController = TextEditingController();

  // State to hold the currently selected student for the modal and top card
  late Student _selectedStudent;

  String? _currentPlaceName;

  // Stream subscription to listen for real-time location updates
  StreamSubscription<Position>? _positionStreamSubscription;

  // State for holding other students' data
  List<Student> _otherStudents = [];
  StreamSubscription? _studentsStreamSubscription;
  // Assignment stream (teacher only)
  List<String> _assignedStudentIds = [];
  StreamSubscription<List<String>>? _assignedIdsSub;

  // Absence reason tracking
  bool _hasAskedForReasonToday = false;


  // Animation Controllers and Animations
  late AnimationController _markerAnimationController;
  late Animation<double> _markerAnimation;
  late AnimationController _backgroundAnimationController;
  late Animation<AlignmentGeometry> _backgroundAlignmentAnimation;
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  late AnimationController _slideAnimationController;
  late Animation<Offset> _slideAnimation;

  // Enhanced color palette
  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _secondaryColor = Color(0xFF8B5CF6);
  static const Color _accentColor = Color(0xFF06B6D4);
  static const Color _surfaceColor = Color(0xFFF8FAFC);
  static const Color _darkTextColor = Color(0xFF1E293B);
  static const Color _lightTextColor = Color(0xFF64748B);
  static const Color _successColor = Color(0xFF10B981);
  static const Color _warningColor = Color(0xFFF59E0B);
  static const Color _errorColor = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    // Initialize student with data passed from the login screen
    _student = widget.student;
    _selectedStudent = _student; // Initially, the selected student is the user

    // Initialize the SchoolBoundary
    _schoolBoundary = SchoolBoundary(
      schoolCenter: _schoolCoordinates,
      insideSchoolRadius: _insideSchoolRadiusMeters,
    );

    _initializeAnimations();

    if (_student.isTeacher) {
      // Teachers are not monitored: no location stream; center map on school
      _student = _student.copyWith(
        currentLocation: _schoolCoordinates,
        recentActivity: 'Monitoring students.',
        status: LocationStatus.unknown,
      );
      _selectedStudent = _student;
      _subscribeToStudentsStream();
      _subscribeToTeacherAssignments();
      // Finish loading immediately for teacher view
      _isLoading = false;
    } else {
      _fetchLocationAndData();
    }
  }

  void _subscribeToTeacherAssignments() {
    _assignedIdsSub?.cancel();
    _assignedIdsSub = _assignmentService
        .getAssignedStudentIdsStream(_student.id)
        .listen(
          (ids) {
            if (!mounted) return;
            setState(() {
              _assignedStudentIds = ids;
            });
          },
          onError: (error) {
            print('❌ Error in teacher assignments stream: $error');
            // Don't show error to user during logout as this is expected
            if (mounted && error.toString().contains('PERMISSION_DENIED')) {
              print('🔄 Permission denied on teacher assignments stream, likely due to logout');
            }
          },
        );
  }

  Future<void> _checkAndPromptForAbsenceReason(LocationStatus currentStatus) async {
    // Only check for students (not teachers)
    if (_student.isTeacher) return;
    
    // Only prompt if student is outside school during class hours
    if (currentStatus != LocationStatus.outsideSchool) {
      // Reset the flag when student is back inside school
      _hasAskedForReasonToday = false;
      return;
    }
    
    // Check if student is during class hours
    if (!_student.isDuringClassHours) return;
    
    // Don't ask again if we already asked today
    if (_hasAskedForReasonToday) return;
    
    // Don't ask if student already provided a reason today
    if (_student.absenceReason != null && _student.absenceReasonSubmittedAt != null) {
      final today = DateTime.now();
      final submissionDate = _student.absenceReasonSubmittedAt!;
      if (submissionDate.day == today.day &&
          submissionDate.month == today.month &&
          submissionDate.year == today.year) {
        _hasAskedForReasonToday = true;
        return;
      }
    }
    
    // Mark that we've asked today to prevent repeated prompts
    _hasAskedForReasonToday = true;
    
    // Show the absence reason dialog
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent dismissing by tapping outside
        builder: (context) => AbsenceReasonDialog(
          studentName: _student.name,
          onReasonSubmitted: _handleAbsenceReasonSubmission,
        ),
      );
    }
  }

  Future<void> _handleAbsenceReasonSubmission(String reason) async {
    try {
      final now = DateTime.now();
      
      // Update the local student object
      setState(() {
        _student = _student.copyWith(
          absenceReason: reason,
          absenceReasonSubmittedAt: now,
          recentActivity: 'Outside school: $reason',
        );
        
        // Update selected student if it's the same
        if (_selectedStudent.id == _student.id) {
          _selectedStudent = _student;
        }
      });
      
      // Update Firestore with the absence reason
      await _mapService.updateAbsenceReason(_student.id, reason, now);
      
      // Show confirmation message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Absence reason submitted successfully'),
            backgroundColor: _successColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ Error submitting absence reason: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting reason: $e'),
            backgroundColor: _errorColor,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Subscribes to the stream of all students from MapService.
  void _subscribeToStudentsStream() {
    _studentsStreamSubscription = _mapService.getStudentsStream().listen(
      (allStudents) {
        if (mounted) {
          setState(() {
            // Update the logged-in student's data if it exists in the stream
            final updatedSelf = allStudents.where((s) => s.id == _student.id);
            if (updatedSelf.isNotEmpty){
              // This keeps the location stream as the primary source of truth for the user's device
              // but updates other info from Firestore
              _student = _student.copyWith(
                name: updatedSelf.first.name,
                gradeLevel: updatedSelf.first.gradeLevel,
                profileImageUrl: updatedSelf.first.profileImageUrl,
                role: updatedSelf.first.role,
              );
            }

            // Only teachers maintain the list of other students
            if (_student.isTeacher) {
              // Filter by assignment list if present; if no assignments stored yet, show none until teacher adds.
              final rawOthers = allStudents.where((s) => s.id != _student.id).toList();
              if (_assignedStudentIds.isEmpty) {
                _otherStudents = [];
              } else {
                _otherStudents = rawOthers
                    .where((s) => _assignedStudentIds.contains(s.id))
                    .toList();
              }
            }
          });
        }
      },
      onError: (error) {
        print('❌ Error in students stream: $error');
        // Don't show error to user during logout as this is expected
        if (mounted && error.toString().contains('PERMISSION_DENIED')) {
          print('🔄 Permission denied on students stream, likely due to logout');
        }
      },
    );
  }


  /// Initializes all animation controllers and their respective animations.
  void _initializeAnimations() {
    _markerAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _markerAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _markerAnimationController,
        curve: Curves.easeInOutSine,
      ),
    );

    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _backgroundAlignmentAnimation = TweenSequence<AlignmentGeometry>([
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topLeft, end: Alignment.bottomRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomRight, end: Alignment.topRight),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.topRight, end: Alignment.bottomLeft),
        weight: 1,
      ),
      TweenSequenceItem(
        tween: Tween(begin: Alignment.bottomLeft, end: Alignment.topLeft),
        weight: 1,
      ),
    ]).animate(_backgroundAnimationController);

    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, -1),
          end: Offset.zero,
        ).animate(
          CurvedAnimation(
            parent: _slideAnimationController,
            curve: Curves.elasticOut,
          ),
        );

    _slideAnimationController.forward();
  }

  /// Fetches the user's current location and sets up a real-time listener.
  Future<void> _fetchLocationAndData() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions denied');
      }

      Position initialPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 30),
        ),
      );

      if (mounted) {
        final initialLocation = LatLng(
          initialPosition.latitude,
          initialPosition.longitude,
        );
        final initialStatus = _schoolBoundary.checkLocationStatus(initialLocation);
        String activityMessage = initialStatus == LocationStatus.insideSchool
            ? "Student is currently inside school."
            : "Student is currently outside school.";

        setState(() {
          _student = _student.copyWith(
            currentLocation: initialLocation,
            status: initialStatus,
            recentActivity: activityMessage,
            lastUpdated: DateTime.now(),
          );
          _selectedStudent = _student; // Ensure selected student is updated
        });

        // Update Firestore with initial location data
        await _mapService.updateStudentLocation(
          _student.id,
          _student.currentLocation,
          _student.status,
          _student.recentActivity,
          _student.lastUpdated,
        );

        // Show initial status notification
        await NotificationService().showGeofenceNotification(
          entered: initialStatus == LocationStatus.insideSchool,
          studentName: _student.name,
        );

        // Check if we need to ask for absence reason on initial load
        await _checkAndPromptForAbsenceReason(initialStatus);

        await _reverseGeocodeLocation(initialLocation);
      }

      _positionStreamSubscription?.cancel();
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 1, // Update every 1 meter change
            ),
          ).listen(
            (Position position) async { // Make the listener async
              if (mounted) {
                final newLocation = LatLng(position.latitude, position.longitude);
                final newStatus = _schoolBoundary.checkLocationStatus(newLocation);
                final bool statusHasChanged = _student.status != newStatus;
                String newActivity = _student.recentActivity;
                if (statusHasChanged) {
                  newActivity = newStatus == LocationStatus.insideSchool
                      ? "Student is currently inside school."
                      : "Student is currently outside school.";
                }

                setState(() {
                  _student = _student.copyWith(
                    currentLocation: newLocation,
                    lastUpdated: DateTime.now(),
                    status: newStatus,
                    recentActivity: newActivity,
                  );
                  // If the currently selected student is the user, update their info
                  if (_selectedStudent.id == _student.id) {
                    _selectedStudent = _student;
                  }
                });

                // Check if we need to ask for absence reason
                await _checkAndPromptForAbsenceReason(newStatus);

                // Update Firestore with new location data
                await _mapService.updateStudentLocation(
                  _student.id,
                  _student.currentLocation,
                  _student.status,
                  _student.recentActivity,
                  _student.lastUpdated,
                );

                // Trigger notification on status change
                if (statusHasChanged) {
                  await NotificationService().showGeofenceNotification(
                    entered: newStatus == LocationStatus.insideSchool,
                    studentName: _student.name,
                  );
                }

                _reverseGeocodeLocation(newLocation);
              }
            },
            onError: (error) {
              print('❌ Location stream error: $error');
            },
          );

    } catch (e) {
      print('💥 Error in location setup: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reverseGeocodeLocation(LatLng location) async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      String resolvedName = "Unknown Location";
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        List<String?> addressParts = [
          place.name,
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.country
        ].where((part) => part != null && part.isNotEmpty).toSet().toList();
        if (addressParts.isNotEmpty) {
          resolvedName = addressParts.join(', ');
        }
      }
      if (mounted) {
        setState(() {
          _currentPlaceName = resolvedName;
        });
      }
    } catch (e) {
      print("Error during reverse geocoding: $e");
      if (mounted) {
        setState(() {
          _currentPlaceName = "Error resolving location";
        });
      }
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    if (!_isMapReady) return; // Guard against calling before map is ready

    final latTween = LatLngTween(
      begin: _mapController.camera.center,
      end: destLocation,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    final animation = CurvedAnimation(
      parent: animationController,
      curve: Curves.fastOutSlowIn,
    );

    animationController.addListener(() {
      _mapController.move(
        latTween.evaluate(animation),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        animationController.dispose();
      }
    });

    animationController.forward();
  }

  Future<void> _fetchBuildings() async {
    if (!_isMapReady || _mapController.camera.zoom < 17) {
      if (mounted && _buildingPolygons.isNotEmpty) {
        setState(() {
          _buildingPolygons = [];
        });
      }
      return;
    }
    if (!mounted) return;

    try {
      final bounds = _mapController.camera.visibleBounds;
      final buildings = await _mapService.fetchBuildingData(bounds);
      if (mounted) {
        setState(() {
          _buildingPolygons = buildings
              .map(
                (points) => Polygon(
                  points: points,
                  color: _primaryColor.withAlpha((255 * 0.08).toInt()),
                  borderColor: _primaryColor.withAlpha((255 * 0.3).toInt()),
                  borderStrokeWidth: 1.5,
                ),
              )
              .toList();
        });
      }
    } catch (e) {
      print('Error fetching building data: $e');
    }
  }

  // Helper method to show the modal for a given student
  void _showStudentModal(Student student) {
    setState(() {
      _selectedStudent = student;
      _isModalVisible = true;
    });
  }

  // Helper method to check if two dates are on the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  // Helper method to cleanup all listeners before logout
  void _cleanupListeners() {
    print('🧹 Cleaning up listeners before logout...');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    
    _studentsStreamSubscription?.cancel();
    _studentsStreamSubscription = null;
    
    _assignedIdsSub?.cancel();
    _assignedIdsSub = null;
    
    print('✅ All listeners cleaned up');
  }

  @override
  void dispose() {
    // Cleanup listeners
    _cleanupListeners();
    
    // Dispose controllers
    _markerAnimationController.dispose();
    _backgroundAnimationController.dispose();
    _pulseAnimationController.dispose();
    _slideAnimationController.dispose();
    _lrnFilterController.dispose();
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      bottomNavigationBar: _isLoading
          ? null
          : _buildEnhancedBottomNavigationBar(),
      body: Stack(
        children: [
          _buildEnhancedBackground(),
          _buildMap(),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            right: 20,
            child: _buildEnhancedStudentInfoCard(),
          ),
          if (_isLoading) _buildEnhancedLoadingIndicator(),
          if (_isModalVisible)
            StudentInfoModal(
              student: _selectedStudent,
              userCurrentLocation: _selectedStudent.currentLocation,
              currentPlaceName: _currentPlaceName,
              onClose: () {
                setState(() {
                  _isModalVisible = false;
                  _selectedStudent = _student; // Reset to the logged-in user
                });
              },
            ),
        ],
      ),
      floatingActionButton: _isLoading ? null : _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  /// Builds the animated background container.
  Widget _buildEnhancedBackground() {
    return AnimatedBuilder(
      animation: _backgroundAnimationController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _primaryColor.withAlpha((255 * 0.05).toInt()),
                _surfaceColor,
                _secondaryColor.withAlpha((255 * 0.05).toInt()),
                _accentColor.withAlpha((255 * 0.03).toInt()),
              ],
              begin: _backgroundAlignmentAnimation.value,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.3, 0.7, 1.0],
            ),
          ),
        );
      },
    );
  }

  /// Builds the main FlutterMap widget with layers and markers.
  Widget _buildMap() {
    List<Marker> allMarkers = [];

    // Helper inline to decide visibility based on privacy rule
    bool isVisible(Student s) {
      final double d = _distance(_schoolCoordinates, s.currentLocation);
      return d <= (_insideSchoolRadiusMeters + _privacyExtraVisibleRadiusMeters);
    }

  // Add current user marker if within privacy visibility range and not a teacher
  if (!_student.isTeacher && isVisible(_student)) {
      allMarkers.add(
        Marker(
          width: 90.0,
          height: 90.0,
          point: _student.currentLocation,
          child: GestureDetector(
            onTap: () => _showStudentModal(_student),
            child: _buildEnhancedStudentMarker(),
          ),
        ),
      );
    }

    // Add other students' markers when visible (only for teacher accounts)
    if (_student.isTeacher) {
      for (final student in _otherStudents) {
        if (!isVisible(student)) continue; // Skip hidden for privacy
        allMarkers.add(
          Marker(
            width: 60,
            height: 60,
            point: student.currentLocation,
            child: GestureDetector(
              onTap: () => _showStudentModal(student),
              child: _buildOtherStudentMarker(student),
            ),
          ),
        );
      }
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _student.currentLocation,
        initialZoom: 18.5,
        maxZoom: 22,
        minZoom: 15,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture) _fetchBuildings();
        },
        onMapReady: () {
          if (mounted) {
            setState(() {
              _isMapReady = true;
            });
            _mapController.move(_student.currentLocation, 18.5);
            print("🗺️ Map is ready. Moved to initial location.");
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          maxZoom: 22,
        ),
        PolygonLayer(polygons: _buildingPolygons),
        CircleLayer(
          circles: [
            CircleMarker(
              point: _schoolCoordinates,
              radius: 100,
              useRadiusInMeter: true,
              color: _successColor.withAlpha(50),
              borderColor: _successColor.withAlpha(150),
              borderStrokeWidth: 2,
            ),
            // Optional: visual ring for the privacy visibility extension (semi-transparent)
            CircleMarker(
              point: _schoolCoordinates,
              radius: _insideSchoolRadiusMeters + _privacyExtraVisibleRadiusMeters,
              useRadiusInMeter: true,
              color: _accentColor.withAlpha(10),
              borderColor: _accentColor.withAlpha(80),
              borderStrokeWidth: 1,
            ),
          ],
        ),
        MarkerLayer(markers: allMarkers),
      ],
    );
  }

  /// Builds the custom animated marker for the logged-in student.
  Widget _buildEnhancedStudentMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        ScaleTransition(
          scale: _pulseAnimation,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _primaryColor.withAlpha((255 * 0.2).toInt()),
              border: Border.all(
                color: _primaryColor.withAlpha((255 * 0.4).toInt()),
                width: 2,
              ),
            ),
          ),
        ),
        ScaleTransition(
          scale: _markerAnimation,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(color: _primaryColor, width: 3),
              boxShadow: [
                BoxShadow(
                  color: _primaryColor.withAlpha((255 * 0.3).toInt()),
                  spreadRadius: 0,
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(3.0),
              child: ClipOval(
                child: Image.network(
                  _student.profileImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [_primaryColor, _secondaryColor],
                      ),
                    ),
                    child: const Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the pulsing marker for other students.
  Widget _buildOtherStudentMarker(Student student) {
    return ScaleTransition(
      scale: _pulseAnimation,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: student.status == LocationStatus.insideSchool
                ? _successColor
                : _warningColor,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.2).toInt()),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: ClipOval(
            child: Image.network(
              student.profileImageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.person,
                color: Colors.grey,
                size: 30,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the enhanced student information card displayed at the top.
  /// This card now reflects the `_selectedStudent`.
  Widget _buildEnhancedStudentInfoCard() {
    final studentToShow = _selectedStudent;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_primaryColor, _secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: _primaryColor.withAlpha((255 * 0.3).toInt()),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Padding(
                padding: const EdgeInsets.all(3.0),
                child: ClipOval(
                  child: Image.network(
                    studentToShow.profileImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.person, color: Colors.grey),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentToShow.name,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    studentToShow.gradeLevel,
                    style: TextStyle(
                      color: Colors.white.withAlpha((255 * 0.9).toInt()),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // FIXED: Status indicator with dot and text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha((255 * 0.2).toInt()),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withAlpha((255 * 0.3).toInt()),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: studentToShow.status == LocationStatus.insideSchool
                            ? _successColor
                            : _warningColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    studentToShow.statusDisplay,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            // Profile button
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showProfilePage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((255 * 0.2).toInt()),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withAlpha((255 * 0.3).toInt()),
                    width: 1,
                  ),
                ),
                child: const Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a column of floating action buttons for map interaction.
  Widget _buildFloatingActionButtons() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: 'zoomIn',
          onPressed: () {
            _animatedMapMove(_mapController.camera.center, _mapController.camera.zoom + 1);
          },
          mini: true,
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'zoomOut',
          onPressed: () {
            _animatedMapMove(_mapController.camera.center, _mapController.camera.zoom - 1);
          },
          mini: true,
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          child: const Icon(Icons.remove),
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'myLocation',
          onPressed: () {
            _animatedMapMove(_student.currentLocation, 18.5);
          },
          backgroundColor: _primaryColor,
          foregroundColor: Colors.white,
          child: const Icon(Icons.my_location),
        ),
      ],
    );
  }

  /// Builds the enhanced loading indicator overlay.
  Widget _buildEnhancedLoadingIndicator() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha((255 * 0.95).toInt()),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.1).toInt()),
              blurRadius: 30,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: _primaryColor,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Loading Map...",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _darkTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Please wait while we fetch the latest data",
              style: TextStyle(fontSize: 12, color: _lightTextColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedBottomNavigationBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 20.0,
          sigmaY: 20.0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha((255 * 0.9).toInt()),
            border: Border(
              top: BorderSide(
                color: Colors.white.withAlpha((255 * 0.2).toInt()),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            bottom: true,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                const _EnhancedNavItem(
                  icon: FontAwesomeIcons.house,
                  label: "Home",
                  isActive: true,
                ),
                const _EnhancedNavItem(
                  icon: FontAwesomeIcons.clockRotateLeft,
                  label: "History",
                  isActive: false,
                ),
                if (_student.isTeacher)
                  _EnhancedNavItem(
                    icon: FontAwesomeIcons.users,
                    label: "Students",
                    isActive: false,
                    onTap: _showStudentsListSheet,
                  ),
                _EnhancedNavItem(
                  icon: FontAwesomeIcons.solidUser,
                  label: "Profile",
                  isActive: false,
                  onTap: _showProfilePage,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Returns a sorted & optionally filtered list of other students for teacher view
  List<Student> _sortedFilteredOtherStudents() {
    if (!_student.isTeacher) return const [];
    final List<Student> sorted = List<Student>.from(_otherStudents);
    sorted.sort((a, b) => a.id.compareTo(b.id)); // Sort by LRN/id ascending
    if (_lrnFilterQuery.trim().isEmpty) return sorted;
    final q = _lrnFilterQuery.trim();
    return sorted.where((s) => s.id.contains(q)).toList();
  }

  void _showProfilePage() {
    print('Profile button tapped!'); // Debug print
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProfilePage(
          student: _student,
          onCleanupBeforeLogout: _cleanupListeners,
          onLogout: () {
            // Navigate to login screen and remove all previous routes
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          },
          onProfileUpdated: (updatedStudent) {
            if (mounted) {
              setState(() {
                _student = updatedStudent;
                // Also update selected student if it's the same student
                if (_selectedStudent.id == updatedStudent.id) {
                  _selectedStudent = updatedStudent;
                }
              });
            }
          },
        ),
      ),
    );
  }

  void _showStudentsListSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final visibleStudents = _sortedFilteredOtherStudents();
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 16,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Students (sorted by LRN)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Inter',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _lrnFilterController,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search),
                        hintText: 'Filter by LRN...',
                        suffixIcon: _lrnFilterQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _lrnFilterController.clear();
                                  setState(() => _lrnFilterQuery = '');
                                  setModalState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _lrnFilterQuery = val);
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Add student LRN',
                              prefixIcon: const Icon(Icons.person_add_alt),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (val) async {
                              final trimmed = val.trim();
                              if (trimmed.isEmpty) return;
                              final ok = await _assignmentService.addStudentToTeacher(_student.id, trimmed);
                              if (!mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Failed to add "$trimmed" (not found).')),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Added $trimmed.')),
                                );
                              }
                              setModalState(() {});
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Refresh assignments',
                          child: IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () => setModalState(() {}),
                          ),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: visibleStudents.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'No students match that LRN.',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: visibleStudents.length,
                              itemBuilder: (context, index) {
                                final s = visibleStudents[index];
                                final bool hasAbsenceReason = !s.isTeacher && 
                                    s.status == LocationStatus.outsideSchool &&
                                    s.isDuringClassHours &&
                                    s.absenceReason != null && 
                                    s.absenceReasonSubmittedAt != null &&
                                    _isSameDay(s.absenceReasonSubmittedAt!, DateTime.now());
                                
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundImage: NetworkImage(s.profileImageUrl),
                                  ),
                                  title: Text('${s.id}  •  ${s.name}'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${s.gradeLevel} • ${s.statusDisplay}'),
                                      if (hasAbsenceReason) ...[
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _warningColor.withAlpha((255 * 0.1).toInt()),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: _warningColor.withAlpha((255 * 0.3).toInt()),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.info_outline,
                                                size: 12,
                                                color: _warningColor,
                                              ),
                                              const SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  'Absent: ${s.absenceReason!}',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: _warningColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: _warningColor.withAlpha((255 * 0.2).toInt()),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  "ABSENT",
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.bold,
                                                    color: _warningColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                                    tooltip: 'Remove from monitoring',
                                    onPressed: () async {
                                      final confirmed = await _confirmRemoval(s.id);
                                      if (confirmed != true) return;
                                      await _assignmentService.removeStudentFromTeacher(_student.id, s.id);
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Removed ${s.id}.')),
                                      );
                                      setModalState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    // Center map on selected student & show modal
                                    Future.delayed(const Duration(milliseconds: 50), () {
                                      _animatedMapMove(s.currentLocation, 18.5);
                                      _showStudentModal(s);
                                    });
                                  },
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
      },
    );
  }

  Future<bool?> _confirmRemoval(String studentId) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student'),
        content: Text('Remove $studentId from your monitoring list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}

class _EnhancedNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _EnhancedNavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    this.onTap,
  });

  static const Color _primaryColor = Color(0xFF6366F1);
  static const Color _lightTextColor = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
  onTap: onTap ?? () { print('Tapped: $label'); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? _primaryColor.withAlpha((255 * 0.1).toInt())
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isActive ? _primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _primaryColor.withAlpha((255 * 0.3).toInt()),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                icon,
                color: isActive ? Colors.white : _lightTextColor,
                size: 20,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? _primaryColor : _lightTextColor,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LatLngTween extends Tween<LatLng> {
  LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) {
    return LatLng(
      begin!.latitude + (end!.latitude - begin!.latitude) * t,
      begin!.longitude + (end!.longitude - begin!.longitude) * t,
    );
  }
}

class SchoolBoundary {
  final LatLng schoolCenter;
  final double insideSchoolRadius;

  final Distance _distance = const Distance();

  SchoolBoundary({
    required this.schoolCenter,
    this.insideSchoolRadius = 500,
  });

  LocationStatus checkLocationStatus(LatLng studentLocation) {
    final double distance = _distance(schoolCenter, studentLocation);
    if (distance <= insideSchoolRadius) {
      return LocationStatus.insideSchool;
    } else {
      return LocationStatus.outsideSchool;
    }
  }
}