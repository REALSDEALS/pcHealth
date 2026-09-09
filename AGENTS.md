# AI Coding Assistant Guide — pcHealth

> If you are an AI assistant (Claude, Copilot, Cursor, etc.), read this file
> before making any changes to this repository.
> Inspired by: https://github.com/torvalds/linux/blob/master/Documentation/process/coding-assistants.rst

---

## Project Structure

This project has **two separate codebases**. Know which one you're in:

| Part | Location | Language | Purpose |
|---|---|---|---|
| CLI | `src/CLI/` | PowerShell 7 + Bash | Cross-platform terminal health tool |
| GUI | `src/GUI/pcHealth/` | C# / WinUI 3 (.NET) | Windows-only graphical frontend |

Do not mix patterns between them. C# APIs do not belong in PowerShell scripts and vice versa.

---

## Working Style: Caveman First

This project follows the **caveman approach**:
https://github.com/JuliusBrussee/caveman

- Make **small, focused changes** — one concern per commit
- Prefer **boring, readable solutions** over clever abstractions
- **Do not refactor working code** unless there is a clear reason
- If you're unsure, leave a `// TODO(AI): ...` comment and move on
- Build must pass after every commit

---

## Language & Comments

- Code and comments are written in **English**
- Comments explain **WHY**, not WHAT
- No obvious comments (`// increment i` on `i++` is noise)

---

## Deprecated APIs — Avoid These

### C# / .NET (GUI — `src/GUI/`)

The GUI uses WinUI 3 on .NET. Replace legacy APIs with their modern equivalents:

| Deprecated / Avoid | Preferred | Why |
|---|---|---|
| `System.Management.ManagementObjectSearcher` | `Microsoft.Management.Infrastructure` (`CimSession`, `CimInstance`) | `System.Management` uses DCOM under the hood — slow, Windows-only, and discouraged in modern .NET. The CIM/MI library uses WSMan and is the Microsoft-recommended replacement. |
| `global using System.Management` | Do not reintroduce — the codebase is fully migrated to `CimSession.QueryInstances()` | The global using pulls in the entire legacy namespace project-wide |
| `Process.Start()` without `CancellationToken` support | Wrap with `async`/`await` and pass a `CancellationToken` where the call can hang | Fire-and-forget `Process.Start` cannot be cancelled or awaited cleanly |
| `catch { }` (empty catch) | `catch (Exception ex) { /* log ex */ }` | Silent swallowing hides real failures; always log or surface |
| `catch (Exception)` (bare) | Catch specific types: `IOException`, `UnauthorizedAccessException`, `COMException`, etc. | Overly broad catches mask bugs |
| Raw string path building (`dir + "\\" + file`) | `Path.Combine(dir, file)` | Breaks on path edge cases; `Path.Combine` handles separators correctly |
| `Microsoft.Win32.Registry.OpenSubKey()` without null-check | Always null-check the returned key before accessing it | Registry keys may not exist on all Windows builds |

**CIM migration example** — replace this:
```csharp
// OLD — System.Management (DCOM, legacy)
using var searcher = new ManagementObjectSearcher(
    "SELECT Caption FROM Win32_OperatingSystem");
foreach (ManagementObject obj in searcher.Get())
    Console.WriteLine(obj["Caption"]);
```

With this:
```csharp
// NEW — Microsoft.Management.Infrastructure (CIM/WSMan, modern)
using var session = CimSession.Create(null); // null = local machine
foreach (var instance in session.QueryInstances(
    "root/cimv2", "WQL", "SELECT Caption FROM Win32_OperatingSystem"))
    Console.WriteLine(instance.CimInstanceProperties["Caption"].Value);
```

### PowerShell 7 (CLI — `src/CLI/`)

