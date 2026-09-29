# Photo App

A Flutter-based photo discovery application powered by the Pexels API, with Firebase Authentication and persistent user-specific saved photos.

## Features

* Firebase email/password authentication
* Persistent login sessions
* Pexels-powered photo feed
* Masonry-style photo grid
* Infinite scrolling
* Pull-to-refresh
* Photo search with debouncing
* Photo detail view with photographer information
* Save and remove photos
* Per-user saved photos with persistent storage
* Share photos
* Light, dark, and system theme
* Persistent theme preference
* Bottom navigation
* Preserved screen state while navigating
* Loading, empty, error, and retry states
* Animated splash screen
* Page transitions and UI animations
* Animated save interactions

## Tech Stack

* **Flutter**
* **Dart**
* **Firebase Authentication**
* **Pexels REST API**
* **SharedPreferences**
* **Git / GitHub**

## Setup

### 1. Clone the repository

```bash
git clone <YOUR_GITHUB_REPOSITORY_URL>
cd photo_app
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Add your Pexels API key

Open `lib/main.dart` and replace:

```dart
const String pexelsApiKey = 'YOUR_API_KEY_HERE';
```

with your own Pexels API key.

### 4. Run the application

```bash
flutter run
```

## Documentation & Screenshots

A walkthrough using screenshots of the project have been provided here:

**[View Documentation & Screenshots](https://drive.google.com/file/d/15F-LlmpoYpEnZGj9bycmul5OX7zK33av/view?usp=drivesdk)**

## About

This project was built to explore Flutter mobile application development, including authentication, REST API integration, asynchronous programming, local persistence, navigation, responsive layouts, and animations.

## API

Photos are provided by the **Pexels API**.

The application requires a valid Pexels API key to load photos.
