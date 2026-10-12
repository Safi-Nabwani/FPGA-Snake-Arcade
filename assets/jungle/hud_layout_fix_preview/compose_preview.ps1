# PREVIEW ONLY. Compose image-edited boundary artwork with the unchanged arena.
# No source/ROM/config writes, compilation, Git staging, or FPGA programming.
param(
    [string]$DraftPath = (Join-Path $PSScriptRoot 'image_edit_concept.png')
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$previewRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$scenePath = Join-Path $previewRoot 'assets/jungle/hud_implemented/full_scene_640x480.png'
$fontPath = Join-Path $previewRoot 'RTL/mifs/numbers_new_font.mif'
$draft = [System.Drawing.Bitmap]::new($DraftPath)
$original = [System.Drawing.Bitmap]::new($scenePath)
if ($draft.Width -ne 1448 -or $draft.Height -ne 1086) { throw 'Unexpected image-edit draft dimensions' }
if ($original.Width -ne 640 -or $original.Height -ne 480) { throw 'Current scene is not 640x480' }
$scene = [System.Drawing.Bitmap]::new(640,480,[System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
$graphics = [System.Drawing.Graphics]::FromImage($scene)
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$graphics.Clear([System.Drawing.Color]::FromArgb(0,36,0))
function Copy-DraftRegion($sx,$sy,$sw,$sh,$dx,$dy,$dw,$dh) {
    $graphics.DrawImage($draft,[System.Drawing.Rectangle]::new($dx,$dy,$dw,$dh),
        [System.Drawing.Rectangle]::new($sx,$sy,$sw,$sh),[System.Drawing.GraphicsUnit]::Pixel)
}
# Fit distinct edited UI/frame regions, not the complete game screen.
Copy-DraftRegion 0 0 316 1086 8 8 128 464
Copy-DraftRegion 340 0 1067 54 144 0 480 24
Copy-DraftRegion 340 1034 1067 52 144 456 480 24
Copy-DraftRegion 316 54 24 980 136 24 8 432
Copy-DraftRegion 1407 54 41 980 624 24 16 432
Copy-DraftRegion 316 0 24 54 136 0 8 24
Copy-DraftRegion 316 1034 24 52 136 456 8 24
Copy-DraftRegion 1407 0 41 54 624 0 16 24
Copy-DraftRegion 1407 1034 41 52 624 456 16 24
Copy-DraftRegion 1413 54 18 980 0 0 8 480
Copy-DraftRegion 350 12 280 18 8 0 128 8
Copy-DraftRegion 350 1050 280 18 8 472 128 8
$graphics.Dispose()
# Preview RGB332 quantization is limited to proposed boundary artwork.
# Active MIFs and the existing arena's pixels are NEVER quantized or rewritten.
$levels = @(0,36,72,109,145,182,218,255)
$blueLevels = @(0,85,170,255)
for ($y=0; $y -lt 480; $y++) {
    for ($x=0; $x -lt 640; $x++) {
        if ($x -ge 144 -and $x -lt 624 -and $y -ge 24 -and $y -lt 456) { continue }
        $p=$scene.GetPixel($x,$y)
        $r=$levels[[int][Math]::Round($p.R*7.0/255)]
        $g=$levels[[int][Math]::Round($p.G*7.0/255)]
        $b=$blueLevels[[int][Math]::Round($p.B*3.0/255)]
        $scene.SetPixel($x,$y,[System.Drawing.Color]::FromArgb($r,$g,$b))
    }
}
# Overlay the original arena, unscaled and unaltered, instead of generated gameplay.
$graphics = [System.Drawing.Graphics]::FromImage($scene)
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$graphics.DrawImage($original,[System.Drawing.Rectangle]::new(144,24,480,432),
    [System.Drawing.Rectangle]::new(144,24,480,432),[System.Drawing.GraphicsUnit]::Pixel)
# Clear ONLY preview placeholder numerals inside the proposed counter wells.
# These small inset regions stay clear of frames, labels and gemstone illustrations.
$fields = @(
    @{Name='Score'; Value='12'; X=57; Y=116; Color=0xF9; Clear=@(38,112,70,26); Well=@(35,108,76,32)},
    @{Name='High Score'; Value='19'; X=56; Y=182; Color=0xF9; Clear=@(37,178,70,26); Well=@(33,175,78,32)},
    @{Name='Ruby'; Value='012'; X=64; Y=273; Color=0xED; Clear=@(62,271,52,21); Well=@(59,268,59,27)},
    @{Name='Sapphire'; Value='345'; X=64; Y=317; Color=0x57; Clear=@(62,315,52,22); Well=@(59,313,59,27)},
    @{Name='Cursed'; Value='678'; X=64; Y=362; Color=0xB3; Clear=@(62,360,52,22); Well=@(59,358,59,27)}
)
foreach($field in $fields) {
    $c=$field.Clear
    $graphics.FillRectangle([System.Drawing.Brushes]::Black,$c[0],$c[1],$c[2],$c[3])
}
$graphics.Dispose()
$scene.Save((Join-Path $PSScriptRoot 'empty_counter_windows_640x480.png'),[System.Drawing.Imaging.ImageFormat]::Png)
# Use full-detail occupied rows6..23 of the existing16x32 font; no new glyph art.
$font = [int[]]::new(8192)
$fontText = [System.IO.File]::ReadAllText($fontPath)
$matches = [regex]::Matches($fontText,'(?m)^([0-9A-F]+)\s*:\s*([01]);')
if ($matches.Count -ne 8192) { throw 'Expected complete original font addresses' }
foreach($m in $matches) { $font[[Convert]::ToInt32($m.Groups[1].Value,16)] = [int]::Parse($m.Groups[2].Value) }
function RGB332([int]$code) {
    return [System.Drawing.Color]::FromArgb($levels[($code -shr 5) -band 7],
        $levels[($code -shr 2) -band 7],$blueLevels[$code -band 3])
}
foreach($field in $fields) {
    for($i=0;$i -lt $field.Value.Length;$i++) {
        $digit=[int]::Parse([string]$field.Value[$i])
        for($dy=0;$dy -lt 18;$dy++) {
            for($dx=0;$dx -lt 16;$dx++) {
                if($font[$digit*512+($dy+6)*16+$dx]) {
                    $scene.SetPixel($field.X+$i*16+$dx,$field.Y+$dy,(RGB332 $field.Color))
                }
            }
        }
    }
}
# Assert every gameplay-area RGB pixel remains exactly equal to the current scene.
$arenaBytes=[byte[]]::new(480*432*3)
$offset=0
for($y=24;$y -lt 456;$y++) {
    for($x=144;$x -lt 624;$x++) {
        $a=$scene.GetPixel($x,$y); $b=$original.GetPixel($x,$y)
        if($a.ToArgb() -ne $b.ToArgb()) { throw "Arena pixel changed: ($x,$y)" }
        $arenaBytes[$offset++]=$a.R; $arenaBytes[$offset++]=$a.G; $arenaBytes[$offset++]=$a.B
    }
}
$arenaHash=[Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($arenaBytes))
$scene.Save((Join-Path $PSScriptRoot 'full_scene_640x480.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$zoom=[System.Drawing.Bitmap]::new(1280,960)
$zoomGraphics=[System.Drawing.Graphics]::FromImage($zoom)
$zoomGraphics.InterpolationMode=[System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$zoomGraphics.PixelOffsetMode=[System.Drawing.Drawing2D.PixelOffsetMode]::Half
$zoomGraphics.DrawImage($scene,[System.Drawing.Rectangle]::new(0,0,1280,960),0,0,640,480,[System.Drawing.GraphicsUnit]::Pixel)
$zoomGraphics.Dispose()
$zoom.Save((Join-Path $PSScriptRoot 'full_scene_2x.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$zoom.Dispose()
$fieldSummary=@($fields | ForEach-Object {
    @{name=$_.Name;example=$_.Value;number_origin=@($_.X,$_.Y);digit_cell=@(16,18);window=$_.Well}
})
$validation=[ordered]@{
    preview_only=$true; approval_pending=$true; size=@(640,480)
    source_scene='assets/jungle/hud_implemented/full_scene_640x480.png'
    source_scene_sha256=(Get-FileHash -LiteralPath $scenePath).Hash
    source_font_sha256=(Get-FileHash -LiteralPath $fontPath).Hash
    arena_bounds=@(144,24,624,456); arena_pixels_verified=207360; arena_rgb_sha256=$arenaHash
    arena_pixel_identical=$true; hud_bounds=@(8,8,136,472); fields=$fieldSummary
    top_filler=@(144,0,624,24); bottom_filler=@(144,456,624,480)
    divider_filler=@(136,24,144,456); right_filler=@(624,24,640,456)
    boundary_colors='RGB332'; active_mif_changes=$false; rtl_changes=$false; quartus_run=$false
    fpga_programmed=$false
}
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot 'verification.json'),
    ($validation | ConvertTo-Json -Depth 8)+[Environment]::NewLine)
$original.Dispose(); $draft.Dispose(); $scene.Dispose()
'PREVIEW_PASS: 640x480; full-height HUD; five 16x18 font fields; 207360 unchanged arena pixels; no active project writes'
