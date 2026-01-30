# Cleanup Root Images Script
# Deletes images from root directory that have been copied to attachments folders

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$vaultRoot = Get-Location
$imageExtensions = @('.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp', '.avif')

Write-Host "=========================================="
Write-Host "Cleanup Root Images Script"
Write-Host "Vault root: $($vaultRoot.Path)"
Write-Host "=========================================="
Write-Host ""

# Get all image files in root directory
$rootImages = Get-ChildItem -Path $vaultRoot -File | Where-Object {
    $imageExtensions -contains $_.Extension.ToLower()
}

Write-Host "Found $($rootImages.Count) image files in root directory"
Write-Host ""

if ($rootImages.Count -eq 0) {
    Write-Host "No images to clean up!"
    exit 0
}

# Check if each image exists in any attachments folder
$toDelete = @()
$notFound = @()

foreach ($img in $rootImages) {
    $imgName = $img.Name

    # Search for this image in any attachments folder
    $found = Get-ChildItem -Path $vaultRoot -Recurse -Filter $imgName -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -like "*\attachments\*" -and $_.FullName -ne $img.FullName
    }

    if ($found) {
        $toDelete += $img
        Write-Host "✓ Will delete: $imgName (found in attachments)"
    } else {
        $notFound += $img
        Write-Host "⚠ Keep: $imgName (not found in attachments)"
    }
}

Write-Host ""
Write-Host "=========================================="
Write-Host "Summary:"
Write-Host "  Images to delete: $($toDelete.Count)"
Write-Host "  Images to keep: $($notFound.Count)"
Write-Host "=========================================="
Write-Host ""

if ($notFound.Count -gt 0) {
    Write-Host "Images that will be kept (not found in attachments):"
    foreach ($img in $notFound) {
        Write-Host "  - $($img.Name)"
    }
    Write-Host ""
}

# Ask for confirmation
$response = Read-Host "Do you want to delete $($toDelete.Count) images from root directory? (yes/no)"

if ($response -eq "yes" -or $response -eq "y") {
    Write-Host ""
    Write-Host "Deleting images..."

    $deleted = 0
    $errors = 0

    foreach ($img in $toDelete) {
        try {
            Remove-Item $img.FullName -Force
            Write-Host "Deleted: $($img.Name)"
            $deleted++
        } catch {
            Write-Host "Error deleting $($img.Name): $_" -ForegroundColor Red
            $errors++
        }
    }

    Write-Host ""
    Write-Host "=========================================="
    Write-Host "Cleanup Complete!"
    Write-Host "  Deleted: $deleted"
    Write-Host "  Errors: $errors"
    Write-Host "  Kept: $($notFound.Count)"
    Write-Host "=========================================="
} else {
    Write-Host "Cleanup cancelled."
}
