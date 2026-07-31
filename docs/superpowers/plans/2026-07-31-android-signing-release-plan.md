# Android Signing and Release Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Configure the existing blog-phone Flutter app to build installable, update-compatible Android release APKs with a new local formal signing key, consistent version metadata, the `blog-api` product name, and GitHub Actions support without exposing secrets.

**Architecture:** Keep the existing Android application ID `com.example.blog_phone` so the new signed APK remains install-compatible with the current app. Store the local PKCS12 keystore and password outside the repository, load local signing values from ignored `android/key.properties`, and make CI reconstruct the keystore and properties file only when all GitHub Secrets are present. Use `pubspec.yaml` as the single source for Flutter version and build number; propagate its values into Android and Windows metadata.

**Tech Stack:** Flutter 3.41.4, Dart, Android Gradle Kotlin DSL, GitHub Actions, OpenSSL-generated PKCS12 keystore, Windows CMake resource metadata.

---

### Task 1: Establish the signing configuration contract

**Files:**
- Modify: `android/.gitignore`
- Create locally, never commit: `android/key.properties`
- Use locally, never commit: `E:/kmoretti-github/blog_api/secrets/blog-api-release.jks`
- Use locally, never commit: `E:/kmoretti-github/blog_api/secrets/blog-api-release-password.txt`

- [ ] **Step 1: Read the generated local password and write ignored Android properties**

Read the password from `E:/kmoretti-github/blog_api/secrets/blog-api-release-password.txt` and create `android/key.properties` with this exact structure, replacing the value with the local password:

```properties
storeFile=E:/kmoretti-github/blog_api/secrets/blog-api-release.jks
storePassword=<generated-password>
keyAlias=blog-api
keyPassword=<generated-password>
```

Use forward slashes so Gradle parses the Windows path consistently.

- [ ] **Step 2: Verify the properties and keystore are ignored**

Run:

```powershell
git check-ignore -v android/key.properties
 git check-ignore -v android/*.jks
```

Expected: both paths are ignored by `android/.gitignore`; the keystore remains outside the repository.

- [ ] **Step 3: Confirm no secret is tracked**

Run:

```powershell
git status --short --ignored android/key.properties
```

Expected: the file appears only under ignored files and no secret value appears in Git status output.

### Task 2: Wire formal signing into Android Gradle

**Files:**
- Modify: `android/app/build.gradle.kts:7-35`
- Test: `test/release_config_test.dart`

- [ ] **Step 1: Write a failing configuration test**

