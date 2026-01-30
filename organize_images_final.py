#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Image Organization Script for Obsidian Vault
Organizes images by moving them to attachments/ subdirectories next to referencing markdown files
"""

import os
import re
import shutil
import json
from pathlib import Path
from collections import defaultdict
from datetime import datetime

# Configuration
VAULT_ROOT = Path(__file__).parent
EXCLUDE_DIRS = {'.obsidian', '.git', '.claude', 'node_modules'}
IMAGE_EXTENSIONS = {'.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.avif'}
LOG_FILE = VAULT_ROOT / 'image_organization_log.txt'
UNUSED_FILE = VAULT_ROOT / 'unused_images.txt'
REFS_FILE = VAULT_ROOT / 'image_references.json'

# Regex patterns for image references
OBSIDIAN_PATTERN = r'!\[\[([^\]]+\.(?:png|jpg|jpeg|gif|svg|webp|avif))\]\]'
MARKDOWN_PATTERN = r'!\[[^\]]*\]\(([^)]+\.(?:png|jpg|jpeg|gif|svg|webp|avif))\)'

class Logger:
    def __init__(self, log_file):
        self.log_file = log_file
        self.messages = []

    def log(self, message, level='INFO'):
        timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        log_msg = f"[{timestamp}] [{level}] {message}"
        self.messages.append(log_msg)
        print(log_msg)

    def save(self):
        with open(self.log_file, 'w', encoding='utf-8') as f:
            f.write('\n'.join(self.messages))

def is_local_image(path):
    """Check if the image reference is a local file (not external URL or Typora cache)"""
    path_lower = path.lower()
    if path_lower.startswith(('http://', 'https://')):
        return False
    if 'typora' in path_lower or 'appdata' in path_lower:
        return False
    return True

def extract_filename(path):
    """Extract just the filename from a path"""
    # Handle both forward and backward slashes
    path = path.replace('\\', '/')
    # Remove leading ./ or ./
    path = path.lstrip('./')
    # Get just the filename
    return Path(path).name

def scan_markdown_files(logger):
    """Scan all markdown files and extract image references"""
    logger.log("=== Phase 1: Scanning markdown files ===")

    image_refs = defaultdict(list)  # image_name -> [list of (md_file_path, reference_type)]
    md_files_processed = 0

    for md_file in VAULT_ROOT.rglob('*.md'):
        # Skip excluded directories
        if any(excluded in md_file.parts for excluded in EXCLUDE_DIRS):
            continue

        md_files_processed += 1

        try:
            with open(md_file, 'r', encoding='utf-8') as f:
                content = f.read()

            # Find Obsidian-style references
            for match in re.finditer(OBSIDIAN_PATTERN, content, re.IGNORECASE):
                img_path = match.group(1)
                if is_local_image(img_path):
                    img_name = extract_filename(img_path)
                    image_refs[img_name].append((md_file, 'obsidian'))

            # Find Markdown-style references
            for match in re.finditer(MARKDOWN_PATTERN, content, re.IGNORECASE):
                img_path = match.group(1)
                if is_local_image(img_path):
                    img_name = extract_filename(img_path)
                    image_refs[img_name].append((md_file, 'markdown'))

        except Exception as e:
            logger.log(f"Error reading {md_file}: {e}", 'ERROR')

    logger.log(f"Processed {md_files_processed} markdown files")
    logger.log(f"Found {len(image_refs)} unique images referenced")

    return dict(image_refs)

def find_image_file(image_name, logger):
    """Find the actual image file in the vault"""
    # First check root directory
    root_path = VAULT_ROOT / image_name
    if root_path.exists() and root_path.is_file():
        return root_path

    # Then check all subdirectories (including existing attachments folders)
    for img_file in VAULT_ROOT.rglob(image_name):
        if any(excluded in img_file.parts for excluded in EXCLUDE_DIRS):
            continue
        if img_file.is_file():
            return img_file

    return None

def copy_images(image_refs, logger):
    """Copy referenced images to attachments folders"""
    logger.log("\n=== Phase 2: Copying images to attachments folders ===")

    stats = {
        'copied': 0,
        'skipped_exists': 0,
        'skipped_not_found': 0,
        'errors': 0
    }

    for img_name, refs in image_refs.items():
        # Find the source image file
        src_file = find_image_file(img_name, logger)

        if not src_file:
            logger.log(f"Image not found: {img_name}", 'WARNING')
            stats['skipped_not_found'] += 1
            continue

        # Group references by directory
        ref_dirs = set()
        for md_file, _ in refs:
            ref_dirs.add(md_file.parent)

        # Copy to each directory's attachments folder
        for ref_dir in ref_dirs:
            attachments_dir = ref_dir / 'attachments'
            attachments_dir.mkdir(exist_ok=True)

            dst_file = attachments_dir / img_name

            # Check if already in the right place
            if src_file.resolve() == dst_file.resolve():
                logger.log(f"Already in place: {img_name} in {ref_dir.name}/attachments/")
                stats['skipped_exists'] += 1
                continue

            # Check if destination already exists
            if dst_file.exists():
                # Compare file sizes to see if they're the same
                if src_file.stat().st_size == dst_file.stat().st_size:
                    logger.log(f"Skipped (already exists): {img_name} -> {ref_dir.name}/attachments/")
                    stats['skipped_exists'] += 1
                else:
                    # Handle name conflict
                    base_name = dst_file.stem
                    ext = dst_file.suffix
                    counter = 1
                    while dst_file.exists():
                        dst_file = attachments_dir / f"{base_name}_{counter}{ext}"
                        counter += 1
                    logger.log(f"Name conflict resolved: {img_name} -> {dst_file.name}")

            try:
                shutil.copy2(src_file, dst_file)
                logger.log(f"Copied: {img_name} -> {ref_dir.name}/attachments/")
                stats['copied'] += 1
            except Exception as e:
                logger.log(f"Error copying {img_name}: {e}", 'ERROR')
                stats['errors'] += 1

    logger.log(f"\nCopy statistics:")
    logger.log(f"  Copied: {stats['copied']}")
    logger.log(f"  Skipped (exists): {stats['skipped_exists']}")
    logger.log(f"  Skipped (not found): {stats['skipped_not_found']}")
    logger.log(f"  Errors: {stats['errors']}")

    return stats

def update_markdown_references(image_refs, logger):
    """Update image references in markdown files"""
    logger.log("\n=== Phase 3: Updating markdown file references ===")

    files_updated = 0
    refs_updated = 0

    # Group by markdown file
    md_files = defaultdict(list)
    for img_name, refs in image_refs.items():
        for md_file, ref_type in refs:
            md_files[md_file].append((img_name, ref_type))

    for md_file, images in md_files.items():
        try:
            with open(md_file, 'r', encoding='utf-8') as f:
                content = f.read()

            original_content = content

            for img_name, ref_type in images:
                if ref_type == 'obsidian':
                    # Update Obsidian format: ![[image.png]] -> ![[attachments/image.png]]
                    # But don't update if already pointing to attachments
                    pattern = rf'!\[\[(?!attachments/)(?:[^/\]]*/)?' + re.escape(img_name) + r'\]\]'
                    replacement = f'![[attachments/{img_name}]]'
                    content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)

                elif ref_type == 'markdown':
                    # Update Markdown format: ![](image.png) -> ![](attachments/image.png)
                    # Handle both ./image.png and image.png
                    pattern = rf'!\[([^\]]*)\]\((?!attachments/)(?:\./)?(?:[^/)]*/)?' + re.escape(img_name) + r'\)'
                    replacement = rf'![\1](attachments/{img_name})'
                    content = re.sub(pattern, replacement, content, flags=re.IGNORECASE)

            if content != original_content:
                with open(md_file, 'w', encoding='utf-8') as f:
                    f.write(content)

                rel_path = md_file.relative_to(VAULT_ROOT)
                logger.log(f"Updated: {rel_path}")
                files_updated += 1
                refs_updated += len(images)

        except Exception as e:
            logger.log(f"Error updating {md_file}: {e}", 'ERROR')

    logger.log(f"\nUpdate statistics:")
    logger.log(f"  Files updated: {files_updated}")
    logger.log(f"  References updated: {refs_updated}")

    return files_updated

def find_unused_images(image_refs, logger):
    """Find images in root directory that are not referenced"""
    logger.log("\n=== Phase 4: Finding unused images ===")

    referenced_images = set(image_refs.keys())
    unused_images = []

    # Scan root directory for image files
    for item in VAULT_ROOT.iterdir():
        if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS:
            if item.name not in referenced_images:
                unused_images.append(item)

    logger.log(f"Found {len(unused_images)} unused images in root directory")

    # Save to file
    if unused_images:
        with open(UNUSED_FILE, 'w', encoding='utf-8') as f:
            f.write("# Unused Images in Root Directory\n")
            f.write(f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"# Total: {len(unused_images)} files\n\n")
            for img in sorted(unused_images):
                f.write(f"{img.name}\n")
        logger.log(f"Unused images list saved to: {UNUSED_FILE}")

    return unused_images

def save_references_map(image_refs, logger):
    """Save image references map to JSON for debugging"""
    refs_data = {}
    for img_name, refs in image_refs.items():
        refs_data[img_name] = [
            {
                'file': str(md_file.relative_to(VAULT_ROOT)),
                'type': ref_type
            }
            for md_file, ref_type in refs
        ]

    with open(REFS_FILE, 'w', encoding='utf-8') as f:
        json.dump(refs_data, f, indent=2, ensure_ascii=False)

    logger.log(f"References map saved to: {REFS_FILE}")

def main():
    logger = Logger(LOG_FILE)

    logger.log("=" * 60)
    logger.log("Image Organization Script")
    logger.log(f"Vault root: {VAULT_ROOT}")
    logger.log("=" * 60)

    # Phase 1: Scan markdown files
    image_refs = scan_markdown_files(logger)

    # Save references map
    save_references_map(image_refs, logger)

    # Phase 2: Copy images
    copy_stats = copy_images(image_refs, logger)

    # Phase 3: Update markdown references
    files_updated = update_markdown_references(image_refs, logger)

    # Phase 4: Find unused images
    unused_images = find_unused_images(image_refs, logger)

    # Summary
    logger.log("\n" + "=" * 60)
    logger.log("SUMMARY")
    logger.log("=" * 60)
    logger.log(f"Referenced images: {len(image_refs)}")
    logger.log(f"Images copied: {copy_stats['copied']}")
    logger.log(f"Markdown files updated: {files_updated}")
    logger.log(f"Unused images found: {len(unused_images)}")
    logger.log("=" * 60)

    # Save log
    logger.save()
    logger.log(f"\nLog saved to: {LOG_FILE}")

    if unused_images:
        logger.log(f"\nNext steps:")
        logger.log(f"1. Review unused images in: {UNUSED_FILE}")
        logger.log(f"2. Verify images display correctly in Obsidian")
        logger.log(f"3. If everything looks good, delete unused images")
        logger.log(f"4. Commit changes with git")

if __name__ == '__main__':
    main()
