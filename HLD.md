# MarkMe - High-Level Design Document

## 1. Introduction

### 1.1 Purpose
MarkMe is a modern attendance tracking application built with Flutter that provides both online and offline attendance management capabilities. It allows users to create and manage attendance records using NFC technology or manual entry.

### 1.2 Scope
This document outlines the high-level architecture, components, data flow, and technical implementation details of the MarkMe application.

## 2. System Overview

### 2.1 System Description
MarkMe is a cross-platform mobile application that enables users to:
- Create and manage student attendance records
- Work in offline mode with local storage
- Work in online mode with real-time synchronization
- Use NFC technology to scan student IDs
- Export attendance data
- Authenticate users securely

### 2.2 System Architecture
The application follows a client-server architecture with:
- **Frontend**: Flutter-based mobile application
- **Backend**: Supabase for authentication, database, and real-time functionality
- **Storage**: Both local storage (SharedPreferences) and cloud storage (Supabase)

## 3. Technical Stack

### 3.1 Frontend
- **Framework**: Flutter
- **Language**: Dart
- **State Management**: Provider pattern
- **UI Components**: Custom Material Design components

### 3.2 Backend
- **Platform**: Supabase
- **Authentication**: Supabase Auth
- **Database**: PostgreSQL (via Supabase)
- **Real-time**: Supabase Realtime

### 3.3 Storage
- **Local Storage**: SharedPreferences
- **Cloud Storage**: Supabase PostgreSQL

### 3.4 Key Dependencies
- `supabase_flutter`: Backend integration
- `flutter_dotenv`: Environment variable management
- `provider`: State management
- `shared_preferences`: Local storage
- `nfc_manager`: NFC functionality
- `device_info_plus`: Device identification
- `share_plus`: Export functionality
- `path_provider`: File system access
- `intl`: Internationalization and formatting
- `google_fonts`: Typography

## 4. Component Architecture

### 4.1 Core Components

#### 4.1.1 Services
- **AuthService**: Handles user authentication and session management
- **FolderService**: Manages offline folders and student data
- **LobbyService**: Manages online lobbies and attendance records
- **NFCService**: Handles NFC scanning and data extraction
- **NotificationService**: Manages in-app notifications

#### 4.1.2 Providers
- **LobbyProvider**: Manages state for lobbies and real-time updates

#### 4.1.3 Models
- **Student**: Represents student data with ID, name, and timestamp
- **Lobby**: Represents an attendance session with members and records

#### 4.1.4 Screens
- **LoginScreen**: User authentication
- **HomeScreen**: Main navigation hub with folders and lobbies
- **FolderScreen**: Offline attendance management
- **CreateLobbyScreen**: Create new online attendance sessions
- **ActiveLobbyScreen**: Manage active attendance sessions

#### 4.1.5 Components
- **NotificationOverlay**: Displays in-app notifications
- **EmptyStateWidget**: Consistent empty state UI
- **MarkMeLogo**: Branding component

### 4.2 Data Flow

#### 4.2.1 Authentication Flow
1. User enters credentials in LoginScreen
2. AuthService validates credentials with Supabase
3. On success, user is redirected to HomeScreen
4. AuthService maintains session state

#### 4.2.2 Offline Attendance Flow
1. User creates a folder via HomeScreen
2. User navigates to FolderScreen
3. User adds students manually or via NFC
4. FolderService stores data in SharedPreferences
5. User can export attendance data as CSV

#### 4.2.3 Online Attendance Flow
1. User creates a lobby via CreateLobbyScreen
2. LobbyService creates entry in Supabase
3. User navigates to ActiveLobbyScreen
4. User adds students manually or via NFC
5. LobbyService stores records in Supabase
6. LobbyProvider handles real-time updates
7. User can export attendance data as CSV

## 5. Database Schema

### 5.1 Supabase Tables

#### 5.1.1 lobbies
- `id`: UUID (primary key)
- `name`: String
- `entry_code`: String
- `host_id`: UUID (foreign key to auth.users)
- `active`: Boolean
- `created_at`: Timestamp

#### 5.1.2 lobby_members
- `id`: UUID (primary key)
- `lobby_id`: UUID (foreign key to lobbies)
- `user_id`: UUID (foreign key to auth.users)
- `device_id`: String
- `created_at`: Timestamp

#### 5.1.3 attendance_records
- `id`: UUID (primary key)
- `lobby_id`: UUID (foreign key to lobbies)
- `student_system_id`: String
- `student_name`: String
- `user_id`: UUID (foreign key to auth.users)
- `device_id`: String
- `recorded_at`: Timestamp

### 5.2 Local Storage Schema

#### 5.2.1 SharedPreferences Keys
- `user_folders`: List of folder names
- `{folderName}_students`: List of serialized Student objects

## 6. Security Considerations

### 6.1 Authentication
- Email/password authentication via Supabase
- Session management with automatic token refresh
- User banning functionality

### 6.2 Data Protection
- Local data stored in device-protected SharedPreferences
- Server data protected by Supabase Row-Level Security (RLS)
- No sensitive data stored in plain text

## 7. NFC Implementation

### 7.1 NFC Reading
- Implemented using `nfc_manager` package
- Supports MIFARE Classic cards
- Reads student ID from Block 1
- Reads student name from Block 4
- Handles authentication with multiple keys

### 7.2 NFC Data Processing
- Validates scanned data
- Prevents duplicate attendance records
- Provides feedback via NotificationService

## 8. Offline vs Online Mode

### 8.1 Offline Mode (Folders)
- Works without internet connection
- Stores data locally using SharedPreferences
- Supports manual entry and NFC scanning
- Allows CSV export

### 8.2 Online Mode (Lobbies)
- Requires internet connection
- Stores data in Supabase
- Supports real-time updates across devices
- Provides entry codes for joining
- Supports manual entry and NFC scanning
- Allows CSV export

## 9. UI/UX Design

### 9.1 Theme
- Dark theme with yellow accent color
- Custom typography using Google Fonts
- Consistent gradient backgrounds
- Responsive layouts

### 9.2 Navigation
- Tab-based navigation in HomeScreen
- Stack-based navigation for detail screens
- Consistent back navigation

### 9.3 Notifications
- In-app notification system
- Color-coded by type (success, error, info, warning)
- Auto-dismissing with manual override

## 10. Future Enhancements

### 10.1 Potential Improvements
- Offline-to-online synchronization
- Advanced analytics and reporting
- Multiple NFC card type support
- User roles and permissions
- Cloud backup for offline data
- Push notifications

## 11. Conclusion

MarkMe provides a flexible and user-friendly solution for attendance tracking, with both online and offline capabilities. The application leverages modern technologies like Flutter, Supabase, and NFC to create a seamless experience for users managing attendance in various contexts.