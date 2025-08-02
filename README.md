# ALLY: Track, Trust, Transform

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white) ![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)

**ALLY** is a powerful Flutter-based mobile application designed to empower educators and administrators with real-time student location tracking and management. Seamlessly integrated with Firebase, ALLY provides a secure and intuitive platform to monitor student whereabouts, ensure their safety within school boundaries, and access critical information instantly.

---

### 🚀 Features

* **Secure Authentication**: 🛡️ Users can securely sign in using their unique Learner Reference Number (LRN) and a password, verified via Firebase Authentication.
* **Real-time Location Tracking**: 📍 Stay updated with live student locations on a dynamic map, powered by `geolocator`.
* **Intelligent Boundary Detection**: 🏫 Automatically checks if students are within the predefined school boundary and provides real-time status updates.
* **Interactive Map**: 🗺️ A visually engaging map interface built with `flutter_map`, displaying all student markers (excluding the logged-in user).
* **Animated Student Info Modal**: ✨ Tap on a student's marker to reveal a beautiful, draggable glassmorphic modal with detailed student information.
* **Rich Animations**: 🎨 Enjoy a smooth and modern user experience with engaging animations on the login screen and map markers.
* **Robust Firebase Integration**: ☁️ Utilizes Firebase Authentication for secure access and Cloud Firestore for real-time, scalable data management.

---

### 📦 Technologies & Packages

* **Flutter**: The primary framework for building beautiful, natively compiled applications.
* **Firebase**: Our backend-as-a-service for Authentication and Firestore.
* **Packages**:
    * `flutter_map`: Interactive maps.
    * `latlong2`: Latitude and longitude handling.
    * `geolocator`: Device location services.
    * `geocoding`: Reverse geocoding.
    * `font_awesome_flutter`: A comprehensive icon set.
    * `http`: For network requests.

---

### 📁 File Structure

| File | Description |
| :--- | :--- |
| `main.dart` | Application entry point and login flow management. |
| `login_service.dart` | Handles all user authentication logic with Firebase. |
| `map_screen.dart` | The core map interface, responsible for UI, location tracking, and state management. |
| `map_service.dart` | Manages real-time data streams for students and other map-related data from Firestore. |
| `student_model.dart` | Data models for `Student` and `StudentLocationStatus`. |
| `student_info_modal.dart`| A reusable widget for displaying detailed student information. |
| `map_animations.dart` | Contains reusable animation logic to enhance the user experience. |
