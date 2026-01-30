# Image Organization Script
# This script must be run directly in PowerShell or via the batch file

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

Write-Host "=== Image Organization Script for 学习笔记 ===" -ForegroundColor Cyan

# Use absolute paths
$vaultRoot = "C:\Users\cong.pi\Documents\obsidian-note"
$notesPath = "C:\Users\cong.pi\Documents\obsidian-note\学习笔记"
$attachmentsPath = "C:\Users\cong.pi\Documents\obsidian-note\学习笔记\attachments"

# Verify paths exist
if (-not (Test-Path $notesPath)) {
    Write-Host "ERROR: Notes directory not found!" -ForegroundColor Red
    exit 1
}

Write-Host "Vault root: $vaultRoot"
Write-Host "Notes directory: $notesPath"
Write-Host "Attachments directory: $attachmentsPath"

# Create attachments directory
if (-not (Test-Path $attachmentsPath)) {
    New-Item -ItemType Directory -Path $attachmentsPath -Force | Out-Null
    Write-Host "Created attachments directory" -ForegroundColor Green
}

# Step 1: Scan for image references
Write-Host "`n=== Step 1: Scanning markdown files ===" -ForegroundColor Cyan
$imageRefs = @{}

# Change to notes directory to avoid path issues
Push-Location $notesPath
$mdFiles = Get-ChildItem -Filter "*.md" -File
Pop-Location

Write-Host "Found $($mdFiles.Count) markdown files to scan"

$scanCount = 0
foreach ($file in $mdFiles) {
    $scanCount++
    if ($scanCount % 10 -eq 0) {
        Write-Host "  Scanned $scanCount files..." -NoNewline -ForegroundColor Gray
        Write-Host "`r" -NoNewline
    }

    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)

        # Obsidian style: ![[image.png]]
        $pattern1 = '!\[\[([^\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]'
        $matches1 = [regex]::Matches($content, $pattern1)
        foreach ($m in $matches1) {
            $img = $m.Groups[1].Value
            # Extract filename only
            if ($img -match '[\\/]') {
                $img = [System.IO.Path]::GetFileName($img)
            }
            if (-not $imageRefs.ContainsKey($img)) {
                $imageRefs[$img] = @()
            }
            if ($imageRefs[$img] -notcontains $file.Name) {
                $imageRefs[$img] += $file.Name
            }
        }

        # Markdown style: ![](image.png)
        $pattern2 = '!\[[^\]]*\]\(([^)]+\.(png|jpg|jpeg|gif|avif|webp))\)'
        $matches2 = [regex]::Matches($content, $pattern2)
        foreach ($m in $matches2) {
            $img = $m.Groups[1].Value
            # Extract filename only
            if ($img -match '[\\/]') {
                $img = [System.IO.Path]::GetFileName($img)
            }
            if (-not $imageRefs.ContainsKey($img)) {
                $imageRefs[$img] = @()
            }
            if ($imageRefs[$img] -notcontains $file.Name) {
                $imageRefs[$img] += $file.Name
            }
        }
    } catch {
        Write-Host "  Error reading $($file.Name): $_" -ForegroundColor Yellow
    }
}

Write-Host "Found $($imageRefs.Count) unique images referenced" -ForegroundColor Green

if ($imageRefs.Count -gt 0) {
    Write-Host "`nSample images found:"
    $imageRefs.Keys | Select-Object -First 10 | ForEach-Object {
        $files = $imageRefs[$_] -join ", "
        Write-Host "  - $_ (in: $files)"
    }
}

# Step 2: Move images
Write-Host "`n=== Step 2: Moving images to attachments ===" -ForegroundColor Cyan
$moved = 0
$alreadyThere = 0
$notFound = 0

foreach ($img in $imageRefs.Keys) {
    $srcPath = Join-Path $vaultRoot $img
    $dstPath = Join-Path $attachmentsPath $img

    if (Test-Path $srcPath) {
        if (-not (Test-Path $dstPath)) {
            Move-Item -Path $srcPath -Destination $dstPath -Force
            Write-Host "  Moved: $img" -ForegroundColor Green
            $moved++
        } else {
            # File exists in both places, remove from root
            Remove-Item -Path $srcPath -Force
            Write-Host "  Removed duplicate from root: $img" -ForegroundColor Yellow
            $moved++
        }
    } elseif (Test-Path $dstPath) {
        $alreadyThere++
    } else {
        Write-Host "  NOT FOUND: $img" -ForegroundColor Red
        $notFound++
    }
}

Write-Host "`nMoved: $moved, Already in attachments: $alreadyThere, Not found: $notFound" -ForegroundColor Green

# Step 3: Update markdown files
Write-Host "`n=== Step 3: Updating image paths in markdown files ===" -ForegroundColor Cyan
$updated = 0

foreach ($file in $mdFiles) {
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName, [System.Text.Encoding]::UTF8)
        $original = $content

        # Update Obsidian style: ![[image.png]] -> ![[./attachments/image.png]]
        # But don't update if already has ./attachments/
        $content = [regex]::Replace($content, '!\[\[(?!\.\/attachments\/)([^/\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]', '![[./attachments/$1]]')

        # Update markdown style: ![](image.png) -> ![](./attachments/image.png)
        $content = [regex]::Replace($content, '!\[([^\]]*)\]\((?!\.\/attachments\/)([^/)]+\.(png|jpg|jpeg|gif|avif|webp))\)', '![$1](./attachments/$2)')

        if ($content -ne $original) {
            [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.Encoding]::UTF8)
            Write-Host "  Updated: $($file.Name)" -ForegroundColor Green
            $updated++
        }
    } catch {
        Write-Host "  Error updating $($file.Name): $_" -ForegroundColor Yellow
    }
}

Write-Host "`nUpdated $updated markdown files" -ForegroundColor Green

# Step 4: Find unused images
Write-Host "`n=== Step 4: Finding unused images in vault root ===" -ForegroundColor Cyan
$allImages = Get-ChildItem -Path $vaultRoot -File | Where-Object {
    $_.Extension -match '\.(png|jpg|jpeg|gif|avif|webp)$'
}
$unused = $allImages | Where-Object { -not $imageRefs.ContainsKey($_.Name) }

Write-Host "Found $($unused.Count) unused images in vault root" -ForegroundColor Yellow

if ($unused.Count -gt 0 -and $unused.Count -le 30) {
    Write-Host "`nUnused images:"
    foreach ($img in $unused) {
        Write-Host "  - $($img.Name)"
    }
} elseif ($unused.Count -gt 30) {
    Write-Host "`nShowing first 30 unused images:"
    for ($i = 0; $i -lt 30; $i++) {
        Write-Host "  - $($unused[$i].Name)"
    }
    Write-Host "  ... and $($unused.Count - 30) more"
}

# Final summary
Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
Write-Host "Markdown files scanned: $($mdFiles.Count)"
Write-Host "Unique images referenced: $($imageRefs.Count)"
Write-Host "Images moved to attachments: $moved"
Write-Host "Markdown files updated: $updated"
Write-Host "Unused images in vault root: $($unused.Count)"
Write-Host "`nNote: Unused images were NOT automatically deleted." -ForegroundColor Yellow
Write-Host "Review the list above and delete manually if needed." -ForegroundColor Yellow
