import os
import re
import shutil
from pathlib import Path

# Configuration
VAULT_ROOT = Path(r"C:\Users\cong.pi\Documents\obsidian-note")
NOTES_DIR = VAULT_ROOT / "学习笔记"
ATTACHMENTS_DIR = NOTES_DIR / "attachments"

print("=== Image Organization Script ===")
print(f"Vault root: {VAULT_ROOT}")
print(f"Notes directory: {NOTES_DIR}")
print(f"Attachments directory: {ATTACHMENTS_DIR}")

# Create attachments directory
ATTACHMENTS_DIR.mkdir(exist_ok=True)
print("Attachments directory ready")

# Step 1: Scan for image references
print("\n=== Step 1: Scanning markdown files ===")
image_refs = {}
md_files = list(NOTES_DIR.glob("*.md"))
print(f"Found {len(md_files)} markdown files")

for md_file in md_files:
    try:
        content = md_file.read_text(encoding='utf-8')

        # Obsidian style: ![[image.png]]
        pattern1 = r'!\[\[([^\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]'
        for match in re.finditer(pattern1, content):
            img = match.group(1)
            # Extract filename only
            img = os.path.basename(img)
            if img not in image_refs:
                image_refs[img] = []
            if md_file.name not in image_refs[img]:
                image_refs[img].append(md_file.name)

        # Markdown style: ![](image.png)
        pattern2 = r'!\[[^\]]*\]\(([^)]+\.(png|jpg|jpeg|gif|avif|webp))\)'
        for match in re.finditer(pattern2, content):
            img = match.group(1)
            # Extract filename only
            img = os.path.basename(img)
            if img not in image_refs:
                image_refs[img] = []
            if md_file.name not in image_refs[img]:
                image_refs[img].append(md_file.name)
    except Exception as e:
        print(f"  Error reading {md_file.name}: {e}")

print(f"Found {len(image_refs)} unique images referenced")

if image_refs:
    print("\nSample images:")
    for img in list(image_refs.keys())[:10]:
        files = ", ".join(image_refs[img])
        print(f"  - {img} (in: {files})")

# Step 2: Move images
print("\n=== Step 2: Moving images ===")
moved = 0
already_there = 0
not_found = 0

for img in image_refs.keys():
    src = VAULT_ROOT / img
    dst = ATTACHMENTS_DIR / img

    if src.exists():
        if not dst.exists():
            shutil.move(str(src), str(dst))
            print(f"  Moved: {img}")
            moved += 1
        else:
            src.unlink()
            print(f"  Removed duplicate: {img}")
            moved += 1
    elif dst.exists():
        already_there += 1
    else:
        print(f"  NOT FOUND: {img}")
        not_found += 1

print(f"\nMoved: {moved}, Already in attachments: {already_there}, Not found: {not_found}")

# Step 3: Update markdown files
print("\n=== Step 3: Updating image paths ===")
updated = 0

for md_file in md_files:
    try:
        content = md_file.read_text(encoding='utf-8')
        original = content

        # Update Obsidian style: ![[image.png]] -> ![[./attachments/image.png]]
        content = re.sub(
            r'!\[\[(?!\.\/attachments\/)([^/\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]',
            r'![[./attachments/\1]]',
            content
        )

        # Update markdown style: ![](image.png) -> ![](./attachments/image.png)
        content = re.sub(
            r'!\[([^\]]*)\]\((?!\.\/attachments\/)([^/)]+\.(png|jpg|jpeg|gif|avif|webp))\)',
            r'![\1](./attachments/\2)',
            content
        )

        if content != original:
            md_file.write_text(content, encoding='utf-8')
            print(f"  Updated: {md_file.name}")
            updated += 1
    except Exception as e:
        print(f"  Error updating {md_file.name}: {e}")

print(f"\nUpdated {updated} markdown files")

# Step 4: Find unused images
print("\n=== Step 4: Finding unused images ===")
all_images = [f for f in VAULT_ROOT.glob("*") if f.is_file() and f.suffix.lower() in ['.png', '.jpg', '.jpeg', '.gif', '.avif', '.webp']]
unused = [img for img in all_images if img.name not in image_refs]

print(f"Found {len(unused)} unused images in vault root")

if unused:
    if len(unused) <= 30:
        print("\nUnused images:")
        for img in unused:
            print(f"  - {img.name}")
    else:
        print("\nShowing first 30 unused images:")
        for img in unused[:30]:
            print(f"  - {img.name}")
        print(f"  ... and {len(unused) - 30} more")

# Summary
print("\n=== SUMMARY ===")
print(f"Markdown files scanned: {len(md_files)}")
print(f"Unique images referenced: {len(image_refs)}")
print(f"Images moved to attachments: {moved}")
print(f"Markdown files updated: {updated}")
print(f"Unused images in vault root: {len(unused)}")
print("\nNote: Unused images were NOT automatically deleted.")
print("Review the list above and delete manually if needed.")
