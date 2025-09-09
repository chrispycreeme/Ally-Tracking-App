# 🎓 ALLY

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white) ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black) ![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white) ![Status](https://img.shields.io/badge/Status-Development%20Phase-blue?style=for-the-badge)

> **Track, Trust, Transform** - Empowering educational institutions with intelligent student safety monitoring.

**ALLY** is a sophisticated Flutter-based mobile application that revolutionizes student safety management for educational institutions. Built with Firebase's robust backend infrastructure, ALLY delivers a secure, privacy-first platform for real-time location tracking, intelligent geofencing, and seamless communication between students, teachers, and administrators.

## ✨ Why ALLY?

- **🛡️ Safety First**: Real-time monitoring ensures student safety within and around school premises
- **🔒 Privacy-Focused**: Advanced privacy controls protect student data beyond school boundaries  
- **📱 Modern Interface**: Beautiful, intuitive UI with smooth animations and responsive design
- **⚡ Smart Technology**: Geofencing with battery-optimized location tracking

---

## 🚀 Core Features

### 🔐 **Authentication & Role Management**

- **Automatic Role Detection**: Single "Account ID" field with intelligent role detection (student vs teacher)
- **Secure Firebase Authentication**: Uses email pattern `<id>@school.com` (LRN for students, Staff ID for teachers)
- **Role-Based Access Control**: Different permissions and interfaces for students and teachers
- **Animated Login Interface**: Beautiful glassmorphism login screen with smooth animations

### 📍 **Location Tracking & Geofencing**

- **Real-time GPS Monitoring**: Continuous location updates for students (teachers are observers only)
- **Intelligent Geofencing**: Automatic detection of school entry/exit with configurable boundaries
- **Privacy Protection**: Student markers hidden beyond school + privacy radius (300m) for off-campus privacy
- **Battery Optimization**: Efficient 1-meter distance filtering to minimize power consumption
- **Location Status Detection**: Automatic "inside school" vs "outside school" status updates

### 🗺️ **Interactive Map Interface**

- **Professional Map Display**: Built with `flutter_map` for responsive, interactive mapping
- **Constant-Size Markers**: Static student markers that maintain size across zoom levels
- **Building Polygon Visualization**: Detailed school building footprints with enhanced visibility
- **Smart Building Detection**: Automatic identification of which building a student is in
- **Building Labels**: Labeled markers at building centroids for easy identification
- **Real-time Synchronization**: Live updates across all connected devices
- **Intuitive Controls**: Pan, zoom, and auto-center functionality

### 📊 **Activity History & Analytics**

- **Beautiful Timeline Interface**: Modern card-based history with date grouping and visual timeline
- **Rich Activity Cards**: Color-coded entries with custom icons for different activity types
- **Smart Date Formatting**: Intelligent date/time display with fallback formatting
- **Comprehensive Details**: Location coordinates, place names, and status information
- **Teacher Overview**: Multi-student history access with elegant student picker
- **Responsive Design**: Smooth animations and overflow-safe text handling

### 👥 **Role-Based Functionality**

#### **Student Features**
* **Personal Tracking**: View only their own location and status
* **Absence Management**: Easy submission of absence reasons when outside school during class hours
* **Profile Management**: Access to personal information and settings
* **Privacy Controls**: Automatic location hiding when far from school premises

#### **Teacher Features**
* **Multi-Student Monitoring**: View all assigned student locations in real-time
* **Student Assignment System**: Add/remove students from monitoring lists via LRN
* **Comprehensive Student Information**: Detailed profiles, class schedules, and activity timelines
* **Absence Reason Visibility**: Access to student-submitted absence explanations
* **Advanced Filtering**: Search and filter students by LRN or status
* **Student Management**: Bottom sheet interface for efficient student oversight

### ⚠️ **Absence Management System**
* **Automated Detection**: Identifies students outside school during class hours
* **Smart Prompting**: Context-aware absence reason requests (once per day)
* **Predefined Options**: Quick selection from common absence reasons
* **Custom Explanations**: Flexible text input for specific situations
* **Teacher Visibility**: Real-time absence reason display with timestamps
* **Activity Timeline**: Visual representation of student activities and absences

### 🔔 **Notification System**
* **Geofence Alerts**: Local notifications for school entry/exit events
* **Cross-Platform Support**: Native notifications on Android and iOS
* **Permission Management**: Proper handling of notification permissions
* **Real-time Status Updates**: Instant alerts for location status changes

---

## 📦 Technical Architecture

### **Core Technologies**

- **Flutter SDK 3.8+**: Cross-platform mobile development framework
- **Firebase Suite**: Backend-as-a-Service for authentication and real-time database
- **Dart Language**: Primary programming language with null safety

### **Key Dependencies**

```yaml
dependencies:
  # Firebase & Authentication
  firebase_core: 3.15.1
  firebase_auth: 5.6.2
  cloud_firestore: 5.6.11
  firebase_storage: ^12.3.9
  firebase_app_check: ^0.3.0+1
  
  # Maps & Location Services
  flutter_map: 8.2.1
  flutter_map_tile_caching: ^10.1.1
  latlong2: 0.9.1
  geolocator: 14.0.2
  geocoding: 4.0.0
  
  # UI/UX & Animations
  font_awesome_flutter: 10.8.0
  intl: ^0.19.0                      # Internationalization & date formatting
  
  # Media & Storage
  image_picker: ^1.1.2
  
  # Notifications
  flutter_local_notifications: ^17.2.3
  
  # Networking
  http: ^1.5.0-beta
```

### **Architecture Highlights**

- **MVVM Pattern**: Clean separation of concerns with reactive state management
- **Stream-based Real-time Updates**: Efficient Firebase Firestore streams
- **Modular Design**: Organized codebase with clear service boundaries
- **Performance Optimized**: Battery-efficient location tracking and smart caching

---

## 🏗️ Database Architecture

### **Firestore Collections Structure**

```javascript
// Students Collection
students/{lrn} {
  id: string,
  name: string,
  gradeLevel: string,
  profileImageUrl: string,
  currentLocation: GeoPoint,
  status: string, // "insideSchool" | "outsideSchool"
  classHours: string, // "08:00-15:00"
  dismissalTime: string,
  recentActivity: string,
  lastUpdated: Timestamp,
  role: "student",
  absenceReason?: string,
  absenceReasonSubmittedAt?: Timestamp,
  currentBuilding?: string // Name of building if inside one
}

// Teachers Collection
teachers/{staffId} {
  id: string,
  name: string,
  gradeLevel: string, // Department/Subject
  profileImageUrl: string,
  role: "teacher",
  classHours?: string,
  dismissalTime?: string,
  recentActivity: string,
  lastUpdated: Timestamp
}

// Teacher Assignments Collection
teacherAssignments/{teacherId} {
  studentIds: string[] // Array of student LRNs
}

// Buildings Collection (NEW)
buildings/{buildingId} {
  name: string, // "Admin Building", "Science Wing", etc.
  polygon: GeoPoint[], // Array of coordinate vertices (min 3 points)
  color?: string, // Optional hex color "#6366F1"
  level?: number, // Optional floor/level indicator
  centroid?: GeoPoint // Optional cached center point
}
```

---

## 📁 Project Structure

```
lib/
├── main.dart                           # App entry point & Firebase initialization
├── login_screen.dart                   # Authentication interface
├── login_service.dart                  # Firebase authentication logic
├── map_screen.dart                     # Main map interface & location tracking
├── profile_page.dart                   # User profile management
├── history_screen.dart                 # Activity history with modern UI
├── notification_service.dart           # Local notifications for geofencing
└── map_handlers/
    ├── student_model.dart              # Student/Teacher data model
    ├── building_model.dart             # Building polygon data model (NEW)
    ├── map_service.dart                # Firestore data operations & building detection
    ├── student_info_modal.dart         # Student detail modal interface
    ├── absence_reason_dialog.dart      # Absence reason submission dialog
    ├── teacher_assignment_service.dart # Teacher-student assignment management
    ├── history_service.dart            # Activity history data service
    └── history_entry.dart              # History entry data model

assets/
├── background.png                      # Login background image
└── fonts/
    ├── Inter-Light.ttf                 # Custom typography
    ├── Inter-Medium.ttf
    └── Inter-ExtraBold.ttf

android/
├── app/
│   ├── google-services.json          # Firebase Android configuration
│   └── build.gradle.kts               # Android build configuration
└── ...

ios/
├── Runner/
│   ├── GoogleService-Info.plist      # Firebase iOS configuration
│   └── Info.plist                     # iOS app configuration
└── ...
```

---

## 🛡️ Privacy & Security Features

### **Data Protection**
* **Geofenced Visibility**: Student locations only visible within school + 300m privacy radius
* **Role-Based Access**: Students see only their data; teachers see assigned students only
* **Automatic Privacy**: Student markers disappear when too far from school
* **Secure Authentication**: Firebase Auth with institutional email patterns
* **Data Validation**: Client and server-side validation of all location data

### **Compliance Ready**
* **Consent Management**: Clear privacy notices and permission requests
* **Minimal Data Collection**: Only essential location and profile data collected
* **Temporary Storage**: Location updates don't create permanent history logs
* **Access Controls**: Strict role-based permissions throughout the application

---

## ⚡ Performance & Optimization

### **Battery & Network Optimization**
* **Efficient Location Updates**: 1-meter distance filter to minimize GPS usage
* **Smart Caching**: Firestore offline persistence for reduced network calls
* **Stream Management**: Proper subscription lifecycle to prevent memory leaks
* **Conditional Updates**: Location updates only when status actually changes

### **User Experience**
* **Smooth Animations**: 60fps animations with proper controller disposal
* **Responsive Design**: Adaptive layout for various screen sizes
* **Loading States**: Clear feedback during data fetching and operations
* **Error Handling**: Graceful degradation with user-friendly error messages

---

## 🎯 Current Status

### **✅ Recently Enhanced**

- **Building Polygon System**: Complete building footprint visualization with polygon detection
- **Building Detection**: Automatic identification of which building students are currently in  
- **Enhanced Map Visibility**: Higher contrast building polygons with labeled centroids
- **Constant-Size Markers**: Static student markers that don't scale with zoom levels
- **Firestore Security Rules**: Added secure access controls for buildings collection
- **Modern History Interface**: Redesigned activity history with timeline cards and date grouping
- **Improved Error Handling**: Robust date formatting with graceful fallbacks
- **UI/UX Refinements**: Fixed text overflow issues and improved dropdown interfaces
- **Performance Optimizations**: Enhanced stream management and animation controllers

### **🔧 Production Ready Features**

- Complete authentication system with role detection
- Real-time location tracking and geofencing  
- Interactive map with animated markers
- Student information management system
- Teacher assignment and monitoring tools
- Absence reason submission and tracking
- Local notification system
- Privacy controls and security measures
- **NEW**: Beautiful activity history with modern UI design

### **� Deployment Status**

The application is **production-ready** with:

- ✅ Comprehensive error handling and graceful degradation
- ✅ Professional UI/UX design with consistent theming
- ✅ Scalable Firebase backend architecture
- ✅ Security best practices and privacy controls
- ✅ Cross-platform compatibility (iOS/Android)
- ✅ Battery-optimized location tracking
- ✅ Responsive design for various screen sizes

---

## 🔄 Setup & Deployment

### **Firebase Configuration**
1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Authentication (Email/Password) and Firestore Database
3. Add your Android/iOS apps and download configuration files:
   - `android/app/google-services.json` (Android)
   - `ios/Runner/GoogleService-Info.plist` (iOS)

### **Database Setup**

1. Create Firestore collections: `students`, `teachers`, `teacherAssignments`, `buildings`
2. Populate with sample data following the schema above
3. Create Firebase Auth users with email pattern `<id>@school.com`
4. Configure Firestore security rules for role-based access (including buildings collection)
5. Add building polygon data using GeoPoint arrays for each building footprint

### **Development**
```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build for production
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## ⚠️ Privacy & Compliance Notice

**Important**: This application handles sensitive location data. Educational institutions implementing ALLY must:

- Obtain proper consent from students and parents/guardians
- Establish clear data retention and usage policies
- Implement proper security measures for data protection  
- Provide transparency about data collection and usage
- Conduct regular privacy impact assessments

---

## 📄 License

This project is proprietary software developed for educational institution use.
Contact the development team for licensing inquiries.

---

<div align="center">

**Built with ❤️ for student safety and educational excellence**

[![Made with Flutter](https://img.shields.io/badge/Made%20with-Flutter-blue)](https://flutter.dev)
[![Powered by Firebase](https://img.shields.io/badge/Powered%20by-Firebase-orange)](https://firebase.google.com)

</div>
