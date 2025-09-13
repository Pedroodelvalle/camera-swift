# Contributing to Camera App

So you want to contribute to our camera app? Good for you. This document tells you how to not mess things up.

## Getting Started (the basics)

### Prerequisites
- Xcode 16.4+ with iOS 18.5+ SDK (because we're not supporting ancient versions)
- macOS 15.0+ (because we're not masochists)
- Physical iOS device (camera doesn't work in simulator, shocking I know)
- Basic knowledge of Swift, SwiftUI, and AVFoundation (if you don't know these, maybe start with a simpler project)

### Development Setup
1. Fork the repository (obviously)
2. Clone your fork: `git clone https://github.com/yourusername/camera-swift.git`
3. Open `Camera.xcodeproj` in Xcode
4. Select a physical device (camera features don't work in simulator, remember?)
5. Build and run the project

## Areas for Contribution (what we actually need)

### High Priority (the important stuff)
- Bug fixes for camera functionality (because bugs are amateur hour)
- Performance optimizations for video recording (because nobody likes laggy video)
- Accessibility improvements (because we're not monsters)
- Unit tests for core functionality (because untested code is garbage)

### Medium Priority (the nice-to-have stuff)
- New video filters using Core Image (because more filters = more fun)
- Additional teleprompter features (because reading from paper is for cavemen)
- UI/UX enhancements (because ugly interfaces are amateur hour)
- Documentation improvements (because nobody reads docs anyway)

### Low Priority (the "maybe someday" stuff)
- Snap Camera Kit integration improvements (because AR is cool but not essential)
- Advanced camera controls (because most people can't handle advanced features)
- Export format options (because HEVC is good enough for most people)

## Development Guidelines (how not to write garbage code)

### Code Style
- Follow Swift API Design Guidelines (because Apple knows what they're doing)
- Use SwiftUI for UI components (because UIKit is for boomers)
- Implement MVVM pattern for new features (because spaghetti code is for amateurs)
- Add documentation comments for public APIs (because nobody can read your mind)

### Commit Messages
Use conventional commit format (because random commit messages are amateur hour):
```
feat: add new video filter support
fix: resolve camera permission issue
docs: update README with new features
test: add unit tests for teleprompter
```

### Pull Request Process
1. Create a feature branch: `git checkout -b feature/amazing-feature`
2. Make your changes following our guidelines
3. Test thoroughly on a physical device (because camera doesn't work in simulator)
4. Update documentation if needed
5. Submit a pull request with a clear description

### Testing Requirements
- Test on physical device (camera features require hardware, remember?)
- Test different iOS versions (18.5+)
- Test various device models (iPhone/iPad compatibility)
- Verify camera permissions work correctly

## Bug Reports (when things go wrong)

When reporting bugs, include:
- iOS version and device model (because "it doesn't work" is not helpful)
- Steps to reproduce the issue (because we can't read your mind)
- Expected vs actual behavior (because "it's broken" is not descriptive)
- Screenshots or videos if applicable (because visual evidence is better than words)
- Console logs if relevant (because error messages are actually useful)

## Feature Requests (when you want something new)

For new features, provide:
- Clear description of the feature (because "make it better" is not specific)
- Use case and benefits (because "it would be cool" is not a valid reason)
- Mockups or examples if applicable (because visual aids are helpful)
- Technical considerations if known (because we need to know if it's actually possible)

## Code Architecture (how we organize things)

### Key Components
- `CameraViewModel` - Main app state management (doesn't suck)
- `CaptureSessionController` - Camera session handling (actually works)
- `TeleprompterOverlay` - Teleprompter UI and logic (you can drag it around)
- `SegmentedRecorder` - Video recording management (because losing footage is amateur hour)

### Adding New Features
1. Create feature branch from `main`
2. Implement in appropriate component
3. Add unit tests for business logic
4. Update documentation
5. Test on multiple devices

## Technical Guidelines (how to not break things)

### Camera Implementation
- Use AVFoundation for all camera operations (because we're not reinventing the wheel)
- Handle permissions gracefully (because crashes are amateur hour)
- Support orientation changes (because upside-down videos are amateur hour)
- Implement proper error handling (because silent failures are garbage)

### UI/UX Standards
- Follow iOS Human Interface Guidelines (because Apple knows what they're doing)
- Use SwiftUI for modern UI components (because UIKit is for boomers)
- Implement accessibility features (because we're not monsters)
- Support Dark Mode when applicable (because light mode is for peasants)

### Performance Considerations
- Minimize memory usage during video recording (because crashes are amateur hour)
- Optimize for battery life (because nobody likes dead phones)
- Handle background/foreground transitions (because apps shouldn't crash when you switch)
- Use efficient video codecs (HEVC preferred, because H.264 is for peasants)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Getting Help

- Create an issue for questions or problems
- Join discussions in GitHub Discussions
- Review existing issues before creating new ones (because duplicate issues are amateur hour)

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes for significant contributions
- GitHub contributors page

Thanks for contributing to make our Camera App better!