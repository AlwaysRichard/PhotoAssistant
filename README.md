# PhotoAssistant

A comprehensive iOS photography application that combines advanced camera controls with professional planning tools. Perfect for photography professionals, film photographers, and anyone who needs precise exposure calculations, depth of field planning, and field of view visualization.

## Features

### 📸 Advanced Camera View
- **Multi-lens support**: Automatic detection and switching between Ultra Wide (0.5x), Wide (1x), Telephoto (2x), and Telephoto 3x cameras
- **Perspective viewfinder**: Real-time overlay showing different camera aspect ratios and focal lengths for composition planning
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

### 🎯 My Gear Management
- **Camera database**: Store your camera bodies with sensor dimensions and capture plane specifications
- **Lens library**: Maintain a collection of prime and zoom lenses for each camera
- **Persistent storage**: Your gear configuration is saved and shared across all calculation tools
- **Easy organization**: Add, edit, and manage multiple camera/lens combinations

### 💡 Exposure Compensation Calculator
- **Film reciprocity failure correction**: Comprehensive database of black & white and color films with accurate reciprocity models
- **Filter compensation**: Add and manage ND filters, polarizers, and other filters with automatic stop calculation
- **Power law models**: Accurate corrections for films like Ilford HP5 Plus, Delta series, and T-Max
- **Lookup tables**: Precise corrections for slide films like Fuji Velvia and Kodak Ektachrome
- **Stop correction models**: Specialized handling for color negative films (Portra, Ektar)
- **Real-time calculations**: Instant exposure adjustments as you modify settings
- **Color shift warnings**: Recommendations for color correction filters on long exposures

### 📏 Depth of Field Calculator
- **Hyperfocal distance**: Calculate the optimal focus point for maximum depth of field
- **Near/far limits**: Precise depth of field boundaries for any focal length and aperture
- **Circle of confusion**: Sensor-specific CoC calculations based on your camera's capture plane
- **Real-time updates**: Instant recalculation as you adjust aperture, focal length, or focus distance
- **Multiple distance units**: Input focus distance in feet and inches
- **Infinity focus support**: Special handling for landscape photography at infinity

### 🔭 Field of View Calculator
- **Angular field of view**: Calculate horizontal, vertical, and diagonal angles for any lens/sensor combination
- **Scene coverage**: Determine the exact width and height covered at your focus distance
- **Visual representation**: Interactive diagram showing field of view dimensions with proper aspect ratio
- **Two-page results**: Swipeable interface showing calculations and visual preview
- **Multi-camera support**: Accurate calculations for any sensor size from full frame to APS-C to micro four thirds

### 🎨 Professional Interface
- **Camera LCD aesthetic**: Retro camera display styling with American Typewriter fonts
- **Consistent controls**: Unified interface across all calculation tools
- **Dark theme optimized**: Easy on the eyes in low-light shooting conditions
- **Intuitive workflows**: Streamlined lens and filter selection with embedded zoom controls
- **Swipeable results**: Multi-page result displays for detailed information

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
- Location services recommended for full camera functionality

### Frameworks Used
- **SwiftUI**: Modern declarative UI framework
- **AVFoundation**: Camera capture and video preview
- **CoreLocation**: GPS, altitude, and heading data
- **CoreMotion**: Device orientation and motion sensors
- **Photos**: Photo library access and saving
- **SwiftData**: Data persistence for gear management
- **ImageIO**: EXIF metadata manipulation
- **Combine**: Reactive data flow for real-time updates

### Architecture
- **MVVM Pattern**: Clean separation of concerns with ObservableObject
- **Async/Await**: Modern concurrency for photo operations
- **Shared State Management**: Centralized gear selection across all views via MyGearSelectionKeys
- **Codable Models**: Type-safe JSON parsing for film and filter databases
- **UserDefaults Persistence**: Settings and selections preserved between sessions

