# Image Organization Script - Comprehensive Version
# Organizes images by moving them to attachments/ subdirectories next to referencing markdown files

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Configuration
$vaultRoot = Get-Location
$excludeDirs = @('.obsidian', '.git', '.claude', 'node_modules')
$imageExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.avif')
$logFile = Join-Path $vaultRoot "image_organization_log.txt"
$unusedFile = Join-Path $vaultRoot "unused_images.txt"
$refsFile = Join-Path $vaultRoot "image_references.json"

# Initialize log
$logMessages = @()
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$timestamp] [$Level] $Message"
    $logMessages += $logMsg
    Write-Host $logMsg
}

function Test-LocalImage {
    param([string]$Path)
    $pathLower = $Path.ToLower()
    if ($pathLower.StartsWith("http://") -or $pathLower.StartsWith("https://")) {
        return $false
    }
    if ($pathLower.Contains("typora") -or $pathLower.Contains("appdata")) {
        return $false
    }
    return $true
}

function Get-ImageFilename {
    param([string]$Path)
    $Path = $Path.Replace('\', '/')
    $Path = $Path.TrimStart('./')
    return Split-Path $Path -Leaf
}

# Phase 1: Scan markdown files
Write-Log "=========================================="
Write-Log "Image Organization Script"
Write-Log "Vault root: $($vaultRoot.Path)"
Write-Log "=========================================="
Write-Log ""
Write-Log "=== Phase 1: Scanning markdown files ==="

$imageRefs = @{}  # image_name -> @{Files = @(); Types = @()}
$mdFilesProcessed = 0

Get-ChildItem -Path $vaultRoot -Recurse -Filter "*.md" | ForEach-Object {
    $mdFile = $_

    # Skip excluded directories
    $skip = $false
    foreach ($excludeDir in $excludeDirs) {
        if ($mdFile.FullName -like "*\$excludeDir\*") {
            $skip = $true
            break
        }
    }
    if ($skip) { return }

    $mdFilesProcessed++

    try {
        $content = Get-Content $mdFile.FullName -Raw -Encoding UTF8

        # Find Obsidian-style references: ![[image.png]]
        $obsidianMatches = [regex]::Matches($content, '!\[\[([^\]]+\.(?:png|jpg|jpeg|gif|svg|webp|avif))\]\]', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($match in $obsidianMatches) {
            $imgPath = $match.Groups[1].Value
            if (Test-LocalImage $imgPath) {
                $imgName = Get-ImageFilename $imgPath
                if (-not $imageRefs.ContainsKey($imgName)) {
                    $imageRefs[$imgName] = @{Files = @(); Types = @()}
                }
                $imageRefs[$imgName].Files += $mdFile
                $imageRefs[$imgName].Types += 'obsidian'
            }
        }

        # Find Markdown-style references: ![](image.png)
        $markdownMatches = [regex]::Matches($content, '!\[[^\]]*\]\(([^)]+\.(?:png|jpg|jpeg|gif|svg|webp|avif))\)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($match in $markdownMatches) {
            $imgPath = $match.Groups[1].Value
            if (Test-LocalImage $imgPath) {
                $imgName = Get-ImageFilename $imgPath
                if (-not $imageRefs.ContainsKey($imgName)) {
                    $imageRefs[$imgName] = @{Files = @(); Types = @()}
                }
                $imageRefs[$imgName].Files += $mdFile
                $imageRefs[$imgName].Types += 'markdown'
            }
        }
    }
    catch {
        Write-Log "Error reading $($mdFile.FullName): $_" "ERROR"
    }
}

Write-Log "Processed $mdFilesProcessed markdown files"
Write-Log "Found $($imageRefs.Count) unique images referenced"

# Save references map
$refsData = @{}
foreach ($imgName in $imageRefs.Keys) {
    $refsData[$imgName] = @()
    for ($i = 0; $i -lt $imageRefs[$imgName].Files.Count; $i++) {
        $relPath = $imageRefs[$imgName].Files[$i].FullName.Replace($vaultRoot.Path + '\', '')
        $refsData[$imgName] += @{
            file = $relPath
            type = $imageRefs[$imgName].Types[$i]
        }
    }
}
$refsData | ConvertTo-Json -Depth 10 | Set-Content $refsFile -Encoding UTF8
Write-Log "References map saved to: $refsFile"

# Phase 2: Copy images
Write-Log ""
Write-Log "=== Phase 2: Copying images to attachments folders ==="

$stats = @{
    copied = 0
    skipped_exists = 0
    skipped_not_found = 0
    errors = 0
}

foreach ($imgName in $imageRefs.Keys) {
    # Find the source image file
    $srcFile = $null

    # First check root directory
    $rootPath = Join-Path $vaultRoot $imgName
    if (Test-Path $rootPath -PathType Leaf) {
        $srcFile = Get-Item $rootPath
    }
    else {
        # Search in subdirectories
        $found = Get-ChildItem -Path $vaultRoot -Recurse -Filter $imgName -File -ErrorAction SilentlyContinue | Where-Object {
            $skip = $false
            foreach ($excludeDir in $excludeDirs) {
                if ($_.FullName -like "*\$excludeDir\*") {
                    $skip = $true
                    break
                }
            }
            -not $skip
        } | Select-Object -First 1

        if ($found) {
            $srcFile = $found
        }
    }

    if (-not $srcFile) {
        Write-Log "Image not found: $imgName" "WARNING"
        $stats.skipped_not_found++
        continue
    }

    # Group references by directory
    $refDirs = @{}
    foreach ($mdFile in $imageRefs[$imgName].Files) {
        $refDirs[$mdFile.DirectoryName] = $true
    }

    # Copy to each directory's attachments folder
    foreach ($refDir in $refDirs.Keys) {
        $attachmentsDir = Join-Path $refDir "attachments"
        if (-not (Test-Path $attachmentsDir)) {
            New-Item -ItemType Directory -Path $attachmentsDir -Force | Out-Null
        }

        $dstFile = Join-Path $attachmentsDir $imgName

        # Check if already in the right place
        if ($srcFile.FullName -eq $dstFile) {
            $dirName = Split-Path $refDir -Leaf
            Write-Log "Already in place: $imgName in $dirName/attachments/"
            $stats.skipped_exists++
            continue
        }

        # Check if destination already exists
        if (Test-Path $dstFile) {
            # Compare file sizes
            $dstItem = Get-Item $dstFile
            if ($srcFile.Length -eq $dstItem.Length) {
                $dirName = Split-Path $refDir -Leaf
                Write-Log "Skipped (already exists): $imgName -> $dirName/attachments/"
                $stats.skipped_exists++
                continue
            }
            else {
                # Handle name conflict
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($imgName)
                $ext = [System.IO.Path]::GetExtension($imgName)
                $counter = 1
                while (Test-Path $dstFile) {
                    $dstFile = Join-Path $attachmentsDir "${baseName}_${counter}${ext}"
                    $counter++
                }
                Write-Log "Name conflict resolved: $imgName -> $(Split-Path $dstFile -Leaf)"
            }
        }

        try {
            Copy-Item $srcFile.FullName $dstFile -Force
            $dirName = Split-Path $refDir -Leaf
            Write-Log "Copied: $imgName -> $dirName/attachments/"
            $stats.copied++
        }
        catch {
            Write-Log "Error copying $imgName : $_" "ERROR"
            $stats.errors++
        }
    }
}

Write-Log ""
Write-Log "Copy statistics:"
Write-Log "  Copied: $($stats.copied)"
Write-Log "  Skipped (exists): $($stats.skipped_exists)"
Write-Log "  Skipped (not found): $($stats.skipped_not_found)"
Write-Log "  Errors: $($stats.errors)"

# Phase 3: Update markdown references
Write-Log ""
Write-Log "=== Phase 3: Updating markdown file references ==="

$filesUpdated = 0
$refsUpdated = 0

# Group by markdown file
$mdFiles = @{}
foreach ($imgName in $imageRefs.Keys) {
    for ($i = 0; $i -lt $imageRefs[$imgName].Files.Count; $i++) {
        $mdFile = $imageRefs[$imgName].Files[$i]
        $refType = $imageRefs[$imgName].Types[$i]

        if (-not $mdFiles.ContainsKey($mdFile.FullName)) {
            $mdFiles[$mdFile.FullName] = @()
        }
        $mdFiles[$mdFile.FullName] += @{Image = $imgName; Type = $refType}
    }
}

foreach ($mdFilePath in $mdFiles.Keys) {
    try {
        $content = Get-Content $mdFilePath -Raw -Encoding UTF8
        $originalContent = $content

        foreach ($ref in $mdFiles[$mdFilePath]) {
            $imgName = $ref.Image
            $refType = $ref.Type

            if ($refType -eq 'obsidian') {
                # Update Obsidian format: ![[image.png]] -> ![[attachments/image.png]]
                $escapedName = [regex]::Escape($imgName)
                $pattern = "!\[\[(?!attachments/)(?:[^/\]]*/)?" + $escapedName + "\]\]"
                $replacement = "![[attachments/$imgName]]"
                $content = [regex]::Replace($content, $pattern, $replacement, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            }
            elseif ($refType -eq 'markdown') {
                # Update Markdown format: ![](image.png) -> ![](attachments/image.png)
                $escapedName = [regex]::Escape($imgName)
                $pattern = "!\[([^\]]*)\]\((?!attachments/)(?:\./)?(?:[^/)]*/)?" + $escapedName + "\)"
                $replacement = "![`$1](attachments/$imgName)"
                $content = [regex]::Replace($content, $pattern, $replacement, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
            }
        }

        if ($content -ne $originalContent) {
            Set-Content $mdFilePath $content -Encoding UTF8 -NoNewline
            $relPath = $mdFilePath.Replace($vaultRoot.Path + '\', '')
            Write-Log "Updated: $relPath"
            $filesUpdated++
            $refsUpdated += $mdFiles[$mdFilePath].Count
        }
    }
    catch {
        Write-Log "Error updating $mdFilePath : $_" "ERROR"
    }
}

Write-Log ""
Write-Log "Update statistics:"
Write-Log "  Files updated: $filesUpdated"
Write-Log "  References updated: $refsUpdated"

# Phase 4: Find unused images
Write-Log ""
Write-Log "=== Phase 4: Finding unused images ==="

$referencedImages = $imageRefs.Keys
$unusedImages = @()

Get-ChildItem -Path $vaultRoot -File | Where-Object {
    $imageExtensions -contains $_.Extension.ToLower()
} | ForEach-Object {
    if ($referencedImages -notcontains $_.Name) {
        $unusedImages += $_
    }
}

Write-Log "Found $($unusedImages.Count) unused images in root directory"

if ($unusedImages.Count -gt 0) {
    $unusedContent = @(
        "# Unused Images in Root Directory"
        "# Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
        "# Total: $($unusedImages.Count) files"
        ""
    )
    $unusedContent += $unusedImages | Sort-Object Name | ForEach-Object { $_.Name }
    $unusedContent | Set-Content $unusedFile -Encoding UTF8
    Write-Log "Unused images list saved to: $unusedFile"
}

# Summary
Write-Log ""
Write-Log "=========================================="
Write-Log "SUMMARY"
Write-Log "=========================================="
Write-Log "Referenced images: $($imageRefs.Count)"
Write-Log "Images copied: $($stats.copied)"
Write-Log "Markdown files updated: $filesUpdated"
Write-Log "Unused images found: $($unusedImages.Count)"
Write-Log "=========================================="

# Save log
$logMessages | Set-Content $logFile -Encoding UTF8
Write-Log ""
Write-Log "Log saved to: $logFile"

if ($unusedImages.Count -gt 0) {
    Write-Log ""
    Write-Log "Next steps:"
    Write-Log "1. Review unused images in: $unusedFile"
    Write-Log "2. Verify images display correctly in Obsidian"
    Write-Log "3. If everything looks good, delete unused images"
    Write-Log "4. Commit changes with git"
}
