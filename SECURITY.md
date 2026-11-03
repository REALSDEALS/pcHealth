# Security Policy

## Supported versions

Only the latest release gets fixes.

| Platform | Minimum                        | Tested on                      |
|----------|--------------------------------|--------------------------------|
| Windows  | Windows 10 22H2 (build 19045)  | Windows 11 25H2 (build 26200)  |
| Linux    | Python 3.11                    | Current Fedora, Ubuntu, Arch   |

The Windows CLI refuses to start below build 19045, the oldest build WinUI 3
supports. Windows 10 22H2 itself no longer gets security updates from
Microsoft (end of support: October 2025).

## Verifying a download

Release files are not code-signed yet, so Windows SmartScreen shows them as
coming from an unknown publisher. Each release has a `SHA256SUMS.txt`; compare
it with:

```powershell
Get-FileHash .\pcHealth-2.0.0-win-x64.msi -Algorithm SHA256
```

Only download pcHealth from
[github.com/REALSDEALS/pcHealth/releases](https://github.com/REALSDEALS/pcHealth/releases).

## Reporting a vulnerability

1. Do not open a public issue.
2. Report it through a
   [GitHub Security Advisory](https://github.com/REALSDEALS/pcHealth/security/advisories/new).
3. Describe the problem, the affected files and how to reproduce it.

You can expect a first reply within 7 days.

## Scope

pcHealth runs with administrator rights on Windows and asks for root on Linux.
It runs SFC and DISM, resets the network stack, rewrites EFI boot files and
installs software. Treat anything that could lead to privilege escalation,
data loss or an unintended change to the system as a security issue. That
includes the build and release workflows in `.github/workflows`.
