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

    # Add queries block for url_launcher package visibility support on Android 11+
    queries_block = """    <queries>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="https" />
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW" />
            <data android:scheme="http" />
        </intent>
    </queries>"""
    if '<queries>' not in content:
        content = content.replace('<application', f'{queries_block}\n    <application')
        print("Added queries block for url_launcher support.")

    with open(manifest_path, 'w', encoding='utf-8') as file:
        file.write(content)

    print("AndroidManifest.xml patching completed.")

    gradle_path = 'frontend/android/app/build.gradle.kts'
    if os.path.exists(gradle_path):
        with open(gradle_path, 'r', encoding='utf-8') as file:
            gradle_content = file.read()

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
            if 'dependencies' in gradle_content:
                gradle_content = re.sub(
                    r'(dependencies\s*\{)',
                    r'\1\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")',
                    gradle_content
                )
                print("Added coreLibraryDesugaring to existing dependencies block.")
            else:
                gradle_content += '\n\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
                print("Appended new dependencies block with coreLibraryDesugaring dependency.")
            updated = True

        if updated:
            with open(gradle_path, 'w', encoding='utf-8') as file:
                file.write(gradle_content)
            print("build.gradle.kts patching completed.")
        else:
            print("build.gradle.kts already patched or no changes needed.")
    else:
        print(f"Gradle file not found: {gradle_path}")

    # Patch jcenter() and namespace for AGP 8+ out of pub-cache plugins (e.g. ota_update) to fix Android builds
    import glob
    import re
    pub_cache = os.path.expanduser("~/.pub-cache/hosted/pub.dev")
    if not os.path.exists(pub_cache):
        pub_cache = os.path.expanduser("~/AppData/Local/Pub/Cache/hosted/pub.dev")
    
    if os.path.exists(pub_cache):
        for root_dir, _, files in os.walk(pub_cache):
            if 'build.gradle' in files:
                filepath = os.path.join(root_dir, 'build.gradle')
                try:
                    with open(filepath, 'r', encoding='utf-8') as f:
                        content = f.read()
                    
                    changed = False
                    if 'jcenter()' in content:
                        content = content.replace('jcenter()', 'mavenCentral()')
                        changed = True
                    
                    if 'namespace' not in content and 'android {' in content:
                        # Try to find AndroidManifest.xml to extract package name
                        manifest_path = os.path.join(root_dir, 'src', 'main', 'AndroidManifest.xml')
                        if os.path.exists(manifest_path):
                            with open(manifest_path, 'r', encoding='utf-8') as mf:
                                m_content = mf.read()
                                match = re.search(r'package="([^"]+)"', m_content)
                                if match:
                                    pkg = match.group(1)
                                    content = re.sub(r'(android\s*\{)', rf'\1\n    namespace "{pkg}"', content, count=1)
                                    changed = True
                    
                    if changed:
                        with open(filepath, 'w', encoding='utf-8') as f:
                            f.write(content)
                        print(f"Patched build.gradle in {filepath}")
                except Exception as e:
                    print(f"Error patching {filepath}: {e}")

if __name__ == '__main__':
    main()
