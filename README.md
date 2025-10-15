# PhotoAssistant

A professional iOS camera app that captures photos with comprehensive location, orientation, and metadata information. Perfect for photography professionals, surveyors, real estate agents, and anyone who needs detailed spatial data embedded in their photos.

## Features

### 📸 Advanced Camera Controls
- **Multi-lens support**: Automatic detection and switching between Ultra Wide (0.5x), Wide (1x), Telephoto (2x), and Telephoto 3x cameras
- **High-resolution capture**: Supports 4K and maximum photo quality settings
- **Real-time camera preview**: Full-screen live preview with proper orientation handling
- **Auto flash**: Intelligent flash control based on lighting conditions

### 🧭 Comprehensive Location Data
- **GPS coordinates**: Precise latitude and longitude with accuracy indicators
- **Altitude tracking**: Elevation data in feet with accuracy validation
- **Compass heading**: True north bearing with 16-point compass directions (N, NNE, NE, etc.)
- **Address lookup**: Reverse geocoding to display human-readable addresses
- **Motion sensors**: Real-time device tilt and roll angle measurements

### 📊 Real-time Orientation Display
- **Vertical angle**: Camera tilt relative to horizon (pitch)
- **Horizontal angle**: Camera roll relative to level position
- **Compass heading**: Direction camera is pointing with precise degree measurements
- **Live updates**: All measurements update in real-time as you move the device

### 🖼️ Enhanced Photo Output
- **EXIF metadata embedding**: All location and orientation data saved to photo metadata
- **Visual information banner**: Photos include overlay with key information
- **Proper orientation handling**: Automatic rotation correction for all device orientations
- **Photo library integration**: Seamless saving to iOS Photos app

### 🔐 Privacy & Permissions
- **Permission management**: Graceful handling of camera, location, and photo library permissions
- **User choice**: Option to use camera without location services if desired
- **Privacy compliance**: Includes proper privacy usage descriptions
- **Settings integration**: Direct links to system settings for permission management

## Technical Details

### Requirements
- iOS 17.0 or later
- iPhone with camera (multiple lens support varies by device)
- Location services recommended for full functionality

### Frameworks Used
- **SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Camera capture and video preview
- **CoreLocation**: GPS, altitude, and heading data
- **CoreMotion**: Device orientation and motion sensors
- **Photos**: Photo library access and saving
- **SwiftData**: Data persistence framework
- **ImageIO**: EXIF metadata manipulation

### Architecture
- **MVVM Pattern**: Clean separation of concerns with ObservableObject
- **Async/Await**: Modern concurrency for photo operations
- **Combine Framework**: Reactive data binding for real-time updates
- **Delegate Pattern**: Location and camera event handling

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/PhotoAssistant.git
   ```

2. Open `PhotoAssistant.xcodeproj` in Xcode 15 or later

3. Build and run on a physical iOS device (camera functionality requires actual hardware)

## Usage

1. **Launch the app**: Camera view opens automatically with permission requests
2. **Grant permissions**: Allow camera, location, and photo library access for full functionality
3. **Switch lenses**: Tap the lens selector buttons (.5, 1x, 2, 3) to change between available cameras
4. **Monitor data**: Watch real-time updates of location, heading, and orientation information
5. **Capture photos**: Tap the white shutter button to take enhanced photos
6. **View results**: Photos are automatically saved to your photo library with all metadata

## Permissions Required

The app requires the following permissions for full functionality:

- **Camera**: To capture photos
- **Location When In Use**: For GPS coordinates, altitude, and address information
- **Photo Library (Add Only)**: To save enhanced photos
- **Motion & Fitness**: For device orientation and tilt measurements

## Privacy

PhotoAssistant respects your privacy:
- Location data is only used to enhance your photos
- No data is transmitted to external servers
- All information stays on your device
- You can use the camera without location services if preferred

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Developer

Created by Richard Cox - October 2025

## Acknowledgments

- Built with Swift and SwiftUI
- Utilizes Apple's Core frameworks for location and camera functionality
- Designed for professional photography and surveying applications

---

*PhotoAssistant - Capture more than just images, capture the complete picture.*