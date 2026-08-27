# Mac Verification Results

- **Branch:** `chore/mac-verify-scaffold`
- **Commit:** `b5219135f2ddfc1d2c1939f017f54a7f89eebc4f`
- **Timestamp (UTC):** 2026-08-27T18:29:36Z

## Toolchain
```
swift: swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
xcodebuild: xcode-select: error: tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance
macOS: 26.5.2
arch: arm64
```

## Toolchain Repair Log
```
Toolchain OK — swift build succeeds.
```

## Step Results

| Step | Result |
|---|---|
| swift build | PASS |
| swift test | EXIT_1 |
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
warning: 'inner-ear': /Library/Developer/CommandLineTools/usr/bin/swift-frontend -frontend -c -primary-file /Users/jhjessup/tmp/inner-ear/Package.swift -target arm64-apple-macosx14.0 -Xllvm -aarch64-use-tbi -enable-objc-interop -stack-check -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -I /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI -vfsoverlay /var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.NL1d39/vfs.yaml -no-color-diagnostics -Xcc -fno-color-diagnostics -swift-version 6 -package-description-version 6.0.0 -new-driver-path /Library/Developer/CommandLineTools/usr/bin/swift-driver -empty-abi-descriptor -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -no-auto-bridging-header-chaining -module-name main -disable-clang-spi -target-sdk-version 26.5 -target-sdk-name macosx26.5 -external-plugin-path '/Library/Developer/Developer/usr/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server' -external-plugin-path '/Library/Developer/Developer/usr/local/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server' -in-process-plugin-server-path /Library/Developer/CommandLineTools/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins -plugin-path /Library/Developer/CommandLineTools/usr/local/lib/swift/host/plugins -o /var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.FlOgXU/Package-1.o
/Library/Developer/CommandLineTools/usr/bin/clang /var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.FlOgXU/Package-1.o --sysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk --target=arm64-apple-macosx14.0 -L /Library/Developer/CommandLineTools/usr/lib/swift/macosx -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/swift -rpath /usr/lib/swift -L /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI -L /Library/Developer/CommandLineTools/Library/Developer/Frameworks -lPackageDescription -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI -o /var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.TsZazm/inner-ear-manifest
Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx14.0
Building for debugging...
Write auxiliary file /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/swift-version--1AB21518FC5DEDBE.txt
Build complete! (0.13s)

