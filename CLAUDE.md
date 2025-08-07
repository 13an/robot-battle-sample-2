# CLAUDE.md
必ず日本語で回答してください。
This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

RobotBattleSampl1 is a SwiftUI iOS application that implements a real-time multiplayer robot battle game using Bluetooth connectivity. Players control robots in a shared battlefield where they can attack each other and compete in battle scenarios.

## Architecture

### Core Components

- **SwiftUI Views**: `ContentView`, `ConnectionView`, `BattleView` handle the UI navigation flow
- **SpriteKit Scene**: `BattleScene` manages the real-time game rendering, physics, and collision detection
- **Bluetooth Communication**: `BluetoothManager` handles peer-to-peer connectivity using Core Bluetooth
- **Game State Management**: `GameManager` tracks global game state, `RobotState` represents robot data
- **Factory Pattern**: `RobotFactory` creates robot sprites with different configurations

### Key Architecture Patterns

- **Singleton Pattern**: `BluetoothManager.shared` and `GameManager.shared` for global state
- **Delegate Pattern**: `BluetoothManagerDelegate` and `VirtualJoystickDelegate` for event handling
- **Message Passing**: `BluetoothMessage` enum serializes game state over Bluetooth
- **Real-time Updates**: Game loop in `BattleScene.update()` sends state every 0.1 seconds

### Data Flow

1. Player connects via `ConnectionView` → `BluetoothManager` establishes connection
2. Battle starts → `BattleScene` renders two robots (local + remote)
3. Joystick input → Local robot moves → State sent via Bluetooth
4. Remote state received → Remote robot position updated
5. Collision detection → Damage calculation → Game over conditions

## Development Commands

### Build and Run
- **Xcode**: Open `RobotBattleSampl1.xcodeproj` and use Cmd+R to build and run
- **Scheme**: Use the main app scheme for device/simulator testing

### Testing
- **Unit Tests**: Run via Xcode Test Navigator or Cmd+U
- **UI Tests**: Automated UI testing available in `RobotBattleSampl1UITests`

### Debugging
- Use Xcode's debugger and console for runtime debugging
- Bluetooth communication includes debug print statements for message tracing
- Collision detection has verbose logging for troubleshooting

## Key Technical Details

### Bluetooth Implementation
- Uses Core Bluetooth framework with custom service UUID "1234" and characteristic UUID "5678"
- One device acts as Central (scanner), other as Peripheral (advertiser)
- Message serialization handles `RobotState`, `hit`, `gameOver`, and control messages

### Game Mechanics
- Real-time collision detection between robot spikes and bodies
- Knockback physics with customizable strength (240 units default)
- HP system (100 HP, 10 damage per hit) with damage cooldown (0.5 seconds)
- Wall collision detection with haptic feedback for local player

### Coordinate System
- Battlefield is 2x screen width to accommodate split-screen view
- Camera positioning differs based on Central/Peripheral role
- Local robot positioned at 25% or 75% of battlefield width depending on role

## Important Notes

- App requires Bluetooth permissions and physical device testing (Bluetooth doesn't work in simulator)
- Uses haptic feedback (`UIImpactFeedbackGenerator`) for wall collisions and hits
- Game state synchronization relies on the Central device being authoritative for damage calculations
- SpriteKit physics body configured as edge loop for battlefield boundaries
