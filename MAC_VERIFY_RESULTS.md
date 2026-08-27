# Mac Verification Results

- **Branch:** `chore/mac-verify-scaffold`
- **Commit:** `9fde8c59d2148d59ad590e94a3fb3f330f518078`
- **Timestamp (UTC):** 2026-08-27T18:55:15Z

## Toolchain
```
swift: Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
xcodebuild: xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
macOS: 26.5.2
arch: arm64
```

## Toolchain Repair Log
```
Detected known CLT/manifest-link toolchain issue. Attempting automatic fixes.

--- Attempt 1: install/switch to an official Swift.org toolchain via swiftly (no sudo) ---
installer: Package name is 
installer: Installing at base path /Users/jhjessup
installer: The install was successful.
Fetching the latest stable Swift release...
Swift 6.3.3 is already installed
The file `/Users/jhjessup/tmp/inner-ear/.swift-version` has been set to `Swift 6.3.3` (was 6.3.3)
FIXED via swiftly toolchain: Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
```

## Step Results

| Step | Result |
|---|---|
| swift build | PASS |
| swift test | PASS |
| innerear --version | PASS |
| innerear --help | PASS |
| innerear record (expect not-yet-implemented) | EXIT_1 |
| innerear transcribe (expect not-yet-implemented) | EXIT_1 |
| innerear export (expect not-yet-implemented) | EXIT_1 |

`swift build`/`swift test` should be PASS. The three `innerear` command
steps are expected to show a non-zero exit (EXIT_1) right now — they're
stubs pending real service implementations (see docs/XCODE_SETUP.md).
Full logs below.


--- log: swift build ---
warning: 'inner-ear': /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swift-frontend -frontend -c -primary-file /Users/jhjessup/tmp/inner-ear/Package.swift -target arm64-apple-macosx14.0 -Xllvm -aarch64-use-tbi -enable-objc-interop -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/pm/ManifestAPI -vfsoverlay /var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.5KPLWv/vfs.yaml -no-color-diagnostics -Xcc -fno-color-diagnostics -swift-version 6 -package-description-version 6.0.0 -empty-abi-descriptor -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins/testing -no-auto-bridging-header-chaining -module-name main -in-process-plugin-server-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/local/lib/swift/host/plugins -target-sdk-version 26.5 -target-sdk-name macosx26.5 -external-plugin-path '/Library/Developer/Developer/usr/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server' -external-plugin-path '/Library/Developer/Developer/usr/local/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server' -o /var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.JtQixW/Package-1.o
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/clang /var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.JtQixW/Package-1.o --sysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk --target=arm64-apple-macosx14.0 -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/swift -rpath /usr/lib/swift -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/pm/ManifestAPI -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -lPackageDescription -Xlinker -rpath -Xlinker /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/pm/ManifestAPI -o /var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.QonUma/inner-ear-manifest
Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
Target: arm64-apple-macosx14.0
Planning build
Building for debugging...
Write auxiliary file /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/swift-version-29206828342AA87C.txt
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swiftc -module-name InnerEarCore -emit-dependencies -emit-module -emit-module-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCore.swiftmodule -output-file-map /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/output-file-map.json -parse-as-library -incremental -c @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/sources -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -target arm64-apple-macosx14.0 -v -incremental -enable-batch-mode -serialize-diagnostics -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -Onone -enable-testing -j12 -DSWIFT_PACKAGE -DDEBUG -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -parseable-output -parse-as-library -emit-objc-header -emit-objc-header-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/include/InnerEarCore-Swift.h -swift-version 6 -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -package-name inner_ear
Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
Target: arm64-apple-macosx14.0
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swiftc -module-name InnerEarCLI -emit-dependencies -emit-module -emit-module-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCLI.swiftmodule -output-file-map /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCLI.build/output-file-map.json -incremental -c @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCLI.build/sources -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -target arm64-apple-macosx14.0 -v -incremental -enable-batch-mode -serialize-diagnostics -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -Onone -enable-testing -j12 -DSWIFT_PACKAGE -DDEBUG -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -parseable-output -Xfrontend -entry-point-function-name -Xfrontend InnerEarCLI_main -swift-version 6 -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -package-name inner_ear
Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
Target: arm64-apple-macosx14.0
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swiftc -v -L /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear -module-name innerear -Xlinker -no_warn_duplicate_libraries -emit-executable -Xlinker -alias -Xlinker _InnerEarCLI_main -Xlinker _main -Xlinker -rpath -Xlinker @loader_path @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear.product/Objects.LinkFileList -Xlinker -rpath -Xlinker /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift-6.2/macosx -target arm64-apple-macosx14.0 -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCLI.swiftmodule -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCore.swiftmodule -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g
Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
Target: arm64-apple-macosx14.0
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/clang /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCLI.build/CLI.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCLI.build/main.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/AudioCaptureService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/DiarizationService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/ExportService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Recording.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/RecordingView.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/RecordingViewModel.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Speaker.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/SummarizationService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Summary.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Transcript.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/TranscriptSegment.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/TranscriptionService.swift.o --sysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk --target=arm64-apple-macosx14.0 -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/swift -rpath /usr/lib/swift -L /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -Xlinker -no_warn_duplicate_libraries -Xlinker -alias -Xlinker _InnerEarCLI_main -Xlinker _main -Xlinker -rpath -Xlinker @loader_path -Xlinker -rpath -Xlinker /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift-6.2/macosx -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCLI.swiftmodule -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCore.swiftmodule -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/dsymutil /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear.dSYM
codesign --force --sign - --entitlements /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear-entitlement.plist /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear
/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear: replacing existing signature
Build complete! (0.73s)