| Deprecated / Avoid | Preferred | Why |
|---|---|---|
| `Get-WmiObject` | `Get-CimInstance` | WMI over DCOM; removed from PowerShell 6+. CIM is the modern standard |
| `wmic.exe` via `Invoke-Expression` or `Start-Process` | `Get-CimInstance` | `wmic.exe` is **removed** in Windows 11 25H2 |
| `Invoke-Expression` (`iex`) | Explicit script blocks | Arbitrary code execution; hard to audit and dangerous |
| `$ErrorActionPreference = 'SilentlyContinue'` set globally | `-ErrorAction SilentlyContinue` per call | Global silencing hides real errors in unrelated code |
| `Write-Host` for data/pipeline output | `Write-Output` or `return` | `Write-Host` bypasses the pipeline; only use it for user-facing display text |
| String concatenation for paths (`"$dir\$file"`) | `Join-Path $dir $file` | Handles both `\` and `/` correctly on Windows and Linux |
| Bare `ls`, `cat`, `cp` aliases | `Get-ChildItem`, `Get-Content`, `Copy-Item` | Aliases are unreliable in strict or non-interactive environments |
| `(& somecmd args).Trim()` | `Get-PcCommandOutput 'somecmd' @('args')` | A missing or silent command returns `$null`, and `.Trim()` on it throws — which aborts the whole tool, not just that field. On Linux this is routine: no systemd in containers and WSL, no `mokutil`/`lspci` on minimal installs |
| `sudo <cmd>` inside a tool | Call the command directly | pcHealth already exits unless it is running as root on Linux. Re-elevating is a no-op where sudo exists and a hard failure where it does not. `sudo -u <user>` to *drop* privileges is still correct |
| `$env:USER` / `$env:HOME` on Linux | `Get-PcDesktopUser` | Under `sudo pwsh` both describe root, not the person at the keyboard |

### Bash (CLI Linux — `src/CLI/start.sh`)

| Avoid | Prefer | Why |
|---|---|---|
| Unquoted variables (`$VAR`) | Quoted (`"$VAR"`) | Breaks on paths with spaces |
| `ls` in scripts | `find` or explicit glob | `ls` output is not reliably parseable |
| `[ ]` (single bracket) | `[[ ]]` (double bracket) | Double bracket is safer and supports regex |

---

## Platform Guards — Mandatory

Both CLI and C# code must guard platform-specific calls:

**PowerShell:**
```powershell
if ($IsWindows) { Get-CimInstance Win32_Processor }
if ($IsLinux)   { & lscpu }
```

**C#:**
```csharp
if (OperatingSystem.IsWindows()) { /* registry, CIM, WinUI */ }
```

Never call `Get-CimInstance`, registry reads, `Get-PnpDevice`, or WinUI APIs
without a platform guard. The CLI runs on Linux too.

---

## Error Handling

- Use specific exception types (`IOException`, `UnauthorizedAccessException`,
  `COMException`, `DirectoryNotFoundException`), not bare `catch (Exception)`
- Do not swallow exceptions silently — always log or surface them
- Every CIM query, registry read, file I/O, and `Process.Start` must have error handling
- In PowerShell: always use `-ErrorAction SilentlyContinue` on fallible cmdlets
  and follow up with a `Write-Warning` or fallback

---

## Commits

All commit messages **must** follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<optional scope>): <short description>
```

Allowed types: `feat`, `fix`, `docs`, `chore`, `refactor`, `style`, `perf`, `test`, `revert`, `ci`, `deps`, `build`

Examples:
```
feat(gui): add dark mode toggle to settings page
fix(cli): handle missing registry key in Get-LicenseKey
ci: pin action SHAs in pr-automation workflow
docs: update README platform support table
```

Rules:
- Subject line is lowercase, no trailing period
- Use imperative mood ("add", "fix", "remove" — not "added", "fixes")
- Keep subject ≤ 72 characters
- One concern per commit — do not bundle unrelated changes

---

## Pull Request Rules

- **Do NOT open a pull request unless the user explicitly asks.** Commit and push only; stop there.
- One PR per logical concern (error handling, deduplication, API migration, etc.)
- Describe **what** changed and **why** in the PR body
- Call out any `TODO(AI)` items explicitly in the PR description
- Do not change public-facing behavior without discussion

---

## What NOT to Do

- Do not introduce new NuGet packages without noting them in the PR description
- Do not convert working code to a different style just for aesthetics
- Do not remove functionality
- Do not rewrite the whole codebase in one PR
- Do not add `using System.Management` anywhere — migrate away from it instead
- Do not call `wmic.exe` — it is removed in Windows 11 25H2
