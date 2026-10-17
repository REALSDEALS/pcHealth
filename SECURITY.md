# Security Policy

## Supported Versions

The table below lists each supported platform, its recommended and hard minimum OS version, and its current support status within this project.

| Platform | Minimum                       | Recommended                   | Status                 |
|----------|-------------------------------|-------------------------------|------------------------|
| Windows  | Build 19045 (Windows 10 22H2) | Build 26200 (Windows 11 25H2) | ✅ Actively maintained |
| Linux    | Kernel 6.0                    | Current stable                | ✅ Actively maintained |

Below the minimum pcHealth exits immediately. Build 19045 is where WinUI 3 stops rendering, so the CLI and the GUI share one floor; supported builds older than the recommended one run normally and get a note on start.

Security fixes are shipped for the recommended build first. Windows 10 22H2 reached end of life in October 2025 and receives no OS security updates from Microsoft — pcHealth running there does not change that. Pre-UEFI systems are out of scope: Boot Repair detects BIOS/MBR firmware and refuses rather than carrying MBR/CSM repair paths that cannot be tested on any supported target.

- Windows release info: https://learn.microsoft.com/en-us/windows/release-health/release-information
- Windows 11 release info: https://learn.microsoft.com/en-us/windows/release-health/windows11-release-information
- Linux kernel releases: https://www.kernel.org/

---

## Future Platform Support

| Platform    | Status      | Notes                                      |
|-------------|-------------|--------------------------------------------|
| Linux (GUI) | Planned     | Targeting parity with the Windows CLI      |

---

## Reporting a Vulnerability

If you discover a security vulnerability in any part of this project (scripts, documentation, or CI):

1. **Do not open a public issue.**
2. Report it privately via the [GitHub Security Advisory](https://github.com/REALSDEALS/pcHealth/security/advisories/new) feature.
3. Include a clear description of the vulnerability, the affected file(s), and steps to reproduce.

We aim to respond within **7 days** and will coordinate a fix and disclosure timeline with the reporter.

---

## Scope

These scripts run with administrator privileges and interact with the OS directly (SFC, DISM, network stack, UEFI boot files). Please treat any issues that could lead to privilege escalation, data loss, or unintended system modification as security-relevant.