--- log: swift test ---
Planning build
Building for debugging...
Write auxiliary file /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/swift-version-29206828342AA87C.txt
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swiftc -module-name InnerEarCoreTests -emit-dependencies -emit-module -emit-module-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftmodule -output-file-map /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/output-file-map.json -parse-as-library -incremental -c @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/sources -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -target arm64-apple-macosx14.0 -v -incremental -enable-batch-mode -serialize-diagnostics -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -Onone -enable-testing -Xfrontend -enable-cross-import-overlays -j12 -DSWIFT_PACKAGE -DDEBUG -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -parseable-output -parse-as-library -swift-version 6 -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -package-name inner_ear
Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
Target: arm64-apple-macosx14.0
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swift-frontend -frontend -emit-module -experimental-skip-non-inlinable-function-bodies-without-types /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/TestSupport/Fakes.swift /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/unit/RecordingViewModelTests.swift -target arm64-apple-macosx14.0 -Xllvm -aarch64-use-tbi -enable-objc-interop -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -no-color-diagnostics -Xcc -fno-color-diagnostics -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -D SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -enable-cross-import-overlays -empty-abi-descriptor -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins/testing -enable-anonymous-context-mangled-names -file-compilation-dir /Users/jhjessup/tmp/inner-ear -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -no-auto-bridging-header-chaining -module-name InnerEarCoreTests -package-name inner_ear -in-process-plugin-server-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/local/lib/swift/host/plugins -target-sdk-version 26.5 -target-sdk-name macosx26.5 -external-plugin-path /Library/Developer/Developer/usr/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -external-plugin-path /Library/Developer/Developer/usr/local/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -emit-module-doc-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftdoc -emit-module-source-info-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftsourceinfo -serialize-diagnostics-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/InnerEarCoreTests.emit-module.dia -emit-dependencies-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/InnerEarCoreTests.emit-module.d -parse-as-library -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftmodule -emit-abi-descriptor-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.abi.json
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swiftc -module-name InnerEarPackageTests -emit-dependencies -emit-module -emit-module-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarPackageTests.swiftmodule -output-file-map /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.build/output-file-map.json -parse-as-library -incremental -c @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.build/sources -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -target arm64-apple-macosx14.0 -v -incremental -enable-batch-mode -serialize-diagnostics -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -Onone -enable-testing -Xfrontend -enable-cross-import-overlays -j12 -DSWIFT_PACKAGE -DDEBUG -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -parseable-output -parse-as-library -emit-objc-header -emit-objc-header-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.build/include/InnerEarPackageTests-Swift.h -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -package-name inner_ear
Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
Target: arm64-apple-macosx14.0
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/swiftc -v -L /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.xctest/Contents/MacOS/InnerEarPackageTests -module-name InnerEarPackageTests -Xlinker -no_warn_duplicate_libraries -Xlinker -bundle -Xlinker -rpath -Xlinker @loader_path/../../../ @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.product/Objects.LinkFileList -Xlinker -rpath -Xlinker /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift-6.2/macosx -target arm64-apple-macosx14.0 -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCore.swiftmodule -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftmodule -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarPackageTests.swiftmodule -I /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -plugin-path /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g
Apple Swift version 6.3.3 (swift-6.3.3-RELEASE)
Target: arm64-apple-macosx14.0
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/clang /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/AudioCaptureService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/DiarizationService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/ExportService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Recording.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/RecordingView.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/RecordingViewModel.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Speaker.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/SummarizationService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Summary.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Transcript.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/TranscriptSegment.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/TranscriptionService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/Fakes.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/RecordingViewModelTests.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/ServiceContractTests.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.build/runner.swift.o --sysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk --target=arm64-apple-macosx14.0 -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/swift -rpath /usr/lib/swift -L /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug -L /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift/macosx/testing -Xlinker -no_warn_duplicate_libraries -Xlinker -bundle -Xlinker -rpath -Xlinker @loader_path/../../../ -Xlinker -rpath -Xlinker /Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/lib/swift-6.2/macosx -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCore.swiftmodule -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftmodule -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarPackageTests.swiftmodule -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.xctest/Contents/MacOS/InnerEarPackageTests
/Users/jhjessup/Library/Developer/Toolchains/swift-6.3.3-RELEASE.xctoolchain/usr/bin/dsymutil /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.xctest/Contents/MacOS/InnerEarPackageTests -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarPackageTests.xctest/Contents/MacOS/InnerEarPackageTests.dSYM
Build complete! (0.94s)
◇ Test run started.
↳ Swift Standard Library Version: 6.3
↳ Swift Compiler Version: 6.3
↳ Testing Library Version: 6.3.3 (48d727cc1cf4eda)
↳ Target Platform: arm64-apple-macosx
↳ OS Version: 26.5.2 (25F84)
◇ Suite RecordingViewModelTests started.
◇ Suite ServiceContractTests started.
◇ Test startRecording_whenPermissionDenied_setsErrorMessageAndLeavesStateIdle() started.
◇ Test startRecording_whenSucceeds_updatesCaptureStateToRecording() started.
◇ Test exportService_export_writesRequestedFormatToDestination() started.
◇ Test diarizationService_diarize_assignsSpeakerToEverySegment() started.
◇ Test stopRecordingAndProcess_runsFullPipeline_andPublishesFinalSummary() started.
◇ Test stopRecordingAndProcess_whenTranscriptionFails_setsErrorAndDoesNotProduceSummary() started.
◇ Test audioCaptureService_stopCapture_returnsRecordingWithMicrophoneURL() started.
◇ Test transcriptionService_transcribe_returnsSegmentsForRecording() started.
◇ Test summarizationService_summarize_returnsSummaryLinkedToTranscript() started.
✔ Test summarizationService_summarize_returnsSummaryLinkedToTranscript() passed after 0.001 seconds.
✔ Test transcriptionService_transcribe_returnsSegmentsForRecording() passed after 0.001 seconds.
✔ Test exportService_export_writesRequestedFormatToDestination() passed after 0.001 seconds.
✔ Test diarizationService_diarize_assignsSpeakerToEverySegment() passed after 0.001 seconds.
✔ Test audioCaptureService_stopCapture_returnsRecordingWithMicrophoneURL() passed after 0.001 seconds.
✔ Suite ServiceContractTests passed after 0.001 seconds.
✔ Test startRecording_whenSucceeds_updatesCaptureStateToRecording() passed after 0.001 seconds.
✔ Test startRecording_whenPermissionDenied_setsErrorMessageAndLeavesStateIdle() passed after 0.001 seconds.
✔ Test stopRecordingAndProcess_whenTranscriptionFails_setsErrorAndDoesNotProduceSummary() passed after 0.001 seconds.
✔ Test stopRecordingAndProcess_runsFullPipeline_andPublishesFinalSummary() passed after 0.001 seconds.
✔ Suite RecordingViewModelTests passed after 0.001 seconds.
✔ Test run with 9 tests in 2 suites passed after 0.001 seconds.

