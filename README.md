# ALLY: Track, Trust, Transform

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white) ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black) ![Status](https://img.shields.io/badge/Status-Production%20Ready-green?style=for-the-badge)

**ALLY** is a comprehensive Flutter-based mobile application designed to empower educational institutions with real-time student safety monitoring and location management. Seamlessly integrated with Firebase, ALLY provides a secure, privacy-focused platform to track student whereabouts, ensure their safety within school boundaries, and facilitate transparent communication between students, teachers, and administrators.

---

## 🚀 Core Features

### 🔐 **Authentication & Role Management**
* **Automatic Role Detection**: Single "Account ID" field with intelligent role detection (student vs teacher)
* **Secure Firebase Authentication**: Uses email pattern `<id>@school.com` (LRN for students, Staff ID for teachers)
* **Role-Based Access Control**: Different permissions and interfaces for students and teachers
* **Animated Login Interface**: Beautiful glassmorphism login screen with smooth animations

### 📍 **Location Tracking & Geofencing**
* **Real-time GPS Monitoring**: Continuous location updates for students (teachers are observers only)
* **Intelligent Geofencing**: Automatic detection of school entry/exit with configurable boundaries
* **Privacy Protection**: Student markers hidden beyond school + privacy radius (300m) for off-campus privacy
* **Battery Optimization**: Efficient 1-meter distance filtering to minimize power consumption
* **Location Status Detection**: Automatic "inside school" vs "outside school" status updates

### 🗺️ **Interactive Map Interface**
* **Professional Map Display**: Built with `flutter_map` for responsive, interactive mapping
* **Animated Student Markers**: Smooth pulsing animations and status-based color coding
* **Building Visualization**: School building polygons for enhanced spatial awareness
* **Real-time Synchronization**: Live updates across all connected devices
* **Intuitive Controls**: Pan, zoom, and auto-center functionality

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

## 📦 Technical Stack

### **Core Technologies**
* **Flutter SDK**: Cross-platform mobile development framework
* **Firebase**: Backend-as-a-Service for authentication and real-time database
* **Dart**: Primary programming language

### **Key Dependencies**
* **Authentication**: `firebase_core`, `firebase_auth`, `cloud_firestore`
* **Maps & Location**: `flutter_map`, `latlong2`, `geolocator`, `geocoding`
* **UI & UX**: `font_awesome_flutter`, Custom animations and glassmorphism effects
* **Storage & Media**: `firebase_storage`, `image_picker`
* **Notifications**: `flutter_local_notifications`
* **Networking**: `http`

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
  absenceReasonSubmittedAt?: Timestamp
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
```

---

## 📁 Project Structure

```
lib/
├── main.dart                           # App entry point & animated login
├── login_service.dart                  # Firebase authentication logic
├── map_screen.dart                     # Main map interface & location tracking
├── profile_page.dart                   # User profile management
├── notification_service.dart           # Local notifications for geofencing
└── map_handlers/
    ├── student_model.dart              # Student/Teacher data model
    ├── map_service.dart                # Firestore data operations
    ├── student_info_modal.dart         # Student detail modal interface
    ├── absence_reason_dialog.dart      # Absence reason submission dialog
    ├── teacher_assignment_service.dart # Teacher-student assignment management
    └── map_animations.dart             # Map animation controllers
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

## � Current Status

### **✅ Completed Features**
* Complete authentication system with role detection
* Real-time location tracking and geofencing
* Interactive map with animated markers
* Student information management system
* Teacher assignment and monitoring tools
* Absence reason submission and tracking
* Local notification system
* Privacy controls and security measures

### **🔧 Production Ready**
The application is feature-complete for core functionality and ready for deployment with:
* Comprehensive error handling
* Professional UI/UX design
* Scalable database architecture
* Security best practices implemented
* Cross-platform compatibility (iOS/Android)

---

## 🔄 Setup & Deployment

### **Firebase Configuration**
1. Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Enable Authentication (Email/Password) and Firestore Database
3. Add your Android/iOS apps and download configuration files:
   - `android/app/google-services.json` (Android)
   - `ios/Runner/GoogleService-Info.plist` (iOS)

### **Database Setup**
1. Create Firestore collections: `students`, `teachers`, `teacherAssignments`
2. Populate with sample data following the schema above
3. Create Firebase Auth users with email pattern `<id>@school.com`
4. Configure Firestore security rules for role-based access

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

---

## 🧪 Future Enhancement Roadmap

* **📊 Analytics Dashboard**: Web-based admin portal for attendance analytics
* **📱 Parent Portal**: Parent access to their child's location status
* **🔄 Offline Support**: Queue location updates when device is offline
* **☁️ Cloud Functions**: Server-side validation and automated alerts
* **📈 Historical Data**: Location history tracking and reporting
* **🔔 Advanced Notifications**: SMS/Email alerts for extended absences
* **🎯 Geofence Customization**: Multiple zones (classroom, cafeteria, etc.)

---

## ⚠️ Privacy & Compliance

**Important**: Location tracking involves sensitive personal data. Educational institutions must:
* Obtain proper consent from students and parents/guardians
* Comply with local privacy regulations (GDPR, COPPA, etc.)
* Establish clear data retention and usage policies
* Implement proper security measures for data protection
* Provide transparency about data collection and usage

---

## 🤝 Contributing

We welcome contributions to improve ALLY! Please:
* Follow Flutter and Dart style guidelines
* Test thoroughly before submitting PRs
* Document any behavioral changes
* Respect privacy and security considerations

---

## 📄 License

This project is proprietary software developed for educational institution use. 
Contact the development team for licensing inquiries.

---

## � Support & Contact

For technical support, feature requests, or deployment assistance, please contact the development team.

**Built with ❤️ for student safety and educational excellence.**
