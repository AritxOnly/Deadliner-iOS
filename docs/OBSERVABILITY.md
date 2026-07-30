# Deadliner diagnostics

The iOS app writes two bounded, durable files at:

`App Group/Diagnostics/deadliner-diagnostics.log`

`App Group/Diagnostics/deadliner-diagnostics.jsonl`

The file is shared by the app and extensions, survives process restarts, retains
up to 14 days of records, and is capped at 8 MiB. The cap and retention are both
intentional: diagnostics must not create an unbounded persistence problem.

The standard `.log` file uses one human-readable line per event:

```text
[2026-07-28T12:34:56.789Z][KMP][persistence.task.create] uid=abc-123
[2026-07-28T12:34:57.012Z][Native][sync.finished] durationMs=183 success=true
```

The JSONL counterpart contains the exact same records. Every structured record
contains a schema version, timestamp, process ID,
session ID, level, domain, event/message, and optional context map. New core
code should prefer:

```swift
AppLog.event(
    "persistence.task.create",
    domain: .persistence,
    context: ["uid": taskID]
)
```

Use `AppLog.failure` for failures. Context must only include non-sensitive,
low-cardinality metadata such as IDs, counts, operation names and elapsed time.
Do not log task text, notes, AI prompts, API keys, WebDAV credentials, or full
network responses.

KMP boundaries are logged twice where useful: the Swift-to-KMP UI bridge uses
the `kmp` domain and the atomic persistence mutation uses `persistence`. The
process stdout capture also persists Kotlin `println` output and classifies
`[KMP]` lines into the `kmp` domain. This keeps third-party/Kotlin diagnostics
available even where the framework cannot call Swift's structured logger.

Users can export either version from **账号与云同步 → 应用日志**. AI feedback
exports both versions. Feedback flows must include at least the standard log,
and JSONL when machine analysis is needed, in addition to any platform-generated
feedback JSON, which normally only contains device metadata.
