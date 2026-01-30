# Image Organization Script - Direct Approach
# Run from within the 学习笔记 directory

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$notesDir = Get-Location
$vaultRoot = Split-Path $notesDir -Parent
$attachmentsDir = Join-Path $notesDir "attachments"

Write-Host "=== Image Organization Script ==="
Write-Host "Notes directory: $notesDir"
Write-Host "Vault root: $vaultRoot"

# Create attachments directory
if (-not (Test-Path $attachmentsDir)) {
    New-Item -ItemType Directory -Path $attachmentsDir -Force | Out-Null
    Write-Host "Created attachments directory"
}

# Step 1: Scan for images
Write-Host "`n=== Step 1: Scanning markdown files ==="
$imageRefs = @{}
$mdFiles = Get-ChildItem -Filter "*.md" -File

Write-Host "Found $($mdFiles.Count) markdown files"

foreach ($file in $mdFiles) {
    $content = Get-Content $file.FullName -Raw -Encoding UTF8

    # Obsidian: ![[image.png]]
    $pattern1 = '!\[\[([^\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]'
    foreach ($m in [regex]::Matches($content, $pattern1)) {
        $img = $m.Groups[1].Value
        if ($img -match '[/\\]') { $img = Split-Path $img -Leaf }
        if (-not $imageRefs.ContainsKey($img)) { $imageRefs[$img] = @() }
        $imageRefs[$img] += $file.Name
    }

    # Markdown: ![](image.png)
    $pattern2 = '!\[[^\]]*\]\(([^)]+\.(png|jpg|jpeg|gif|avif|webp))\)'
    foreach ($m in [regex]::Matches($content, $pattern2)) {
        $img = $m.Groups[1].Value
        if ($img -match '[/\\]') { $img = Split-Path $img -Leaf }
        if (-not $imageRefs.ContainsKey($img)) { $imageRefs[$img] = @() }
        $imageRefs[$img] += $file.Name
    }
}

Write-Host "Found $($imageRefs.Count) unique images"
if ($imageRefs.Count -gt 0) {
    Write-Host "Sample images:"
    $imageRefs.Keys | Select-Object -First 10 | ForEach-Object { Write-Host "  - $_" }
}

# Step 2: Move images
Write-Host "`n=== Step 2: Moving images ==="
$moved = 0
$existing = 0

foreach ($img in $imageRefs.Keys) {
    $src = Join-Path $vaultRoot $img
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

# Step 3: Update markdown files
Write-Host "`n=== Step 3: Updating paths in markdown files ==="
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
Write-Host "`n=== Step 4: Finding unused images ==="
$allImages = Get-ChildItem $vaultRoot -File | Where-Object { $_.Extension -match '\.(png|jpg|jpeg|gif|avif|webp)$' }
$unused = $allImages | Where-Object { -not $imageRefs.ContainsKey($_.Name) }

Write-Host "Found $($unused.Count) unused images in vault root"

Write-Host "`n=== SUMMARY ==="
Write-Host "Images referenced: $($imageRefs.Count)"
Write-Host "Images moved: $moved"
Write-Host "Files updated: $updated"
Write-Host "Unused images: $($unused.Count)"
Write-Host "`nNote: Unused images were NOT deleted. Review manually if needed."