--- log: swift test ---
Planning build
Building for debugging...
Write auxiliary file /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/swift-version--1AB21518FC5DEDBE.txt
/Library/Developer/CommandLineTools/usr/bin/swiftc -module-name InnerEarCore -emit-dependencies -emit-module -emit-module-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCore.swiftmodule -output-file-map /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/output-file-map.json -parse-as-library -incremental -c @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/sources -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -target arm64-apple-macosx14.0 -v -incremental -enable-batch-mode -serialize-diagnostics -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -Onone -enable-testing -j12 -DSWIFT_PACKAGE -DDEBUG -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -parseable-output -parse-as-library -emit-objc-header -emit-objc-header-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/include/InnerEarCore-Swift.h -swift-version 6 -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -L /Library/Developer/CommandLineTools/Library/Developer/Frameworks -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -package-name inner_ear
Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx14.0
/Library/Developer/CommandLineTools/usr/bin/swiftc -module-name InnerEarCLI -emit-dependencies -emit-module -emit-module-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCLI.swiftmodule -output-file-map /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCLI.build/output-file-map.json -incremental -c @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCLI.build/sources -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -target arm64-apple-macosx14.0 -v -incremental -enable-batch-mode -serialize-diagnostics -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -Onone -enable-testing -j12 -DSWIFT_PACKAGE -DDEBUG -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -parseable-output -Xfrontend -entry-point-function-name -Xfrontend InnerEarCLI_main -swift-version 6 -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -L /Library/Developer/CommandLineTools/Library/Developer/Frameworks -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -package-name inner_ear
/Library/Developer/CommandLineTools/usr/bin/swiftc -module-name InnerEarCoreTests -emit-dependencies -emit-module -emit-module-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftmodule -output-file-map /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/output-file-map.json -parse-as-library -incremental -c @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/sources -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -target arm64-apple-macosx14.0 -v -incremental -enable-batch-mode -serialize-diagnostics -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -Onone -enable-testing -Xfrontend -enable-cross-import-overlays -j12 -DSWIFT_PACKAGE -DDEBUG -DSWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -parseable-output -parse-as-library -swift-version 6 -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -L /Library/Developer/CommandLineTools/Library/Developer/Frameworks -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -package-name inner_ear
Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx14.0
Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx14.0
/Library/Developer/CommandLineTools/usr/bin/swiftc -v -L /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear -module-name innerear -Xlinker -no_warn_duplicate_libraries -emit-executable -Xlinker -alias -Xlinker _InnerEarCLI_main -Xlinker _main -Xlinker -rpath -Xlinker @loader_path @/Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear.product/Objects.LinkFileList -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/usr/lib/swift-6.2/macosx -target arm64-apple-macosx14.0 -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCLI.swiftmodule -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCore.swiftmodule -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -L /Library/Developer/CommandLineTools/Library/Developer/Frameworks -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -g
/Library/Developer/CommandLineTools/usr/bin/swift-frontend -frontend -c -primary-file /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/TestSupport/Fakes.swift /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/unit/RecordingViewModelTests.swift -emit-dependencies-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/Fakes.d -emit-reference-dependencies-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/Fakes.swiftdeps -serialize-diagnostics-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/Fakes.dia -target arm64-apple-macosx14.0 -Xllvm -aarch64-use-tbi -enable-objc-interop -stack-check -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -no-color-diagnostics -Xcc -fno-color-diagnostics -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -D SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -new-driver-path /Library/Developer/CommandLineTools/usr/bin/swift-driver -enable-cross-import-overlays -empty-abi-descriptor -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -enable-anonymous-context-mangled-names -file-compilation-dir /Users/jhjessup/tmp/inner-ear -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -no-auto-bridging-header-chaining -module-name InnerEarCoreTests -package-name inner_ear -disable-clang-spi -target-sdk-version 26.5 -target-sdk-name macosx26.5 -external-plugin-path /Library/Developer/Developer/usr/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -external-plugin-path /Library/Developer/Developer/usr/local/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -in-process-plugin-server-path /Library/Developer/CommandLineTools/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins -plugin-path /Library/Developer/CommandLineTools/usr/local/lib/swift/host/plugins -parse-as-library -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/Fakes.swift.o -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -index-system-modules
/Library/Developer/CommandLineTools/usr/bin/swift-frontend -frontend -c /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/TestSupport/Fakes.swift /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift -primary-file /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/unit/RecordingViewModelTests.swift -emit-dependencies-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/RecordingViewModelTests.d -emit-reference-dependencies-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/RecordingViewModelTests.swiftdeps -serialize-diagnostics-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/RecordingViewModelTests.dia -target arm64-apple-macosx14.0 -Xllvm -aarch64-use-tbi -enable-objc-interop -stack-check -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -no-color-diagnostics -Xcc -fno-color-diagnostics -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -D SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -new-driver-path /Library/Developer/CommandLineTools/usr/bin/swift-driver -enable-cross-import-overlays -empty-abi-descriptor -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -enable-anonymous-context-mangled-names -file-compilation-dir /Users/jhjessup/tmp/inner-ear -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -no-auto-bridging-header-chaining -module-name InnerEarCoreTests -package-name inner_ear -disable-clang-spi -target-sdk-version 26.5 -target-sdk-name macosx26.5 -external-plugin-path /Library/Developer/Developer/usr/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -external-plugin-path /Library/Developer/Developer/usr/local/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -in-process-plugin-server-path /Library/Developer/CommandLineTools/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins -plugin-path /Library/Developer/CommandLineTools/usr/local/lib/swift/host/plugins -parse-as-library -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/RecordingViewModelTests.swift.o -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -index-system-modules
/Library/Developer/CommandLineTools/usr/bin/swift-frontend -frontend -c /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/TestSupport/Fakes.swift -primary-file /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/unit/RecordingViewModelTests.swift -emit-dependencies-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/ServiceContractTests.d -emit-reference-dependencies-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/ServiceContractTests.swiftdeps -serialize-diagnostics-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/ServiceContractTests.dia -target arm64-apple-macosx14.0 -Xllvm -aarch64-use-tbi -enable-objc-interop -stack-check -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -no-color-diagnostics -Xcc -fno-color-diagnostics -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -D SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -new-driver-path /Library/Developer/CommandLineTools/usr/bin/swift-driver -enable-cross-import-overlays -empty-abi-descriptor -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -enable-anonymous-context-mangled-names -file-compilation-dir /Users/jhjessup/tmp/inner-ear -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -no-auto-bridging-header-chaining -module-name InnerEarCoreTests -package-name inner_ear -disable-clang-spi -target-sdk-version 26.5 -target-sdk-name macosx26.5 -external-plugin-path /Library/Developer/Developer/usr/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -external-plugin-path /Library/Developer/Developer/usr/local/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -in-process-plugin-server-path /Library/Developer/CommandLineTools/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins -plugin-path /Library/Developer/CommandLineTools/usr/local/lib/swift/host/plugins -parse-as-library -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/ServiceContractTests.swift.o -index-store-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/index/store -index-system-modules
/Library/Developer/CommandLineTools/usr/bin/swift-frontend -frontend -emit-module -experimental-skip-non-inlinable-function-bodies-without-types /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/TestSupport/Fakes.swift /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift /Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/unit/RecordingViewModelTests.swift -target arm64-apple-macosx14.0 -Xllvm -aarch64-use-tbi -enable-objc-interop -stack-check -sdk /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -I /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules -I /Library/Developer/CommandLineTools/Library/Developer/Frameworks -no-color-diagnostics -Xcc -fno-color-diagnostics -enable-testing -g -debug-info-format=dwarf -dwarf-version=4 -module-cache-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/ModuleCache -swift-version 6 -Onone -D SWIFT_PACKAGE -D DEBUG -D SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE -new-driver-path /Library/Developer/CommandLineTools/usr/bin/swift-driver -enable-cross-import-overlays -empty-abi-descriptor -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing -enable-anonymous-context-mangled-names -file-compilation-dir /Users/jhjessup/tmp/inner-ear -Xcc -isysroot -Xcc /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk -Xcc -fPIC -Xcc -g -no-auto-bridging-header-chaining -module-name InnerEarCoreTests -package-name inner_ear -disable-clang-spi -target-sdk-version 26.5 -target-sdk-name macosx26.5 -external-plugin-path /Library/Developer/Developer/usr/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -external-plugin-path /Library/Developer/Developer/usr/local/lib/swift/host/plugins#/Library/Developer/Developer/usr/bin/swift-plugin-server -in-process-plugin-server-path /Library/Developer/CommandLineTools/usr/lib/swift/host/libSwiftInProcPluginServer.dylib -plugin-path /Library/Developer/CommandLineTools/usr/lib/swift/host/plugins -plugin-path /Library/Developer/CommandLineTools/usr/local/lib/swift/host/plugins -emit-module-doc-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftdoc -emit-module-source-info-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftsourceinfo -serialize-diagnostics-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/InnerEarCoreTests.emit-module.dia -emit-dependencies-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCoreTests.build/InnerEarCoreTests.emit-module.d -parse-as-library -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.swiftmodule -emit-abi-descriptor-path /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCoreTests.abi.json
error: emit-module command failed with exit code 1 (use -v to see invocation)
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:1:8: error: no such module 'Testing'
 1 | import Testing
   |        `- error: no such module 'Testing'
 2 | @testable import InnerEarCore
 3 | 
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:1:8: error: no such module 'Testing'
 1 | import Testing
   |        `- error: no such module 'Testing'
 2 | @testable import InnerEarCore
 3 | 
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:1:8: error: no such module 'Testing'
 1 | import Testing
   |        `- error: no such module 'Testing'
 2 | @testable import InnerEarCore
 3 | 
/Users/jhjessup/tmp/inner-ear/Tests/InnerEarCoreTests/service/ServiceContractTests.swift:1:8: error: no such module 'Testing'
 1 | import Testing
   |        `- error: no such module 'Testing'
 2 | @testable import InnerEarCore
 3 | 
Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx14.0
/Library/Developer/CommandLineTools/usr/bin/clang /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCLI.build/CLI.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCLI.build/main.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/AudioCaptureService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/DiarizationService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/ExportService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Recording.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/RecordingView.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/RecordingViewModel.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Speaker.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/SummarizationService.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Summary.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/Transcript.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/TranscriptSegment.swift.o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/InnerEarCore.build/TranscriptionService.swift.o --sysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk --target=arm64-apple-macosx14.0 -L /Library/Developer/CommandLineTools/usr/lib/swift/macosx -L /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/lib/swift -rpath /usr/lib/swift -L /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug -L /Library/Developer/CommandLineTools/Library/Developer/Frameworks -Xlinker -no_warn_duplicate_libraries -Xlinker -alias -Xlinker _InnerEarCLI_main -Xlinker _main -Xlinker -rpath -Xlinker @loader_path -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/usr/lib/swift-6.2/macosx -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCLI.swiftmodule -Xlinker -add_ast_path -Xlinker /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/Modules/InnerEarCore.swiftmodule -o /Users/jhjessup/tmp/inner-ear/.build/arm64-apple-macosx/debug/innerear
error: fatalError

