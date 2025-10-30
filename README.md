# Football Tactics Animator

**A powerful and intuitive desktop application for macOS, built with Flutter, designed for football coaches, analysts, and content creators.**
This tool allows you to create dynamic tactical animations, perfect for team meetings, analysis videos, and social media content.

Bring your tactical ideas to life by animating player movements, drawing runs, and highlighting key areas of the pitch with a professional and easy-to-use interface.

## Features

### 🎬 Advanced Animation System (NEW!)
- **High-Quality Recording:** Export animations as PNG image sequences at up to 60 FPS
- **Configurable Settings:** Adjust FPS (15-60) and transition duration (0.5-5.0s) per your needs
- **Professional Output:** 3x resolution capture for crisp, broadcast-quality frames
- **Unlimited Keyframes:** Create complex multi-step animations with smooth interpolation
- **Real-time Preview:** Play animations before recording to perfect your tactics

### ⚽ Interactive Tactics Board
- **Smooth Canvas:** Responsive football pitch with full/half field layouts
- **Drag & Drop:** Intuitive player and ball positioning
- **Visual Feedback:** Selected players highlighted in yellow
- **High Performance:** Optimized rendering for smooth interactions

### 👥 Player & Ball Management
- **Two Teams:** Distinct home (red) and away (blue) players
- **Custom Images:** Upload player photos for realistic boards
- **Flexible Sizing:** Adjust player token sizes individually or by team
- **Custom Colors:** Set primary, secondary, and text colors for each player

### 🎨 Professional Drawing Tools
- **Straight Arrows:** Show direct player runs and passing lanes with arrowheads
- **Curved Arrows (Left/Right):** Display curved movements, runs around defenders, or arcing passes
- **Rectangular Highlights:** Mark zones, channels, and areas of play
- **Oval Highlights:** Emphasize positions and danger areas
- **Quick Clear:** Remove all drawings with one click

### 💾 Project Management
- **Save Projects:** Export complete tactical setups to JSON files
- **Load Projects:** Resume work on saved animations
- **Undo/Redo:** Full history system for all actions
- **State Preservation:** Maintains all players, positions, keyframes, and drawings

### 🎯 Keyframe Animation
- **Easy Creation:** Add keyframes with current board state
- **Visual Timeline:** Thumbnail previews of each keyframe
- **Update & Delete:** Modify existing keyframes anytime
- **Smooth Transitions:** Eased interpolation between keyframes

### 📊 Export & Sharing
- **Fullscreen Recording Mode:** Clean, distraction-free view for screen recording
- **Auto-Hide Controls:** Double-click to show/hide controls during recording
- **Side-Positioned Controls:** Exit and play/pause buttons slide in from the right
- **Screen Recording Ready:** Optimized for macOS screen capture (Cmd+Shift+5)
- **Professional Presentation:** No UI clutter in your recordings

## Getting Started

Follow these instructions to get the project running on your local machine.

### Prerequisites

- You must have the Flutter SDK installed on your macOS machine.
- You need Xcode installed to configure the project and build the app.

### Setup Instructions

1. **Clone the Repository:**
    ```sh
    git clone https://github.com/MS-Teja/footballTacticsAnimator.git
    cd football-tactics-animator
    ```

2. **Add Dependencies:**
   This project uses several packages for its functionality. Open the `pubspec.yaml` file and ensure the following dependencies are listed:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      image_picker: ^1.0.7
      flutter_colorpicker: ^1.0.3
      file_picker: ^6.2.0
      cupertino_icons: ^1.0.2
    ```
   Then, run the following in your terminal to install them:
    ```sh
    flutter pub get
    ```

3. **Add Image Asset:**
    - Create a new folder named `assets` in the root of your project.
    - Place your football pitch background image inside this folder (e.g., `assets/football_field.jpg`).
    - In `pubspec.yaml`, add the asset path so Flutter knows where to find it:
      ```yaml
      flutter:
        uses-material-design: true
        assets:
          - assets/football_field.jpg
      ```

4. **Configure macOS App Sandbox (Crucial for Save/Load):**
    - Open the macOS part of the project in Xcode by running:
      ```sh
      open macos/Runner.xcworkspace
      ```
    - In Xcode, click on the Runner project, then the Runner target, and go to the **Signing & Capabilities** tab.
    - Click **+ Capability** and add **App Sandbox**.
    - In the new App Sandbox section, find **File Access > User Selected File** and set its permission to **Read/Write**.

5. **Run the App:**
   Now, you can run the application from your code editor or via the terminal:
    ```sh
    flutter run -d macos
    ```

## How to Use

- **Add Players:** Use the "Add Home" and "Add Away" buttons to place players on the pitch.
- **Position Players:** Click and drag any player or the ball to your desired starting position.
- **Create an Animation:**
    1. Set up your initial formation.
    2. Click "Add Keyframe".
    3. Move the players to their next positions.
    4. Click "Add Keyframe" again.
    5. Repeat to build your sequence.
- **Play Animation:** Click the "Play" button to see your tactical movement come to life.
- **Draw on the Pitch:** Use straight arrows, curved arrows (left/right), rectangular highlights, or oval highlights to add analysis.
- **Record with Screen Capture:**
    1. Click the fullscreen icon to enter recording mode.
    2. Use macOS screen recording (Cmd+Shift+5) to capture your animation.
    3. Double-click to show controls, then click play to start animation.
    4. Controls auto-hide after 3 seconds for clean recording.
    5. Click fullscreen exit icon to return to editing mode.
- **Customize:** Click on a player to open the edit panel. Change their name, color, or upload a photo. Use the team color pickers in the edit panel to change colors for all players on a team.
- **Save Your Work:** Click "Save" to export your project to a file. Use "Load" to open it again later.

## Contributing

Contributions are welcome! If you have ideas for new features or find any bugs, please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.