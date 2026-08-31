# Keel product goldens

These fixtures use only fictional, general-purpose data. They cover the
workflow editor, live workflow progress, a session map with several expanded
audit trees, a multi-agent chat, and the full real Keel workspace.

Regenerate after an intentional visual change:

```sh
flutter test --update-goldens test/goldens/keel_product_goldens_test.dart
```

The generated PNGs live in `test/goldens/goldens/`. The fixture uses the
actual `AgentsScreen`, `SessionChatView`, `ProjectsSidebar`, `AgentRail`, and
workflow panel — it does not recreate a parallel product UI. On this macOS
development setup it loads Arial and the Flutter Material Icons font so text
and icons remain readable. For cross-platform CI, commit licensed font assets
to the repository and load those instead.
