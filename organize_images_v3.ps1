# Image Organization Script for 学习笔记 directory
# This script organizes images referenced in markdown files

$ErrorActionPreference = "Continue"

# Use full paths directly to avoid encoding issues
$notesDir = "C:\Users\cong.pi\Documents\obsidian-note\学习笔记"
$vaultRoot = "C:\Users\cong.pi\Documents\obsidian-note"
$attachmentsDir = "$notesDir\attachments"

Write-Host "Vault root: $vaultRoot"
Write-Host "Notes directory: $notesDir"
Write-Host "Attachments directory: $attachmentsDir"

# Verify the directory exists
if (-not (Test-Path $notesDir)) {
    Write-Host "ERROR: Notes directory not found: $notesDir" -ForegroundColor Red
    exit 1
}

# Create attachments directory if it doesn't exist
if (-not (Test-Path $attachmentsDir)) {
    New-Item -ItemType Directory -Path $attachmentsDir -Force | Out-Null
    Write-Host "Created directory: $attachmentsDir"
} else {
    Write-Host "Attachments directory already exists"
}

# Step 1: Collect all image references from markdown files
Write-Host "`n=== Step 1: Scanning markdown files for image references ==="
$imageReferences = @{}

# Use Get-ChildItem which handles Chinese characters better
$mdFiles = Get-ChildItem -Path $notesDir -Filter "*.md" -File
Write-Host "Found $($mdFiles.Count) markdown files to scan"

foreach ($mdFile in $mdFiles) {
    try {
        $content = Get-Content -Path $mdFile.FullName -Raw -Encoding UTF8

        # Match Obsidian-style: ![[image.png]]
        $obsidianPattern = '!\[\[([^\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]'
        $obsidianMatches = [regex]::Matches($content, $obsidianPattern)
        foreach ($match in $obsidianMatches) {
            $imageName = $match.Groups[1].Value
            # Remove any path prefix if present
            if ($imageName -match '[/\\]') {
                $imageName = Split-Path $imageName -Leaf
            }
            if (-not $imageReferences.ContainsKey($imageName)) {
                $imageReferences[$imageName] = @()
            }
            $imageReferences[$imageName] += $mdFile.Name
            Write-Host "  Found Obsidian-style: $imageName in $($mdFile.Name)"
        }

        # Match markdown-style: ![](image.png) or ![text](image.png)
        $mdPattern = '!\[[^\]]*\]\(([^)]+\.(png|jpg|jpeg|gif|avif|webp))\)'
        $mdMatches = [regex]::Matches($content, $mdPattern)
        foreach ($match in $mdMatches) {
            $imagePath = $match.Groups[1].Value
            # Extract just the filename
            if ($imagePath -match '[/\\]') {
                $imageName = Split-Path $imagePath -Leaf
            } else {
                $imageName = $imagePath
            }
            if (-not $imageReferences.ContainsKey($imageName)) {
                $imageReferences[$imageName] = @()
            }
            $imageReferences[$imageName] += $mdFile.Name
            Write-Host "  Found markdown-style: $imageName in $($mdFile.Name)"
        }
    } catch {
        Write-Host "  Error processing $($mdFile.Name): $_" -ForegroundColor Yellow
    }
}

Write-Host "`nFound $($imageReferences.Count) unique images referenced in markdown files"

# Step 2: Move images from vault root to attachments directory
Write-Host "`n=== Step 2: Moving images to attachments directory ==="
$movedCount = 0
$alreadyInPlace = 0

foreach ($imageName in $imageReferences.Keys) {
    $sourceInRoot = "$vaultRoot\$imageName"
    $sourceInAttachments = "$attachmentsDir\$imageName"
    $destination = "$attachmentsDir\$imageName"

    if (Test-Path $sourceInRoot) {
        if (-not (Test-Path $destination)) {
            Move-Item -Path $sourceInRoot -Destination $destination -Force
            Write-Host "Moved: $imageName"
            $movedCount++
        } else {
            Write-Host "Already exists in attachments: $imageName"
            # Remove from root if duplicate
            Remove-Item -Path $sourceInRoot -Force
            $movedCount++
        }
    } elseif (Test-Path $sourceInAttachments) {
        Write-Host "Already in place: $imageName"
        $alreadyInPlace++
    } else {
        Write-Host "WARNING: Image not found: $imageName" -ForegroundColor Yellow
    }
}

Write-Host "Moved $movedCount images, $alreadyInPlace already in place"

# Step 3: Update image paths in markdown files
Write-Host "`n=== Step 3: Updating image paths in markdown files ==="
$updatedFiles = 0

foreach ($mdFile in $mdFiles) {
    try {
        $content = Get-Content -Path $mdFile.FullName -Raw -Encoding UTF8
        $originalContent = $content

        # Update Obsidian-style references that don't already have ./attachments/ path
        # ![[image.png]] -> ![[./attachments/image.png]]
        $content = [regex]::Replace($content, '!\[\[(?!\.\/attachments\/)([^/\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]', '![[./attachments/$1]]')

        # Update markdown-style references that don't already have ./attachments/ path
        # ![](image.png) -> ![](./attachments/image.png)
        $content = [regex]::Replace($content, '!\[([^\]]*)\]\((?!\.\/attachments\/)([^/)]+\.(png|jpg|jpeg|gif|avif|webp))\)', '![$1](./attachments/$2)')

        if ($content -ne $originalContent) {
            Set-Content -Path $mdFile.FullName -Value $content -Encoding UTF8 -NoNewline
            Write-Host "Updated: $($mdFile.Name)"
            $updatedFiles++
        }
    } catch {
        Write-Host "  Error updating $($mdFile.Name): $_" -ForegroundColor Yellow
    }
}

Write-Host "Updated $updatedFiles markdown files"

# Step 4: Find and list unused images in vault root
Write-Host "`n=== Step 4: Finding unused images in vault root ==="
$allImages = Get-ChildItem $vaultRoot -File | Where-Object { $_.Extension -match '\.(png|jpg|jpeg|gif|avif|webp)$' }
$unusedImages = @()

foreach ($image in $allImages) {
    if (-not $imageReferences.ContainsKey($image.Name)) {
        $unusedImages += $image
    }
}

Write-Host "Found $($unusedImages.Count) unused images in vault root"

if ($unusedImages.Count -gt 0 -and $unusedImages.Count -le 20) {
    Write-Host "`nUnused images:"
    foreach ($img in $unusedImages) {
        Write-Host "  - $($img.Name)"
    }
} elseif ($unusedImages.Count -gt 20) {
    Write-Host "`nShowing first 20 unused images:"
    for ($i = 0; $i -lt 20; $i++) {
        Write-Host "  - $($unusedImages[$i].Name)"
    }
    Write-Host "  ... and $($unusedImages.Count - 20) more"
}

Write-Host "`n=== Image organization complete ==="
Write-Host "Summary:"
Write-Host "  - Images referenced: $($imageReferences.Count)"
Write-Host "  - Images moved: $movedCount"
Write-Host "  - Files updated: $updatedFiles"
Write-Host "  - Unused images found: $($unusedImages.Count)"
Write-Host "`nNote: Unused images were NOT deleted. Review them manually if needed."
