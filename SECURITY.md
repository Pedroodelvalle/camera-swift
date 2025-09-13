# Security Policy

## Supported Versions (the ones we actually care about)

We release patches for security vulnerabilities in the following versions:

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability (when you find something bad)

We take security bugs seriously. We appreciate your efforts to responsibly disclose your findings, and will make every effort to acknowledge your contributions.

### How to Report

**Please do not report security vulnerabilities through public GitHub issues.** (Because that would be amateur hour)

Instead, please report them via email to: [pedrodv@appconty.com]

### What to Include

Please include the following information in your report:

- **Type of issue** (e.g. buffer overflow, SQL injection, cross-site scripting, etc.)
- **Full paths of source file(s)** related to the manifestation of the issue
- **Location** of the affected source code (tag/branch/commit or direct URL)
- **Special configuration** required to reproduce the issue
- **Step-by-step instructions** to reproduce the issue
- **Proof-of-concept or exploit code** (if possible)
- **Impact** of the issue, including how an attacker might exploit it

### What to Expect

After you submit a report, we will:

1. **Confirm receipt** of your vulnerability report within 48 hours
2. **Provide regular updates** on our progress
3. **Credit you** in our security advisories (unless you prefer to remain anonymous)

## Security Considerations (the important stuff)

### Camera App Specific

This app handles sensitive user data including:

- **Camera Access** - Direct access to device camera (obviously)
- **Microphone Access** - Audio recording capabilities (because silent videos are boring)
- **Photo Library Access** - Reading and writing to user's photo library
- **Video Content** - User-generated video content

### Best Practices

- **Always test on physical devices** - Camera features don't work in simulator (shocking I know)
- **Handle permissions gracefully** - App requests minimal necessary permissions (because asking for everything is amateur hour)
- **Secure data storage** - Videos are stored locally using standard iOS security (because cloud storage is for peasants)
- **No network transmission** - All processing happens locally on device (because privacy matters)

### Privacy

- **No data collection** - App doesn't collect or transmit user data (because we're not evil)
- **Local processing only** - All video processing happens on device (because cloud processing is for peasants)
- **Standard iOS permissions** - Uses standard iOS permission system (because Apple knows what they're doing)

## Security Measures (how we protect you)

### Code Security
- **Regular dependency updates** - Keep dependencies up to date (because outdated dependencies are amateur hour)
- **Code reviews** - All changes require review (because nobody writes perfect code)
- **Automated security scanning** - CI/CD includes security checks (because manual scanning is for masochists)

### Runtime Security
- **Permission validation** - Verify permissions before camera access (because assuming permissions is amateur hour)
- **Input validation** - Validate all user inputs (because trusting user input is amateur hour)
- **Error handling** - Secure error handling without information leakage (because error messages shouldn't help attackers)

## Responsible Disclosure Timeline (how long things take)

- **Day 0** - Initial report received
- **Day 1-2** - Confirmation and triage
- **Day 3-7** - Initial assessment and reproduction
- **Day 8-30** - Fix development and testing
- **Day 31-45** - Release and disclosure

*Timeline may vary based on severity and complexity of the issue.*

## Hall of Fame (the people who helped us)

We maintain a security hall of fame to recognize security researchers who have helped improve our application's security.

### Contributors
- *No contributors yet - be the first!*

## Contact

For security-related questions or concerns, please contact:

- **Email**: [pedrodv@appconty.com]
- **PGP Key**: [Your PGP key fingerprint if applicable]

---

**Thank you for helping keep our users safe!**