import os
import re

def main():
    manifest_path = 'frontend/android/app/src/main/AndroidManifest.xml'
    if not os.path.exists(manifest_path):
        print(f"File not found: {manifest_path}")
        return

    with open(manifest_path, 'r', encoding='utf-8') as file:
        content = file.read()

    # Ensure internet permission is added (usually Flutter does this, but let's be sure)
    internet_permission = '<uses-permission android:name="android.permission.INTERNET"/>'
    if 'android.permission.INTERNET' not in content:
        # Insert it before <application tag
        content = content.replace('<application', f'{internet_permission}\n    <application')
        print("Added INTERNET permission.")

    # Enable cleartext traffic
    if 'android:usesCleartextTraffic="true"' not in content:
        # Check if usesCleartextTraffic is already set to false
        if 'android:usesCleartextTraffic="false"' in content:
            content = content.replace('android:usesCleartextTraffic="false"', 'android:usesCleartextTraffic="true"')
        else:
            # Inject it into the <application tag
            content = content.replace('<application', '<application\n        android:usesCleartextTraffic="true"')
        print("Enabled usesCleartextTraffic.")

    with open(manifest_path, 'w', encoding='utf-8') as file:
        file.write(content)

    print("AndroidManifest.xml patching completed.")

    gradle_path = 'frontend/android/app/build.gradle.kts'
    if os.path.exists(gradle_path):
        with open(gradle_path, 'r', encoding='utf-8') as file:
            gradle_content = file.read()

        print("=== ORIGINAL GRADLE CONTENT ===")
        print(gradle_content)
        print("=== END ORIGINAL GRADLE CONTENT ===")

        updated = False
        if 'isCoreLibraryDesugaringEnabled' not in gradle_content:
            gradle_content = re.sub(
                r'(compileOptions\s*\{)',
                r'\1\n        isCoreLibraryDesugaringEnabled = true',
                gradle_content
            )
            print("Enabled isCoreLibraryDesugaringEnabled in build.gradle.kts.")
            updated = True

        if 'coreLibraryDesugaring' not in gradle_content:
            gradle_content = re.sub(
                r'(dependencies\s*\{)',
                r'\1\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
                gradle_content
            )
            print("Added coreLibraryDesugaring dependency to build.gradle.kts.")
            updated = True

        if updated:
            with open(gradle_path, 'w', encoding='utf-8') as file:
                file.write(gradle_content)
            print("build.gradle.kts patching completed.")
        else:
            print("build.gradle.kts already patched or no changes needed.")
    else:
        print(f"Gradle file not found: {gradle_path}")

if __name__ == '__main__':
    main()
