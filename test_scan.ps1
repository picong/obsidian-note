$notesDir = "C:\Users\cong.pi\Documents\obsidian-note\学习笔记"
$mdFiles = [System.IO.Directory]::GetFiles($notesDir, "*.md")
Write-Host "Found $($mdFiles.Count) markdown files"

$testFile = $mdFiles[0]
Write-Host "`nTesting file: $testFile"
$content = [System.IO.File]::ReadAllText($testFile, [System.Text.Encoding]::UTF8)
Write-Host "Content length: $($content.Length)"

# Test regex
$pattern = '!\[[^\]]*\]\(([^)]+\.(png|jpg|jpeg|gif|avif|webp))\)'
$matches = [regex]::Matches($content, $pattern)
Write-Host "Found $($matches.Count) markdown-style image references"

$obsidianPattern = '!\[\[([^\]]+\.(png|jpg|jpeg|gif|avif|webp))\]\]'
$obsidianMatches = [regex]::Matches($content, $obsidianPattern)
Write-Host "Found $($obsidianMatches.Count) Obsidian-style image references"

if ($matches.Count -gt 0) {
    Write-Host "`nFirst match: $($matches[0].Value)"
    Write-Host "Image name: $($matches[0].Groups[1].Value)"
}

if ($obsidianMatches.Count -gt 0) {
    Write-Host "`nFirst Obsidian match: $($obsidianMatches[0].Value)"
    Write-Host "Image name: $($obsidianMatches[0].Groups[1].Value)"
}