--- log: innerear --version ---
[0/1] Planning build
Building for debugging...
[0/4] Write swift-version-29206828342AA87C.txt
[1/3] Linking innerear
[2/3] Applying innerear
Build of product 'innerear' complete! (0.74s)
innerear 0.1.0-scaffold

--- log: innerear --help ---
Building for debugging...
[0/3] Write swift-version-29206828342AA87C.txt
Build of product 'innerear' complete! (0.12s)
innerear — local-only meeting recorder/transcriber CLI

USAGE:
  innerear record [--no-system-audio]
  innerear transcribe <audio-file> [--model <name>]
  innerear export <recording-id> [--format markdown|json|text|rtf|pdf]
  innerear --version

All processing runs on-device. No cloud, no accounts, no uploads.

--- log: innerear record (expect not-yet-implemented) ---
Building for debugging...
[0/3] Write swift-version-29206828342AA87C.txt
Build of product 'innerear' complete! (0.13s)
record (system audio: true) — not yet implemented.
Real AudioCaptureService implementation is pending — see docs/XCODE_SETUP.md.

--- log: innerear transcribe (expect not-yet-implemented) ---
Building for debugging...
[0/3] Write swift-version-29206828342AA87C.txt
Build of product 'innerear' complete! (0.12s)
transcribe '/tmp/nonexistent.wav' (model: default) — not yet implemented.
Real TranscriptionService implementation is pending — see docs/XCODE_SETUP.md.

--- log: innerear export (expect not-yet-implemented) ---
Building for debugging...
[0/3] Write swift-version-29206828342AA87C.txt
Build of product 'innerear' complete! (0.11s)
export 'fake-id' as markdown — not yet implemented.
Real ExportService implementation is pending — see docs/XCODE_SETUP.md.