--- log: innerear --version ---
[0/1] Planning build
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'innerear' complete! (0.33s)
innerear 0.1.0-scaffold

--- log: innerear --help ---
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'innerear' complete! (0.13s)
innerear — local-only meeting recorder/transcriber CLI

USAGE:
  innerear record [--no-system-audio]
  innerear transcribe <audio-file> [--model <name>]
  innerear export <recording-id> [--format markdown|json|text|rtf|pdf]
  innerear --version

All processing runs on-device. No cloud, no accounts, no uploads.

--- log: innerear record (expect not-yet-implemented) ---
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'innerear' complete! (0.14s)
record (system audio: true) — not yet implemented.
Real AudioCaptureService implementation is pending — see docs/XCODE_SETUP.md.

--- log: innerear transcribe (expect not-yet-implemented) ---
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'innerear' complete! (0.16s)
transcribe '/tmp/nonexistent.wav' (model: default) — not yet implemented.
Real TranscriptionService implementation is pending — see docs/XCODE_SETUP.md.

--- log: innerear export (expect not-yet-implemented) ---
Building for debugging...
[0/3] Write swift-version--1AB21518FC5DEDBE.txt
Build of product 'innerear' complete! (0.15s)
export 'fake-id' as markdown — not yet implemented.
Real ExportService implementation is pending — see docs/XCODE_SETUP.md.

