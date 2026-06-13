import os

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

if __name__ == '__main__':
    main()
