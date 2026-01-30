# Image Organization Script for 学习笔记 directory

$vaultRoot = "C:\Users\cong.pi\Documents\obsidian-note"
$notesDir = Join-Path $vaultRoot "学习笔记"
$attachmentsDir = Join-Path $notesDir "attachments"

# Create attachments directory if it doesn't exist
if (-not (Test-Path $attachmentsDir)) {
    New-Item -ItemType Directory -Path $attachmentsDir -Force | Out-Null
    Write-Host "Created directory: $attachmentsDir"
}

# Step 1: Collect all image references from markdown files
Write-Host "`n=== Step 1: Scanning markdown files for image references ==="
$imageReferences = @{}
$mdFiles = [System.IO.Directory]::GetFiles($notesDir, "*.md")

foreach ($mdFilePath in $mdFiles) {
    $mdFileName = [System.IO.Path]::GetFileName($mdFilePath)
    $content = [System.IO.File]::ReadAllText($mdFilePath, [System.Text.Encoding]::UTF8)

    # Match Obsidian-style: ![[image.png]]
    $obsidianPattern = '!\[\[([^\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]'
    $obsidianMatches = [regex]::Matches($content, $obsidianPattern)
    foreach ($match in $obsidianMatches) {
        $imageName = $match.Groups[1].Value
        # Remove any path prefix if present
        $imageName = Split-Path $imageName -Leaf
        if (-not $imageReferences.ContainsKey($imageName)) {
            $imageReferences[$imageName] = @()
        }
        $imageReferences[$imageName] += $mdFileName
        Write-Host "  Found Obsidian-style: $imageName in $mdFileName"
    }

    # Match markdown-style: ![](image.png) or ![text](image.png)
    $mdPattern = '!\[[^\]]*\]\(([^)]+\.(png|jpg|jpeg|gif|avif|webp))\)'
    $mdMatches = [regex]::Matches($content, $mdPattern)
    foreach ($match in $mdMatches) {
        $imagePath = $match.Groups[1].Value
        # Extract just the filename
        $imageName = Split-Path $imagePath -Leaf
        if (-not $imageReferences.ContainsKey($imageName)) {
            $imageReferences[$imageName] = @()
        }
        $imageReferences[$imageName] += $mdFileName
        Write-Host "  Found markdown-style: $imageName in $mdFileName"
    }
}

Write-Host "`nFound $($imageReferences.Count) unique images referenced in markdown files"

# Step 2: Move images from vault root to attachments directory
Write-Host "`n=== Step 2: Moving images to attachments directory ==="
$movedCount = 0
$alreadyInPlace = 0

foreach ($imageName in $imageReferences.Keys) {
    $sourceInRoot = Join-Path $vaultRoot $imageName
    $sourceInAttachments = Join-Path $attachmentsDir $imageName
    $destination = Join-Path $attachmentsDir $imageName

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

foreach ($mdFilePath in $mdFiles) {
    $mdFileName = [System.IO.Path]::GetFileName($mdFilePath)
    $content = [System.IO.File]::ReadAllText($mdFilePath, [System.Text.Encoding]::UTF8)
    $originalContent = $content
    $changed = $false

    # Update Obsidian-style references that don't have path
    # ![[image.png]] -> ![[./attachments/image.png]]
    $content = [regex]::Replace($content, '!\[\[([^/\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]', '![[./attachments/$1]]')

    # Update markdown-style references
    # ![](image.png) -> ![](./attachments/image.png)
    # ![](251028-171506.avif) -> ![](./attachments/251028-171506.avif)
    $content = [regex]::Replace($content, '!\[([^\]]*)\]\(([^/)]+\.(png|jpg|jpeg|gif|avif|webp))\)', '![$1](./attachments/$2)')

    if ($content -ne $originalContent) {
        [System.IO.File]::WriteAllText($mdFilePath, $content, [System.Text.Encoding]::UTF8)
        Write-Host "Updated: $mdFileName"
        $updatedFiles++
        $changed = $true
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

if ($unusedImages.Count -gt 0) {
    Write-Host "`nUnused images:"
    foreach ($img in $unusedImages) {
        Write-Host "  - $($img.Name)"
    }

    $response = Read-Host "`nDo you want to delete these unused images? (yes/no)"
    if ($response -eq "yes") {
        foreach ($img in $unusedImages) {
            Remove-Item -Path $img.FullName -Force
            Write-Host "Deleted: $($img.Name)"
        }
        Write-Host "Deleted $($unusedImages.Count) unused images"
    } else {
        Write-Host "Skipped deletion of unused images"
    }
}

Write-Host "`n=== Image organization complete ==="
Write-Host "Summary:"
Write-Host "  - Images referenced: $($imageReferences.Count)"
Write-Host "  - Images moved: $movedCount"
Write-Host "  - Files updated: $updatedFiles"
Write-Host "  - Unused images found: $($unusedImages.Count)"
