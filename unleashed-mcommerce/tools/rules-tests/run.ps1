# Runs the Firestore rules tests against the local emulator only.
# It never deploys rules and never connects to the production project.

$ErrorActionPreference = 'Stop'

$jdk = 'C:\Users\Andrei San Juan\AppData\Local\Java\jdk-21.0.13+9'
if (-not (Test-Path (Join-Path $jdk 'bin\java.exe'))) {
  throw "Java not found at $jdk. Install a JDK 11+ or update this script."
}

$env:JAVA_HOME = $jdk
$env:Path = "$jdk\bin;$env:Path"

$root = Resolve-Path (Join-Path $PSScriptRoot '..\..')
Set-Location $root

Write-Host 'Running offline Firestore rules tests (demo-unleashed-rules)...'
firebase emulators:exec `
  --only firestore `
  --project demo-unleashed-rules `
  --config firebase.rules-test.json `
  'node --test tools\rules-tests\rules.test.cjs'
