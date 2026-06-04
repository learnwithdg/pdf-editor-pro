# PDF Editor Pro

A comprehensive **PDF Viewer & Editor** application built with Flutter. This app allows users to open, view, annotate, and edit PDF documents with a rich set of features.

## Features

### PDF Viewing
- Smooth PDF rendering with pinch-to-zoom
- Page navigation with jump-to-page
- Horizontal page swiping
- Zoom controls (in/out/reset)
- Full-screen reading mode (tap to hide UI)

### PDF Editing & Annotations
- **Highlight** - Select text and highlight with custom colors
- **Underline** - Underline important text
- **Strikethrough** - Strike through text
- **Text Notes** - Add text annotations anywhere on the page
- **Freehand Drawing** - Draw with pen tool
- **Color Picker** - Choose from multiple annotation colors
- **Undo** - Remove last annotation

### Document Management
- Open PDFs from device storage (file picker)
- Document info viewer (name, size, pages, path)
- Share PDFs via system share sheet
- Save annotated PDFs

### Search & Navigation
- Text search within document
- First/Last page quick jump
- Page counter with direct input

## Screenshots

| Home Screen | PDF Viewer | Edit Mode |
|:---:|:---:|:---:|
| Empty state with features | Document viewing | Annotation tools |

## Tech Stack

- **Flutter** - UI framework
- **pdfx** - PDF rendering and viewing
- **pdf** - PDF creation and manipulation
- **flutter_bloc** - State management
- **file_picker** - File selection
- **share_plus** - System sharing

## Getting Started

### Prerequisites
- Flutter SDK 3.0+
- Android SDK / Xcode (for mobile)
- Or Chrome/Edge (for web)

### Installation

1. **Clone the repository**
   ```bash
   cd pdf_editor_app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   # For mobile
   flutter run
   
   # For specific platform
   flutter run -d android
   flutter run -d ios
   flutter run -d windows
   flutter run -d macos
   flutter run -d linux
   flutter run -d chrome
   ```

### Platform-Specific Setup

#### Android
Add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

#### iOS
Add to `ios/Runner/Info.plist`:
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs access to photos for PDF attachments</string>
```

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/
│   └── pdf_document.dart     # Data models
├── blocs/
│   ├── pdf_bloc.dart         # Business logic
│   ├── pdf_event.dart        # Events
│   └── pdf_state.dart        # States
├── screens/
│   ├── home_screen.dart      # Home/landing page
│   └── pdf_viewer_screen.dart # PDF viewer & editor
└── widgets/
    ├── annotation_overlay.dart # Annotation drawing layer
    └── toolbar.dart          # Editor toolbar
```

## Architecture

The app uses **BLoC (Business Logic Component)** pattern for state management:

- **Events** - User actions (Load PDF, Add Annotation, Change Page, etc.)
- **States** - UI states (Loading, Loaded, Error)
- **Bloc** - Connects events to states with business logic

## Usage Guide

### Opening a PDF
1. Tap the **Open PDF** button on home screen
2. Select a PDF file from your device
3. The PDF will load and display

### Viewing
- **Swipe** left/right to change pages
- **Pinch** to zoom in/out
- **Tap center** to toggle full-screen mode
- Use bottom bar for precise page navigation

### Annotating
1. Tap the **Edit** icon in top bar
2. Select a tool from the toolbar:
   - Highlight, Underline, Strikethrough, Text, or Pen
3. Tap/Drag on the document to place annotations
4. Tap the **color button** to change annotation color
5. Tap **Undo** to remove last annotation
6. Tap **Save** to preserve changes

## Keyboard Shortcuts (Desktop)

| Shortcut | Action |
|----------|--------|
| `Ctrl + O` | Open file |
| `Ctrl + S` | Save |
| `Ctrl + F` | Search |
| `Page Up` | Previous page |
| `Page Down` | Next page |
| `Ctrl + +` | Zoom in |
| `Ctrl + -` | Zoom out |
| `Ctrl + 0` | Reset zoom |
| `Esc` | Exit edit mode |

## Dependencies

```yaml
dependencies:
  pdfx: ^2.6.0          # PDF viewer
  pdf: ^3.10.7          # PDF creation
  file_picker: ^6.1.1   # File selection
  path_provider: ^2.1.2 # File paths
  flutter_bloc: ^8.1.3  # State management
  share_plus: ^7.2.1    # System sharing
  uuid: ^4.3.3          # Unique IDs
```

## Roadmap

- [ ] Signature capture with camera
- [ ] Form filling support
- [ ] PDF merging and splitting
- [ ] Cloud storage integration (Google Drive, Dropbox)
- [ ] Text editing in PDFs
- [ ] OCR for scanned documents
- [ ] Password-protected PDF support
- [ ] Night/sepia reading modes

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Acknowledgments

- [pdfx](https://pub.dev/packages/pdfx) - PDF viewing
- [pdf](https://pub.dev/packages/pdf) - PDF creation
- [Flutter](https://flutter.dev) - UI framework

---

Made with Flutter