### Data Models
- **Film Reciprocity**: Power law, lookup table, and stop correction models for accurate long-exposure calculations
- **Filter Database**: Comprehensive catalog of ND filters, polarizers, color correction, and specialty filters
- **Capture Planes**: JSON-based sensor dimension database for accurate optical calculations
- **Gear Configuration**: Persistent camera and lens library with full metadata

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/PhotoAssistant.git
   ```

2. Open `PhotoAssistant.xcodeproj` in Xcode 15 or later

3. Build and run on a physical iOS device (camera functionality requires actual hardware)

## Usage

### Camera View
1. **Launch the app**: Camera view opens automatically with permission requests
2. **Grant permissions**: Allow camera, location, and photo library access for full functionality
3. **Switch lenses**: Tap the lens selector buttons (.5, 1x, 2, 3) to change between available cameras
4. **Use perspective overlay**: Enable viewfinder guides to preview different aspect ratios and focal lengths
5. **Monitor data**: Watch real-time updates of location, heading, and orientation information
6. **Capture photos**: Tap the white shutter button to take enhanced photos

### My Gear Setup
1. Navigate to the My Gear section
2. Add your camera bodies with sensor specifications (or use built-in capture plane database)
3. Add lenses (prime or zoom) to each camera
4. Your gear is automatically available in all calculation tools

### Exposure Compensation
1. Set your base exposure (aperture, shutter speed, ISO)
2. Select a film stock from 40+ options for reciprocity correction
3. Add filters (ND, polarizer, etc.) as needed
4. View corrected exposure time accounting for reciprocity failure
5. Review color filter suggestions for long exposures

### Depth of Field Calculator
1. Select your camera and lens from My Gear
2. Choose your aperture setting
3. Set your focus distance in feet and inches
4. View hyperfocal distance and depth of field limits
5. Use results to optimize focus for landscape or portrait photography

### Field of View Calculator
1. Select your camera and lens from My Gear
2. Adjust zoom if using a zoom lens (embedded slider in lens button)
3. Set your focus distance
4. View angular field of view (horizontal, vertical, diagonal)
5. Swipe to page 2 to see visual representation with labeled dimensions

## Key Features by Use Case

### Film Photographers
- Accurate reciprocity failure corrections for 40+ film stocks
- Filter compensation with stop calculations
- Support for both black & white and color films
- Color shift warnings and filter recommendations
- ISO automatically matches selected film stock

### Landscape Photographers
- Hyperfocal distance calculations for maximum sharpness
- Depth of field visualization
- Field of view planning for composition
- Infinity focus support

### Professional Photographers
- Multi-camera gear management
- Precise exposure calculations
- Sensor-specific optical calculations
- Real-time composition planning tools
- Shared gear settings across all calculation tools

### Photography Students
- Educational tool for understanding depth of field
- Field of view visualization
- Exposure triangle relationships
- Filter effects on exposure
- Reciprocity failure concepts

## Permissions Required

The app requires the following permissions for full functionality:

- **Camera**: To capture photos (Camera View only)
- **Location When In Use**: For GPS coordinates, altitude, and address information (Camera View only)
- **Photo Library (Add Only)**: To save enhanced photos (Camera View only)
- **Motion & Fitness**: For device orientation and tilt measurements (Camera View only)

Note: All calculation tools (Exposure Compensation, DoF, FoV) work without any permissions.

## Privacy

PhotoAssistant respects your privacy:
- Location data is only used to enhance your photos
- No data is transmitted to external servers
- All information stays on your device
- You can use calculation tools without any permissions
- Camera and location are only needed for the Camera View feature

## Data Files

PhotoAssistant includes comprehensive databases:
- **FilmReciprocityConversionFactors.json**: 40+ film stocks with accurate reciprocity models including:
  - Ilford (HP5 Plus, FP4 Plus, Pan F Plus, Delta 100/400/3200, SFX 200, XP2 Super, Ortho Plus)
  - Kodak (Tri-X 400, T-Max 100/400, Portra 160/400/800, Ektar 100, Ektachrome E100)
  - Fuji (Acros 100 II, Velvia 50/100, Provia 100F, Astia 100F)
  - Foma (Fomapan 100/200/400)
  - Rollei (Retro 80S, RPX 25/100/400)
  - Cinestill (50D, 800T)
  - Kodak Vision3 (50D, 250D, 500T)
  - Kentmere (100, 400)
- **PhotographyFilters.json**: Complete filter database with stop values
- **CapturePlane.json**: Sensor dimension specifications for various formats

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues for bugs and feature requests.

Areas for contribution:
- Additional film stocks and reciprocity data
- More filter types and variants
- Camera sensor specifications
- UI/UX improvements
- Bug fixes and optimizations

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Developer

Created by Richard Cox - 2025

## Acknowledgments

- Built with Swift and SwiftUI
- Film reciprocity data compiled from manufacturer specifications and community testing
- Optical calculations based on standard photographic formulas
- Designed for both professional and educational use

---

*PhotoAssistant - Your complete photography planning companion from exposure to composition.*