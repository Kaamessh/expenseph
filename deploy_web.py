import os
import shutil
import subprocess
import sys

def run_command(args, cwd=None):
    cmd_str = " ".join(args)
    print(f"Executing: {cmd_str} in {cwd or '.'}")
    # Using shell=True for windows compatibility
    result = subprocess.run(cmd_str, cwd=cwd, shell=True)
    if result.returncode != 0:
        print(f"Error: Command failed with exit code {result.returncode}")
        sys.exit(result.returncode)

def main():
    # Verify we are in the root directory
    if not os.path.exists("frontend") or not os.path.exists("backend"):
        print("Error: Make sure you run this script from the workspace root (C:\\Expense).")
        sys.exit(1)

    # 1. Build Flutter Web
    print("\n=== Step 1: Building Flutter Web Application ===")
    frontend_dir = os.path.abspath("frontend")
    run_command(["flutter", "build", "web", "--release"], cwd=frontend_dir)
    
    # 2. Copy build files to backend/static
    print("\n=== Step 2: Copying compiled assets to backend/static ===")
    build_dir = os.path.join(frontend_dir, "build", "web")
    static_dir = os.path.abspath(os.path.join("backend", "static"))
    
    if os.path.exists(static_dir):
        print(f"Cleaning old static directory: {static_dir}")
        shutil.rmtree(static_dir)
        
    print(f"Copying web build: {build_dir} -> {static_dir}")
    shutil.copytree(build_dir, static_dir)
    
    # 3. Commit and push to GitHub
    print("\n=== Step 3: Committing and Pushing to GitHub ===")
    run_command(["git", "add", "."])
    # Ignore error if there are no changes to commit
    try:
        subprocess.run("git commit -m \"Deploy Flutter Web frontend to Vercel\"", shell=True, check=True)
    except subprocess.CalledProcessError:
        print("No changes to commit, proceeding to push.")
        
    run_command(["git", "push", "origin", "main"])
    
    print("\n🎉 Web Deployment script finished successfully!")
    print("Vercel will automatically rebuild your deployment. Once the Vercel build is complete,")
    print("any user opening your link: https://expenseph.vercel.app/ in their phone's browser will see the live visual application!")

if __name__ == "__main__":
    main()
