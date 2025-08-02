# Football Tactics Animator

**A powerful and intuitive desktop application for macOS, built with Flutter, designed for football coaches, analysts, and content creators.**  
This tool allows you to create dynamic tactical animations, perfect for team meetings, analysis videos, and social media content.

Bring your tactical ideas to life by animating player movements, drawing runs, and highlighting key areas of the pitch with a professional and easy-to-use interface.

## Features

- **Interactive Tactics Board:** A smooth, responsive canvas with a football pitch background.
- **Player & Ball Management:** Add, remove, and position home players, away players, and a ball.
- **Keyframe Animation System:** Create complex animations by setting player positions at different keyframes. The app smoothly animates the transitions between them.
- **Drawing Tools:**
    - Draw arrows with arrowheads to illustrate player runs or pass directions.
    - Highlight key tactical areas with both rectangular and oval shapes.
- **Undo & Redo:** A complete history system allows you to undo and redo any action, from moving a player to drawing a shape.
- **Save & Load Projects:** Save your entire tactical setup—including all players, their positions, keyframes, and drawings—to a `.json` file. Load projects to continue your work later.
- **Deep Customization:**
    - **Individual Players:** Select any player to change their name/number, color, or even upload a custom image to display on their token.
    - **Team Colors:** Quickly change the color for the entire home or away team at once.
- **Animation Recording:** Capture your animations frame-by-frame. *(Note: Currently captures frames; video export functionality is a future goal).*
- **Quick Cleanup:** Instantly clear all drawings from the board without affecting your player setup.

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
- **Draw on the Pitch:** Use the "Draw Arrow," "Highlight Rect," or "Highlight Oval" tools to add analysis.
- **Customize:** Click on a player to open the edit panel. Change their name, color, or upload a photo. Use the team color pickers in the edit panel to change colors for all players on a team.
- **Save Your Work:** Click "Save" to export your project to a file. Use "Load" to open it again later.

## Contributing

Contributions are welcome! If you have ideas for new features or find any bugs, please feel free to open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.