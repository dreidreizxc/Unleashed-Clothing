# Firestore rules tests (offline emulator only)

These tests exercise `../../firestore.rules` against the local Firestore
emulator. They never connect to the `unleashed-clothing` project, never read or
write production data, and never deploy rules.

## Prerequisites

- Java 11+ (tested with Temurin 21 at
  `C:\Users\Andrei San Juan\AppData\Local\Java\jdk-21.0.13+9`)
- Firebase CLI (`firebase --version`, tested with 15.34.1)
- Node.js 20+ (tested with 24)

## Install

```powershell
cd tools\rules-tests
npm install --no-audit --no-fund
```

## Run

From the repository root:

```powershell
$env:JAVA_HOME = "C:\Users\Andrei San Juan\AppData\Local\Java\jdk-21.0.13+9"
$env:Path = "$env:JAVA_HOME\bin;$env:Path"
firebase emulators:exec --only firestore --project demo-unleashed-rules --config firebase.rules-test.json "node --test tools\rules-tests\rules.test.cjs"
```

The `demo-` project id keeps the emulator fully offline. The emulator listens on
`127.0.0.1:8085` only (see `firebase.rules-test.json`). The config must live at
the repository root because the Firebase CLI rejects rules paths outside the
config directory.

## Scope

- guest/public catalogue, product images, and active-announcement reads
- customer profile ownership and self-promotion denial
- order-request creation shape, protected fields, and email-verification policy
- checkout transaction (order + notifications + cart cleanup) atomicity
- pending-only customer cancellation
- cross-user read isolation for orders, notifications, carts, chat
- administrator-only confirmation, stock, counters, inventory logs, settings
- notification creation/read rules
- review eligibility (delivered order, matching review id)
- chat message sender/role restrictions

## Safety

- Do not run with `--project unleashed-clothing`.
- Do not add a `firebase deploy` step to these scripts.
- Do not commit real credentials; the emulator accepts fake tokens only.
