$files = Get-ChildItem -Path 'C:\Users\xuegao\学习网页\VerificationGuide\docs\guides' -Filter '*.md'
foreach ($f in $files) {
    $c = [System.IO.File]::ReadAllText($f.FullName)
    $c = $c.Replace('```systemverilog', '```verilog')
    [System.IO.File]::WriteAllText($f.FullName, $c)
    Write-Host "Fixed: $($f.Name)"
}
