param([string]$QuartusBin = 'C:\intelFPGA_lite\17.0\quartus\bin64', [string]$Python = 'python', [string]$PinBaseline = 'verification\pin_baseline.json')
$ErrorActionPreference = 'Stop'
Push-Location (Split-Path $PSScriptRoot)
try {
    New-Item -ItemType Directory -Path db/production_build -Force | Out-Null
    & $Python -B scripts/verify_production.py *> db/production_build/input_checks.log
    if ($LASTEXITCODE -ne 0) { throw 'Production input check failed' }
    foreach ($stage in @('map','fit','sta','asm')) {
        $stageArgs = @('TheTemplesCurse','-c','TheTemplesCurse')
        if ($stage -in @('map','fit')) { $stageArgs += '--write_settings_files=off' }
        & (Join-Path $QuartusBin "quartus_$stage.exe") @stageArgs *> "db/production_build/$stage.log"
        if ($LASTEXITCODE -ne 0) { throw "Quartus $stage failed; see db/production_build/$stage.log" }
    }
    & $Python -B scripts/verify_audio_pin_safety.py output_files/TheTemplesCurse.pin --compare $PinBaseline *> db/production_build/pin_safety.log
    if ($LASTEXITCODE -ne 0) { throw 'Final pin audit failed' }
    $summary = Get-Content output_files/TheTemplesCurse.sta.summary -Raw
    $slacks = [regex]::Matches($summary,'Slack\s*:\s*([-+\d.]+)')
    if ($slacks.Count -lt 8) { throw 'Incomplete timing summary' }
    foreach ($s in $slacks) { if ([double]$s.Groups[1].Value -le 0) { throw 'Nonpositive timing slack' } }
    if ((Get-Content output_files/TheTemplesCurse.fit.summary -Raw) -notmatch 'Total virtual pins\s*:\s*9') { throw 'Virtual-pin count changed' }
    $target = [IO.Path]::GetFullPath((Join-Path (Get-Location) '../TheTemplesCurse.sof'))
    if ((Split-Path $target) -ne (Split-Path (Get-Location))) { throw 'Unsafe output path' }
    Move-Item -LiteralPath output_files/TheTemplesCurse.sof -Destination $target -Force
    Get-FileHash -LiteralPath $target
} finally { Pop-Location }
