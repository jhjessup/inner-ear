# Mac Verification Results — TOOLCHAIN REPAIR FAILED

- **Branch:** `chore/mac-verify-scaffold`
- **Commit:** `206f1a94ae0e594917afd4ec81cafc985f89919c`
- **Timestamp (UTC):** 2026-08-27T18:41:11Z

swift build/test were not attempted — the toolchain itself is broken.
See repair log below.

```
Detected known CLT/manifest-link toolchain issue. Attempting automatic fixes.

--- Attempt 1: install/switch to an official Swift.org toolchain via swiftly (no sudo) ---
bash: line 1: 404:: command not found
swiftly installation itself failed — skipping to next fix attempt.

--- Attempt 2: reinstall Command Line Tools (needs sudo; best effort) ---
Passwordless sudo not available — cannot automate the CLT reinstall
(needs your password and a GUI 'Install' click). Run manually:
  sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install

Automatic fixes did not resolve the toolchain issue. Last probe log:
[0/1] Planning build
Building for debugging...
[0/5] Write swift-version--1AB21518FC5DEDBE.txt
error: emit-module command failed with exit code 1 (use -v to see invocation)
[2/7] Emitting module InnerEarCoreTests
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:1:8: error: no such module 'Testing'
 1 | import Testing
   |        `- error: no such module 'Testing'
 2 | @testable import InnerEarCore
 3 | 
[3/7] Compiling InnerEarCoreTests Fakes.swift
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:1:8: error: no such module 'Testing'
 1 | import Testing
   |        `- error: no such module 'Testing'
 2 | @testable import InnerEarCore
 3 | 
[4/7] Compiling InnerEarCoreTests RecordingViewModelTests.swift
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:1:8: error: no such module 'Testing'
 1 | import Testing
   |        `- error: no such module 'Testing'
 2 | @testable import InnerEarCore
 3 | 
[5/7] Compiling InnerEarCoreTests ServiceContractTests.swift
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:1:8: error: no such module 'Testing'
 1 | import Testing
   |        `- error: no such module 'Testing'
 2 | @testable import InnerEarCore
 3 | 
error: fatalError
```
