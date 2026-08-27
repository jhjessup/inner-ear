# Mac Verification Results — TOOLCHAIN REPAIR FAILED

- **Branch:** `chore/mac-verify-scaffold`
- **Commit:** `b70e91adcb2e3d8e6419e69f4eac3ff2a41d5fd8`
- **Timestamp (UTC):** 2026-08-27T17:57:27Z

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
error: 'inner-ear': Invalid manifest (compiled with: ["/Library/Developer/CommandLineTools/usr/bin/swiftc", "-vfsoverlay", "/var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.AZHLTO/vfs.yaml", "-L", "/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI", "-lPackageDescription", "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI", "-target", "arm64-apple-macosx14.0", "-I", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks", "-L", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks", "-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing", "-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk", "-swift-version", "5", "-I", "/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI", "-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk", "-package-description-version", "5.9.0", "/Users/jhjessup/tmp/inner-ear/Package.swift", "-o", "/var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.GBdBZJ/inner-ear-manifest"])
error: link command failed with exit code 1 (use -v to see invocation)
Undefined symbols for architecture arm64:
  "PackageDescription.Package.__allocating_init(name: Swift.String, defaultLocalization: PackageDescription.LanguageTag?, platforms: [PackageDescription.SupportedPlatform]?, pkgConfig: Swift.String?, providers: [PackageDescription.SystemPackageProvider]?, products: [PackageDescription.Product], dependencies: [PackageDescription.Package.Dependency], targets: [PackageDescription.Target], swiftLanguageVersions: [PackageDescription.SwiftVersion]?, cLanguageStandard: PackageDescription.CLanguageStandard?, cxxLanguageStandard: PackageDescription.CXXLanguageStandard?) -> PackageDescription.Package", referenced from:
      _main in Package-1.o
ld: symbol(s) not found for architecture arm64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
error: 'inner-ear': Invalid manifest (compiled with: ["/Library/Developer/CommandLineTools/usr/bin/swiftc", "-vfsoverlay", "/var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.y0IX0a/vfs.yaml", "-L", "/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI", "-lPackageDescription", "-Xlinker", "-rpath", "-Xlinker", "/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI", "-target", "arm64-apple-macosx14.0", "-I", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks", "-L", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks", "-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing", "-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk", "-swift-version", "5", "-I", "/Library/Developer/CommandLineTools/usr/lib/swift/pm/ManifestAPI", "-sdk", "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk", "-package-description-version", "5.9.0", "/Users/jhjessup/tmp/inner-ear/Package.swift", "-o", "/var/folders/6_/1jlqky951fq9r1dkm1xgrm4c0000gn/T/TemporaryDirectory.9ilY4R/inner-ear-manifest"])
error: link command failed with exit code 1 (use -v to see invocation)
Undefined symbols for architecture arm64:
  "PackageDescription.Package.__allocating_init(name: Swift.String, defaultLocalization: PackageDescription.LanguageTag?, platforms: [PackageDescription.SupportedPlatform]?, pkgConfig: Swift.String?, providers: [PackageDescription.SystemPackageProvider]?, products: [PackageDescription.Product], dependencies: [PackageDescription.Package.Dependency], targets: [PackageDescription.Target], swiftLanguageVersions: [PackageDescription.SwiftVersion]?, cLanguageStandard: PackageDescription.CLanguageStandard?, cxxLanguageStandard: PackageDescription.CXXLanguageStandard?) -> PackageDescription.Package", referenced from:
      _main in Package-1.o
ld: symbol(s) not found for architecture arm64
clang: error: linker command failed with exit code 1 (use -v to see invocation)
```