Create a test that reads `android/app/build.gradle.kts` as a repository file and asserts the release configuration contains a conditional formal signing path, does not force the debug signing config, and keeps the existing application ID:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android release uses formal signing when key.properties is available', () {
    final file = File('android/app/build.gradle.kts');
    final source = file.readAsStringSync();

    expect(source, contains('key.properties'));
    expect(source, contains('signingConfigs.create("release")'));
    expect(source, contains('applicationId = "com.example.blog_phone"'));
    expect(source, isNot(contains('signingConfigs.getByName("debug")')));
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
flutter test test/release_config_test.dart
```

Expected: FAIL because the current build file directly assigns the debug signing configuration.

- [ ] **Step 3: Implement conditional release signing**

At the top of `android/app/build.gradle.kts`, load `Properties` and conditionally create a release signing config. The release build must fail with a clear Gradle error when `key.properties` is absent instead of silently falling back to debug signing:

```kotlin
import java.io.FileInputStream
import java.util.Properties

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    ...

    signingConfigs {
        create("release") {
            if (!keyPropertiesFile.exists()) {
                throw GradleException("android/key.properties is required for release signing")
            }
            storeFile = file(keyProperties.getProperty("storeFile"))
            storePassword = keyProperties.getProperty("storePassword")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

Preserve the existing namespace, application ID, Flutter SDK values, Java 17, and Kotlin 17 target.

- [ ] **Step 4: Run the test and static analysis**

Run:

```powershell
flutter test test/release_config_test.dart
flutter analyze
```

Expected: the release configuration test passes and analysis reports no issues.

### Task 3: Set product name and release version metadata

**Files:**
- Modify: `pubspec.yaml:1-5`
- Modify: `lib/app.dart:44-48`
- Modify: `android/app/src/main/AndroidManifest.xml:3-6`
- Modify: `windows/CMakeLists.txt:3-8`
- Modify: `windows/runner/main.cpp:27-32`
- Modify: `windows/runner/Runner.rc:92-99`
- Test: `test/app_metadata_test.dart`

- [ ] **Step 1: Write a failing metadata test**

Create a test that verifies the chosen release metadata:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

def main() {
  test('release metadata uses blog-api and a monotonic build version', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();
    final runner = File('windows/runner/main.cpp').readAsStringSync();

    expect(pubspec, contains('name: blog_phone'));
    expect(pubspec, contains('version: 1.1.0+2'));
    expect(manifest, contains('android:label="blog-api"'));
    expect(cmake, contains('set(BINARY_NAME "blog-api")'));
    expect(runner, contains('window.Create(L"blog-api"'));
  });
}
```

Use `void main()`, not `def main()`; the snippet above intentionally identifies the required assertions and must be corrected to valid Dart before running.

- [ ] **Step 2: Run the test and verify it fails**

Run:

```powershell
flutter test test/app_metadata_test.dart
```

Expected: FAIL because the current product name is `blog_phone`/`Blog Phone` and the version is `1.0.0+1`.

- [ ] **Step 3: Update Flutter, Android, and Windows metadata**

Change `pubspec.yaml` to:

```yaml
name: blog_phone
description: Blog API mobile and desktop client.
publish_to: 'none'
version: 1.1.0+2
```

Change the Flutter `MaterialApp` title to `blog-api`, Android `android:label` to `blog-api`, Windows CMake binary name to `blog-api`, Windows window title to `blog-api`, and Windows resource values to:

```text
CompanyName: blog-api
FileDescription: blog-api
InternalName: blog-api
OriginalFilename: blog-api.exe
ProductName: blog-api
```

Keep `applicationId = "com.example.blog_phone"`; changing it would prevent update-compatible installation over the current app.

- [ ] **Step 4: Run metadata test and analysis**

Run:

```powershell
flutter test test/app_metadata_test.dart
flutter analyze
```

Expected: both pass.

### Task 4: Add signed CI APK construction

**Files:**
- Modify: `.github/workflows/build.yml:1-90`
- Modify: `README.md`

- [ ] **Step 1: Add CI secret validation and keystore reconstruction**

Before the Android build step, add a PowerShell step that fails if any required secret is empty, decodes `ANDROID_KEYSTORE_BASE64` to `android/app/upload-keystore.jks`, and writes `android/key.properties` from the four secrets. Use GitHub secret expressions only in the step environment, never in logs:

```yaml
      - name: Prepare Android signing
        shell: pwsh
        env:
          ANDROID_KEYSTORE_BASE64: ${{ secrets.ANDROID_KEYSTORE_BASE64 }}
          ANDROID_KEYSTORE_PASSWORD: ${{ secrets.ANDROID_KEYSTORE_PASSWORD }}
          ANDROID_KEY_ALIAS: ${{ secrets.ANDROID_KEY_ALIAS }}
          ANDROID_KEY_PASSWORD: ${{ secrets.ANDROID_KEY_PASSWORD }}
        run: |
          $required = @{
            ANDROID_KEYSTORE_BASE64 = $env:ANDROID_KEYSTORE_BASE64
            ANDROID_KEYSTORE_PASSWORD = $env:ANDROID_KEYSTORE_PASSWORD
            ANDROID_KEY_ALIAS = $env:ANDROID_KEY_ALIAS
            ANDROID_KEY_PASSWORD = $env:ANDROID_KEY_PASSWORD
          }
          foreach ($entry in $required.GetEnumerator()) {
            if ([string]::IsNullOrWhiteSpace($entry.Value)) {
              throw "Missing GitHub secret: $($entry.Key)"
            }
          }
          [IO.File]::WriteAllBytes(
            "android/app/upload-keystore.jks",
            [Convert]::FromBase64String($env:ANDROID_KEYSTORE_BASE64)
          )
          @"
          storeFile=upload-keystore.jks
          storePassword=$($env:ANDROID_KEYSTORE_PASSWORD)
          keyAlias=$($env:ANDROID_KEY_ALIAS)
          keyPassword=$($env:ANDROID_KEY_PASSWORD)
          "@ | Set-Content -Path android/key.properties -Encoding ascii
```

Use `upload-keystore.jks` as the relative store path because the Gradle file resolves it relative to the Android project directory.

- [ ] **Step 2: Ensure cleanup runs even when the build fails**

Add a final cleanup step with `if: always()` that removes `android/key.properties` and `android/app/upload-keystore.jks`. Do not print either file’s contents.

- [ ] **Step 3: Update README with one-time secret setup**

Document that the local password file is outside Git and that repository administrators must add these GitHub Secrets before Android CI can build:

```text
ANDROID_KEYSTORE_BASE64
ANDROID_KEYSTORE_PASSWORD
ANDROID_KEY_ALIAS
ANDROID_KEY_PASSWORD
```

Document the PowerShell encoding command from the repository root:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('E:/kmoretti-github/blog_api/secrets/blog-api-release.jks'))
```

Do not place the resulting Base64 value in README or any tracked file.

- [ ] **Step 4: Add workflow source assertions**

Extend `test/release_config_test.dart` to assert the workflow contains `Prepare Android signing`, all four secret names, and a cleanup step with `if: always()`.

- [ ] **Step 5: Run workflow configuration tests**

Run:

```powershell
flutter test test/release_config_test.dart
```

Expected: PASS.

### Task 5: Verify signed local and CI-compatible builds

**Files:**
- Test: `test/release_config_test.dart`
- No tracked signing artifacts allowed: `android/key.properties`, `android/app/upload-keystore.jks`, any `.jks`, `.keystore`, password file.

- [ ] **Step 1: Verify local release signing inputs**

Run:

```powershell
Test-Path android/key.properties
Test-Path E:/kmoretti-github/blog_api/secrets/blog-api-release.jks
Get-Content android/key.properties | Select-String 'storeFile|keyAlias'
```

Expected: both paths exist; output contains only the store path and alias, not password values.

- [ ] **Step 2: Build a local signed APK**

Run:

```powershell
flutter clean
flutter pub get
flutter build apk --release
```

Expected: exit code 0 and `build/app/outputs/flutter-apk/app-release.apk` exists.

- [ ] **Step 3: Verify APK signing and version metadata**

Use Android SDK `apksigner` if available:

```powershell
$apksigner = Get-ChildItem "$env:LOCALAPPDATA/Android/Sdk/build-tools" -Recurse -Filter apksigner.bat | Sort-Object FullName | Select-Object -Last 1
& $apksigner.FullName verify --verbose build/app/outputs/flutter-apk/app-release.apk
```

Expected: signature verification succeeds. If `apksigner` is unavailable, record that limitation and verify the Gradle task exit code plus the presence of the APK.

- [ ] **Step 4: Run the full test and analysis suite**

Run:

```powershell
flutter test
flutter analyze
git diff --check
git status --short
```

Expected: all tests pass, analysis reports no issues, diff check passes, and only intended tracked source/config files are modified.

- [ ] **Step 5: Commit and push only safe files**

Before commit, verify the staged file list excludes all secrets:

```powershell
git add pubspec.yaml lib/app.dart android/app/build.gradle.kts android/app/src/main/AndroidManifest.xml windows/CMakeLists.txt windows/runner/main.cpp windows/runner/Runner.rc .github/workflows/build.yml README.md test/release_config_test.dart
git diff --cached --name-only
```

Then commit and push:

```powershell
git commit -m "build: configure signed blog-api releases"
git push origin HEAD
```

Expected: no `.jks`, `key.properties`, password file, or Base64 secret is committed.
