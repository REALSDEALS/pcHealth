# AI Coding Assistant Guide — pcHealth

> If you are an AI assistant (Claude, Copilot, Cursor, etc.), read this file
> before making any changes to this repository.
> Inspired by: https://github.com/torvalds/linux/blob/master/Documentation/process/coding-assistants.rst

---

## Project Structure

This project has **three separate codebases**. Know which one you're in:

| Part | Location | Language | Purpose |
|---|---|---|---|
| Windows CLI | `src/Windows/CLI/` | PowerShell 7 | Windows terminal health tool |
| Windows GUI | `src/Windows/GUI/pcHealth/` | C# / WinUI 3 (.NET) | Windows-only graphical frontend |
| Linux app | `src/Linux/pchealth/` | Python 3.11+ / GTK4 | Linux terminal menu and desktop app |

Do not mix patterns between them. C# APIs do not belong in PowerShell scripts, and neither belongs in the Python package.

The tool list is shared: `assets/tools.json` is read by both stacks. A new tool
is added there first, then implemented on each side that should have it.

**Each side owns its platform completely.** There are no `$IsLinux` branches in
the PowerShell any more, and no Windows paths in the Python. A Linux tool
belongs in `src/Linux/pchealth/tools/`, never in `src/Windows/`.

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

### C# / .NET (GUI — `src/Windows/GUI/`)

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

### PowerShell 7 (CLI — `src/Windows/CLI/`)

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
| `$IsLinux` branches | Nothing -- the Windows CLI is Windows-only | Linux is `src/Linux/`, in Python. A platform branch here means the tool is in the wrong stack |

### Python (Linux app — `src/Linux/pchealth/`)

| Deprecated / Avoid | Preferred | Why |
|---|---|---|
| `subprocess.run(..., shell=True)` | An argv list, no shell | A shell turns any interpolated value into possible code. Every call in `system.py` passes a list |
| `os.system`, backticks, `shell=True` pipelines | `system.run` / `system.stream` | They centralise the missing-command, timeout and encoding handling |
| Bare `subprocess` calls in a tool | `system.run`, `system.output`, `system.stream` | A missing binary is the normal case on Linux, not an edge case; these return instead of raising |
| `os.geteuid() == 0` checks scattered in tools | `system.run_root` / `system.elevated` | Privilege is raised per action via pkexec so the GUI never runs as root |
| `print()` inside a tool, or any formatted text | `ui.section` / `ui.fields` / `ui.note` / `ui.run` | A tool describes results; the front-end decides whether they become text or widgets. A tool that emits `"[>>] ..."` has decided it lives in a terminal |
| Running a command by hand and printing its output | `ui.run(argv, label=...)` / `ui.run_all(...)` | Handles the step, its raw output, the exit code, and a single elevation prompt for a batch |
| `$HOME` / `os.environ["USER"]` | `system.desktop_user()` | Under sudo or pkexec both describe root, not the person at the keyboard |
| Touching GTK from a worker thread | `GLib.idle_add` | GTK may only be called from the main loop |

Run `python3 -m ruff check .`, `python3 -m ruff format --check .` and
`python3 -m mypy pchealth` from `src/Linux/` before committing. CI runs all three.

---

## Platform Guards — Mandatory

Both CLI and C# code must guard platform-specific calls:

The Windows CLI and the WinUI GUI are Windows-only, so CIM, the registry and
`Get-PnpDevice` need no platform guard there -- but they still need error
handling, because a key or a class can be missing on any given machine.

The Python side guards differently: a missing command is the normal case, so
everything goes through `system.run`, `system.output` or `system.stream`, which
return instead of raising.

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
