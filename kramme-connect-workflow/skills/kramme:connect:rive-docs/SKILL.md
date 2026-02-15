---
name: kramme:connect:rive-docs
description: Official Rive documentation covering editor, scripting, runtimes, data binding, and feature support. Primary focus on iOS/mobile integration.
user-invocable: false
disable-model-invocation: false
---

# Rive Documentation

This skill contains official Rive documentation for the Rive animation platform.

## Quick Reference

### Rive File Extension
- `.riv` - Compiled Rive animation file

### Runtime Packages

| Platform | Package | GitHub |
|----------|---------|--------|
| Web (Canvas) | `@rive-app/canvas` | [rive-wasm](https://github.com/rive-app/rive-wasm) |
| Web (WebGL) | `@rive-app/webgl` | [rive-wasm](https://github.com/rive-app/rive-wasm) |
| React | `@rive-app/react-canvas` | [rive-react](https://github.com/rive-app/rive-react) |
| React Native | `rive-react-native` | [rive-react-native](https://github.com/rive-app/rive-react-native) |
| iOS/macOS | `RiveRuntime` (CocoaPods/SPM) | [rive-ios](https://github.com/rive-app/rive-ios) |
| Android | `app.rive:rive-android` | [rive-android](https://github.com/rive-app/rive-android) |
| Flutter | `rive` | [rive-flutter](https://github.com/rive-app/rive-flutter) |

### State Machine Input Types

1. **Trigger** - Fire once, auto-resets
2. **Boolean** - true/false state
3. **Number** - Numeric value for conditions

---

# 1. INTRODUCTION & GETTING STARTED

Source: https://rive.app/docs/getting-started/introduction

## Welcome to Rive

Welcome to the Rive Docs. We've split this documentation into the sub-sections below. If you can't find the information you're looking for or have questions for us, join us on Twitter, Discord, or contact us by filling out this form.

## Quick Start Tips

- Create an account and try out the Rive Editor
- Design and animate using the Rive docs or watch tutorial videos in Rive 101
- Jump into adding Rive to apps and games via app runtimes and game runtime docs
- Explore use cases with examples, blogs, and tutorials

## Explore Rive - Three Main Paths

### 1. Interface Overview
Start designing and animating in Rive. The editor enables creation, animation design, and state machine logic before exporting via runtimes.

### 2. App Runtimes
Open-source libraries for real-time rendering across Web, iOS, Android, Flutter, React Native, and more.

### 3. Game Runtimes
Open-source libraries for real-time rendering in Unity, Unreal, and Defold with custom engine integration.

## Key Documentation Links

- [Best Practices](/docs/getting-started/best-practices)
- [Quick Links](/docs/getting-started/quick-links)
- [Interface Overview](/docs/editor/interface-overview/overview)
- [Scripting Getting Started](/docs/scripting/getting-started)
- [App Runtimes Getting Started](/docs/runtimes/getting-started)
- [Game Runtimes Overview](/docs/game-runtimes/game-runtimes/game-runtimes)
- [Community](https://community.rive.app)
- [Marketplace Overview](/docs/community/marketplace-overview)

---

# 2. EDITOR INTERFACE OVERVIEW

Source: https://rive.app/docs/editor/interface-overview/overview

## Main Panels

Rive's interface is organized into main panels, showing only what's needed when it's needed.

### Toolbar
The toolbar displays available tools for creating, rigging, and manipulating stage items. It includes options to customize file appearance, set the main artboard, and export or share files.

**More info:** [Toolbar](/docs/editor/interface-overview/toolbar)

### Hierarchy
All objects, assets, controls, and animations comprising a file appear here. The hierarchy also contains the Assets Panel and Data Panel.

**More info:** [Hierarchy](/docs/editor/interface-overview/hierarchy)

### Inspector
Allows adjustment of properties for selected objects—whether on the stage, timeline, or state machine. Properties change dynamically based on context.

**More info:** [Inspector](/docs/editor/interface-overview/inspector)

### Stage
The central canvas area bounded by the Toolbar, Hierarchy, and Inspector. This is where artboards are created as design and animation foundations.

**More info:** [Stage](/docs/editor/interface-overview/stage)

### Timeline
Appears at the bottom when entering animate mode. Enables creating states, accessing playback controls, and setting keyframes. Select timelines from the left-hand list to switch between animations for the active artboard.

**More info:** [Timeline](/docs/editor/animate-mode/timeline)

### State Machine Graph
Replaces the timeline when a state machine is selected, providing the workspace for state machine development.

**More info:** [State Machine](/docs/editor/state-machine/state-machine)

---

# 3. SCRIPTING

Source: https://rive.app/docs/scripting/getting-started

## Overview

"Code, animation, and interaction all in one Editor." Scripting enables developers to combine code, design, and animation within a unified collaborative environment.

## Why Luau?

Rive uses Luau as its scripting language. Luau is a fast, small, safe, gradually typed embeddable scripting language derived from Lua.

## Key Topics

### Creating Scripts
Instructions for initiating new scripts in Rive.
**More info:** [Creating Scripts](/docs/scripting/creating-scripts)

### Protocols
Available script types and their purposes.
**More info:** [Protocols Overview](/docs/scripting/protocols)

### Inputs
Connecting scripts to inputs and data sources.
**More info:** [Script Inputs](/docs/scripting/script-inputs)

### Debugging
Tools for troubleshooting scripts.
**More info:** [Debug Panel](/docs/scripting/debugging/debug-panel)

### AI Agent
Using AI to generate and modify scripts.
**More info:** [Editor AI Agent](/docs/editor/ai-agent)

## Related Links

- [Scripting Demos](/docs/scripting/demos)
- [Why Scripting Runs on Luau](https://rive.app/blog/why-scripting-runs-on-luau)

---

# 4. APP RUNTIMES

Source: https://rive.app/docs/runtimes/getting-started

## Overview

"Run Rive on your platform of choice." The Rive runtimes are open-source libraries enabling developers to load and control animations across apps, games, and websites.

## Documentation Organization

### 1. Installation & Getting Started
Platform-specific setup instructions

### 2. Graphic Control & Interaction
Runtime management techniques

## Available Platforms

| Platform | Package/Library |
|----------|-----------------|
| Web (JS) | `@rive-app/canvas`, `@rive-app/canvas-lite`, `@rive-app/webgl` |
| React | `@rive-app/react-canvas`, `@rive-app/react-canvas-lite`, `@rive-app/react-webgl` |
| React Native | `rive-react-native` |
| Apple (iOS/macOS) | Swift Package Manager or CocoaPods |
| Android | Maven distribution |
| Flutter | pub.dev (`rive`) |
| C++ | Mac/Linux/Windows support |
| C# (.NET) | UWP and WinUI support |

## Runtime Features

### Artboards
Display control at runtime.
**More info:** [Artboards](/docs/runtimes/artboards)

### Layout
Artboard fit and alignment management.
**More info:** [Layout](/docs/runtimes/layout)

### State Machine Playback
State machine control and input interaction.
**More info:** [State Machine Playback](/docs/runtimes/state-machines)

### Data Binding (CRITICAL FOR iOS)
Dynamic content updates (text, colors, images, lists).
**More info:** [Data Binding](/docs/runtimes/data-binding)

### Loading Assets
Out-of-band asset loading (images, fonts, audio).
**More info:** [Loading Assets](/docs/runtimes/loading-assets)

### Caching a Rive File
Performance optimization through file reuse.
**More info:** [Caching a Rive File](/docs/runtimes/caching-a-rive-file)

### Choose a Renderer
Renderer selection guidance.
**More info:** [Choose a Renderer](/docs/runtimes/choose-a-renderer)

### Rive Events
Handle events from Rive animations.
**More info:** [Rive Events](/docs/runtimes/rive-events)

### Playing Audio
Audio playback support.
**More info:** [Playing Audio](/docs/runtimes/playing-audio)

## Official Runtime GitHub Repositories

- **Web**: https://github.com/rive-app/rive-wasm
- **React**: https://github.com/rive-app/rive-react
- **Apple (iOS)**: https://github.com/rive-app/rive-ios
- **Android**: https://github.com/rive-app/rive-android
- **Flutter**: https://github.com/rive-app/rive-flutter
- **C++**: https://github.com/rive-app/rive-cpp
- **React Native**: https://github.com/rive-app/rive-react-native

## Handling .riv Files in Git

When version controlling `.riv` files with Git, add a `.gitattributes` file:

```
*.riv binary
```

This prevents line-ending corruption across platforms (CRLF vs LF).

## Licensing

All official runtimes are open-source and licensed under the MIT License. Free for personal and commercial applications.

---

# 5. FEATURE SUPPORT MATRIX

Source: https://rive.app/docs/feature-support

This documents runtime support for features added to the Rive editor.

**IMPORTANT:** Always use the latest version of the runtimes to take advantage of bug fixes and new features.

## iOS/Apple Runtime Version Requirements

| Feature | Apple iOS Version |
|---------|-------------------|
| Scripting | v6.13.0+ |
| Data Binding (Lists, Images, Artboards) | v6.11.0+ |
| Right to Left Text | 6.7.4+ |
| Text Follow Path | 6.7.4+ |
| Data Binding (General) | 6.8.0+ |
| Vector Feathering | 6.6.0+ |
| N-Slicing | 6.4.0+ |
| Layouts | 6.3.0+ |
| Fallback Fonts | 6.1.0+ |
| Nested Text | 6.1.0+ |
| Nested Inputs | 5.13.2+ |
| Randomization | 5.11.5+ |
| Audio | 5.11.5+ |
| Nested Events | 5.6.0+ |
| Out-of-band Assets | 5.7.0+ |
| Events | 5.3.1+ |
| Text | 5.1.5+ |
| Follow Path | 4.0.5+ |
| Interpolation on States | 4.0.4+ |
| Joysticks | 4.0.1+ |
| Solos | 3.1.9+ |
| Speed on States | 3.1.7+ |
| Graph Editor | 3.1.3+ |
| Listeners | 2.0.21+ |
| Mesh Deformation | 1.0.18+ |
| Caching | Supported |
| Raster Assets | 1.0.1+ |

## React Native Version Requirements

| Feature | React Native Version |
|---------|---------------------|
| Scripting | v0.1.5+ (new) / v9.8.0+ (legacy) |
| Data Binding (Lists, Images, Artboards) | v0.1.4+ (new) / not supported (legacy) |
| Data Binding (General) | v0.1.4+ (new) / v9.3.0+ (legacy) |
| Vector Feathering | v0.1.4+ (new) / v9.0.0+ (legacy) |
| N-Slicing | v0.1.4+ (new) / v8.2.0+ (legacy) |
| Layouts | v0.1.4+ (new) / v8.1.0+ (legacy) |
| Nested Text | v0.1.4+ (new) / v5.8.2+ (legacy) |
| Nested Inputs | v0.1.4+ (new) / v7.2.0+ (legacy) |
| Audio | v0.1.4+ (new) / v7.0.3+ (legacy) |
| Events | v0.1.4+ (new) / v6.1.0+ (legacy) |
| Text | v0.1.4+ (new) / v6.0.3+ (legacy) |
| Listeners | v0.1.4+ (new) / v3.0.38+ (legacy) |

## Android Version Requirements

| Feature | Android Version |
|---------|-----------------|
| Scripting | v11.1.0+ |
| Data Binding (Lists, Images, Artboards) | v10.4.0+ |
| Data Binding (General) | 10.1.0+ |
| Vector Feathering | 10.0.0+ |
| N-Slicing | 9.12.0+ |
| Layouts | 9.10.0+ |
| Fallback Fonts | 9.7.0+ |
| Nested Text | 9.8.0+ (Legacy only) |
| Nested Inputs | 9.4.2+ (Legacy only) |
| Audio | 9.3.5+ |
| Events | 8.4.0+ (Legacy only) |
| Text | 8.1.3+ |

## Flutter Version Requirements

| Feature | Flutter Version |
|---------|-----------------|
| Scripting | 0.14.1 |
| Data Binding | 0.14.0-dev.1 |
| Vector Feathering | 0.14.0-dev.1 |
| Layouts | 0.14.0-dev.1 |
| Events | 0.11.17+ |
| Text | 0.11.14+ |

## Special Notes

### Vector Feathering
Requires **Rive Renderer**. See [choosing a renderer guide](/docs/runtimes/choose-a-renderer).

### React Native
Starting with version 3.0.0, React Native requires minimum iOS 14.0 support.

### Mesh Performance
For web-based runtimes displaying meshes:
- Meshes consuming larger screen areas become resource-heavy
- For Firefox mesh display, `@rive-app/webgl` provides superior performance

---

# 6. GAME RUNTIMES

Source: https://rive.app/docs/game-runtimes/game-runtimes/game-runtimes

## Overview

"Rive supports popular game engines and is easy to integrate with custom engines."

## Available Game Runtimes

### Unity
Integration tool for bringing Rive files into Unity projects.
**More info:** [Unity Plugin](/docs/game-runtimes/unity/unity)

### Unreal
Support for Unreal Engine integration.
**More info:** [Unreal Plugin](/docs/game-runtimes/unreal/unreal)

### Defold
Extension for integrating Rive files with Defold game engine.
**More info:** [Defold Extension](/docs/game-runtimes/defold)

## Getting Started with Game Runtimes

1. Learn foundational skills in the Rive Editor
2. Create rigged and interactive graphics
3. Export for runtime: [Exporting for Runtime](/docs/editor/exporting/exporting-for-runtime)
4. Integrate with your chosen game engine

---

# KEY DOCUMENTATION LINKS INDEX

## Editor
- [Interface Overview](/docs/editor/interface-overview/overview)
- [Toolbar](/docs/editor/interface-overview/toolbar)
- [Hierarchy](/docs/editor/interface-overview/hierarchy)
- [Inspector](/docs/editor/interface-overview/inspector)
- [Stage](/docs/editor/interface-overview/stage)
- [Timeline](/docs/editor/animate-mode/timeline)
- [State Machine](/docs/editor/state-machine/state-machine)
- [Data Binding Overview](/docs/editor/data-binding/overview)
- [Layouts Overview](/docs/editor/layouts/layouts-overview)
- [N-Slicing](/docs/editor/layouts/n-slicing)
- [Components](/docs/editor/fundamentals/components)
- [AI Agent](/docs/editor/ai-agent)
- [Exporting for Runtime](/docs/editor/exporting/exporting-for-runtime)

## Scripting
- [Getting Started](/docs/scripting/getting-started)
- [Creating Scripts](/docs/scripting/creating-scripts)
- [Protocols](/docs/scripting/protocols)
- [Script Inputs](/docs/scripting/script-inputs)
- [Debug Panel](/docs/scripting/debugging/debug-panel)
- [Demos](/docs/scripting/demos)

## Runtimes
- [Getting Started](/docs/runtimes/getting-started)
- [Artboards](/docs/runtimes/artboards)
- [Layout](/docs/runtimes/layout)
- [State Machines](/docs/runtimes/state-machines)
- [Data Binding](/docs/runtimes/data-binding)
- [Loading Assets](/docs/runtimes/loading-assets)
- [Fonts](/docs/runtimes/fonts)
- [Caching a Rive File](/docs/runtimes/caching-a-rive-file)
- [Playing Audio](/docs/runtimes/playing-audio)
- [Logging](/docs/runtimes/logging)
- [Choose a Renderer](/docs/runtimes/choose-a-renderer)
- [Rive Events](/docs/runtimes/rive-events)
- [Text](/docs/runtimes/text)
- [Nested Inputs](/docs/runtimes/inputs#nested-inputs)
- [Runtime Sizes](/docs/runtimes/runtime-sizes)
- [Demos](/docs/runtimes/demos)
- [File Format](/docs/runtimes/advanced-topic/format)

## Game Runtimes
- [Overview](/docs/game-runtimes/game-runtimes)
- [Unity](/docs/game-runtimes/unity/unity)
- [Unreal](/docs/game-runtimes/unreal/unreal)
- [Defold](/docs/game-runtimes/defold)

## Other
- [Feature Support](/docs/feature-support)
- [Best Practices](/docs/getting-started/best-practices)
- [Quick Links](/docs/getting-started/quick-links)
- [Tutorials](/docs/tutorials/learn-rive)
- [Community](https://community.rive.app)
- [Marketplace](/docs/community/marketplace-overview)

---

# HOW TO ADD MORE DOCUMENTATION

When additional Rive docs need to be added:

1. Fetch the URL with WebFetch
2. Extract all content and internal links
3. Add a new section below with:
   - Source URL
   - Full content
   - Related links

---

# ADDITIONAL DOCUMENTATION

<!-- New documentation sections will be added below this line -->

---
