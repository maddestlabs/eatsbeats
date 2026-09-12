param(
    [Parameter(Position = 0, Mandatory = $false)]
    [string]$Target
)

if ([string]::IsNullOrWhiteSpace($Target)) {
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host " Eatsbeats GUI Patch CLI Helper" -ForegroundColor White
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "Usage:" -ForegroundColor Yellow
    Write-Host "  ./guipatch <issue_number | url | file_path>"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  ./guipatch 2"
    Write-Host "  ./guipatch https://github.com/maddestlabs/eatsbeats/issues/2"
    Write-Host "  ./guipatch issue_body.md"
    Write-Host ""
    exit 1
}

Write-Host "Fetching and applying GUI tweak for: $Target..." -ForegroundColor Cyan

dart run tool/apply_gui_patch.dart $Target

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] GUI patch applied successfully and presets rebundled!" -ForegroundColor Green
    Write-Host "Review changes with: git diff" -ForegroundColor Gray
    Write-Host "Commit with: git commit -am `"feat(gui): apply patch (closes #$Target)`"" -ForegroundColor Gray
} else {
    Write-Host ""
    Write-Host "[FAIL] Failed to apply GUI patch (exit code $LASTEXITCODE)." -ForegroundColor Red
    exit $LASTEXITCODE
}
