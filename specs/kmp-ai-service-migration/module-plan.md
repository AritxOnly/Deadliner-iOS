# KMP AIService Migration Module Plan

## 模块拆分

1. **KMP AI utility domain**
   - `shared/src/commonMain/.../domain/ai/`: stable request/result DTOs, monthly-analysis model and errors.
   - `shared/src/commonMain/.../lifi/utility/`: typed utility service, prompt construction, JSON cleanup/decoding and proposal normalization.
   - Reuses the existing open-source `LlmGateway` and `KtorLlmClient`; no Swift networking is retained.

2. **KMP platform facade**
   - `shared/src/iosMain/.../lifi/IosLifiCore.kt`: creates/configures the utility service alongside the LiFi core and exposes suspend calls to Swift.
   - Android/HarmonyOS can construct the common utility service directly from their existing KMP LLM component; no iOS DTO is introduced into common code.

3. **iOS application bridge and presentation**
   - `DeadlinerCoreSupport/Bridge/KMPLifiCoreBridge.swift`: reads persisted settings, owns/reuses iOS facade and maps KMP proposals to existing presentation DTOs.
   - `TaskEditorSheetView`, `HabitEditorSheetView`, `OverviewViewModel`, `AISettingsView`: call the bridge, retain UI-specific form/date rendering.
   - Delete `Core/Application/Services/AIService.swift` only after every caller is moved.

4. **Typed tool execution boundary**
   - `KMPLifiCoreBridge` maps typed KMP `ToolCall` into an `AIToolRequest` solely for current UI cards and stores the original call by request ID.
   - `ToolCallExecutor` accepts only `ToolCall`; all JSON argument decode/legacy `execute(toolName:argsJson:)` code is removed.
   - Missing registry state produces a typed failure payload and never executes a reconstructed JSON request.

## 平台映射

| Capability | KMP shared | iOS | Android / HarmonyOS |
| --- | --- | --- | --- |
| Task/habit recognition | typed utility service + prompts | form-field projection | invoke common utility and project to native form |
| Monthly analysis | typed utility service + DTO | overview display/cache | native overview display/cache |
| Config validation | Ktor client | settings persistence/UI | native settings persistence/UI |
| Main AI chat | existing LiFi core | existing bridge/UI | existing platform facades |

## 文件拆分策略

- Prompt/JSON-normalization and request orchestration stay separate from typed DTOs.
- `IosLifiCore` remains a lifecycle facade; do not grow it with prompt implementation.
- Swift bridge may map DTOs but must not reimplement prompt strings, provider URLs or JSON parsing.
- `AIToolRequest.argsJson` remains bounded to presentation and audit display; no execution component may decode it.
- No modified core source file may exceed 1000 effective lines.

## 风险点

- Existing LiFi prompts intentionally force tool calls, so editor extraction must use a separate utility prompt path.
- Existing Swift proposal DTOs use `name` / `dueTime`, while KMP uses `title` / `dueAt`; mapping remains only a temporary presentation adapter and is deleted with legacy Swift AI models later.
- AI configuration changes require invalidating/recreating the KMP facade before subsequent utility calls.
