---
description: Run the local quality gate — format check, analyze, tests.
---

Run the CubeClash quality gate (the same steps as CI) and report results concisely:

1. `dart format --output=none --set-exit-if-changed .`
2. `flutter analyze`
3. `flutter test`

If any step fails, summarize the failures grouped by file and propose targeted
fixes. Do not modify code before confirming the intended fix.
