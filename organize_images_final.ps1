# Image Organization Script - Final Version
# Run this directly in PowerShell (not through bash)

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Change to the vault directory
Set-Location "C:\Users\cong.pi\Documents\obsidian-note"

$notesDir = Get-Item ".\学习笔记"
$vaultRoot = Get-Location
$attachmentsDir = Join-Path $notesDir.FullName "attachments"

Write-Host "Working directory: $($vaultRoot.Path)"
Write-Host "Notes directory: $($notesDir.FullName)"
Write-Host "Attachments directory: $attachmentsDir"

# Create attachments directory if it doesn't exist
if (-not (Test-Path $attachmentsDir)) {
    New-Item -ItemType Directory -Path $attachmentsDir -Force | Out-Null
    Write-Host "Created attachments directory"
}

# Step 1: Scan for image references
Write-Host "`n=== Scanning for image references ==="
$imageRefs = @{}
$mdFiles = Get-ChildItem -Path $notesDir.FullName -Filter "*.md" -File

Write-Host "Found $($mdFiles.Count) markdown files"

foreach ($file in $mdFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8

    # Obsidian style: ![[image.png]]
    $matches1 = [regex]::Matches($content, '!\[\[([^\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]')
    foreach ($m in $matches1) {
        $img = $m.Groups[1].Value
        if ($img -match '[/\\]') { $img = Split-Path $img -Leaf }
        if (-not $imageRefs.ContainsKey($img)) { $imageRefs[$img] = @() }
        $imageRefs[$img] += $file.Name
    }

    # Markdown style: ![](image.png)
    $matches2 = [regex]::Matches($content, '!\[[^\]]*\]\(([^)]+\.(png|jpg|jpeg|gif|avif|webp))\)')
    foreach ($m in $matches2) {
        $img = $m.Groups[1].Value
        if ($img -match '[/\\]') { $img = Split-Path $img -Leaf }
        if (-not $imageRefs.ContainsKey($img)) { $imageRefs[$img] = @() }
        $imageRefs[$img] += $file.Name
    }
}

Write-Host "Found $($imageRefs.Count) unique images referenced"

# Step 2: Move images
Write-Host "`n=== Moving images ==="
$moved = 0
$existing = 0

foreach ($img in $imageRefs.Keys) {
    $src = Join-Path $vaultRoot.Path $img
    $dst = Join-Path $attachmentsDir $img

    if (Test-Path $src) {
        if (-not (Test-Path $dst)) {
            Move-Item $src $dst -Force
            Write-Host "Moved: $img"
            $moved++
        } else {
            Remove-Item $src -Force
            Write-Host "Removed duplicate: $img"
            $moved++
        }
    } elseif (Test-Path $dst) {
        $existing++
    }
}

Write-Host "Moved: $moved, Already in place: $existing"

# Step 3: Update paths in markdown files
Write-Host "`n=== Updating markdown files ==="
$updated = 0

foreach ($file in $mdFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8
    $original = $content

    # Update Obsidian style
    $content = [regex]::Replace($content, '!\[\[(?!\.\/attachments\/)([^/\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]', '![[./attachments/$1]]')

    # Update markdown style
    $content = [regex]::Replace($content, '!\[([^\]]*)\]\((?!\.\/attachments\/)([^/)]+\.(png|jpg|jpeg|gif|avif|webp))\)', '![$1](./attachments/$2)')

    if ($content -ne $original) {
        Set-Content $file.FullName $content -Encoding UTF8 -NoNewline
        Write-Host "Updated: $($file.Name)"
        $updated++
    }
}

Write-Host "Updated $updated files"

# Step 4: Find unused images
Write-Host "`n=== Finding unused images ==="
$allImages = Get-ChildItem $vaultRoot.Path -File | Where-Object { $_.Extension -match '\.(png|jpg|jpeg|gif|avif|webp)$' }
$unused = $allImages | Where-Object { -not $imageRefs.ContainsKey($_.Name) }

Write-Host "Found $($unused.Count) unused images in vault root"

Write-Host "`n=== Summary ==="
Write-Host "Images referenced: $($imageRefs.Count)"
Write-Host "Images moved: $moved"
Write-Host "Files updated: $updated"
Write-Host "Unused images: $($unused.Count)"
