# Generates image.png — the architecture diagram for PodeRemoteRunner.
# Run from anywhere: .\scripts\generate-image.ps1

Add-Type -AssemblyName System.Drawing

$W = 1200
$H = 820

$bmp = New-Object System.Drawing.Bitmap($W, $H)
$g   = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

function color([string]$h)  { [System.Drawing.ColorTranslator]::FromHtml($h) }
function brush([System.Drawing.Color]$c) { New-Object System.Drawing.SolidBrush($c) }
function pen([System.Drawing.Color]$c, [float]$w = 1.5) { New-Object System.Drawing.Pen($c, $w) }
function apen([System.Drawing.Color]$c, [float]$w = 1.5) {
    $p = New-Object System.Drawing.Pen($c, $w)
    $p.CustomEndCap = New-Object System.Drawing.Drawing2D.AdjustableArrowCap(4, 4, $true)
    $p
}
function font([string]$family, [float]$size, [bool]$bold = $false) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    New-Object System.Drawing.Font($family, $size, $style)
}
function sf([string]$h = 'Center', [string]$v = 'Center') {
    $s = New-Object System.Drawing.StringFormat
    $s.Alignment     = [System.Drawing.StringAlignment]::$h
    $s.LineAlignment = [System.Drawing.StringAlignment]::$v
    $s
}
function rr($x, $y, $w, $h, $r, $pn, $br) {
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path.AddArc([int]$x,           [int]$y,           2*$r, 2*$r, 180, 90)
    $path.AddArc([int]($x+$w-2*$r), [int]$y,           2*$r, 2*$r, 270, 90)
    $path.AddArc([int]($x+$w-2*$r), [int]($y+$h-2*$r), 2*$r, 2*$r,   0, 90)
    $path.AddArc([int]$x,           [int]($y+$h-2*$r), 2*$r, 2*$r,  90, 90)
    $path.CloseAllFigures()
    if ($null -ne $br) { $g.FillPath($br, $path) }
    if ($null -ne $pn) { $g.DrawPath($pn, $path) }
    $path.Dispose()
}
function tx($s, $f, $b, $x, $y, $w, $h, $fmt) {
    $g.DrawString($s, $f, $b, [System.Drawing.RectangleF]::new([float]$x, [float]$y, [float]$w, [float]$h), $fmt)
}

# --- Palette (GitHub dark) ---
$cBg     = color '#0D1117'
$cPanel  = color '#161B22'
$cSub    = color '#0D1117'
$cBorder = color '#30363D'
$cBlue   = color '#58A6FF'
$cGreen  = color '#3FB950'
$cPurple = color '#A371F7'
$cGray   = color '#6E7681'
$cText   = color '#C9D1D9'
$cMuted  = color '#8B949E'
$cGet    = color '#79C0FF'
$cPost   = color '#D2A8FF'

# Brushes
$bBg     = brush $cBg
$bPanel  = brush $cPanel
$bSub    = brush $cSub
$bBlue   = brush $cBlue
$bGreen  = brush $cGreen
$bPurple = brush $cPurple
$bText   = brush $cText
$bMuted  = brush $cMuted
$bGet    = brush $cGet
$bPost   = brush $cPost

# Pens (border)
$pBlue   = pen $cBlue
$pGreen  = pen $cGreen
$pPurple = pen $cPurple
$pBorder = pen $cBorder 1.0
$pGray   = pen $cGray 1.2

# Arrow pens
$aBlue   = apen $cBlue
$aGreen  = apen $cGreen
$aPurple = apen $cPurple

# Fonts
$fTitle = font 'Segoe UI' 19 $true
$fH2    = font 'Segoe UI' 11 $true
$fH3    = font 'Segoe UI'  9 $true
$fBody  = font 'Segoe UI'  8.5
$fMono  = font 'Consolas'  8
$fSmall = font 'Segoe UI'  8
$fFoot  = font 'Segoe UI'  7.5

# StringFormats
$sfC = sf 'Center' 'Center'
$sfL = sf 'Near'   'Center'

# =====================================================================
# BACKGROUND
# =====================================================================
$g.FillRectangle($bBg, 0, 0, $W, $H)

# =====================================================================
# TITLE
# =====================================================================
tx "PodeRemoteRunner — Architecture" $fTitle $bBlue 0 14 $W 34 $sfC

# =====================================================================
# CLIENT BOX  (center x=600)
# =====================================================================
rr 440 60 320 56 8 $pBlue $bPanel
tx "Client"                          $fH2  $bBlue  440 60  320 28 $sfC
tx "Browser  ·  curl  ·  PowerShell" $fBody $bMuted 440 84  320 24 $sfC

# Arrow: Client → Pode
$g.DrawLine($aBlue, 600, 116, 600, 168)

# =====================================================================
# PODE HTTP SERVER BOX  x=60, y=168, w=1080, h=160  (bottom=328)
# =====================================================================
rr 60 168 1080 160 8 $pBlue $bPanel
tx "Pode HTTP Server  :8080" $fH2 $bBlue 60 170 1080 26 $sfC

# Middleware sub-box: x=78, y=200, w=270, h=114
rr 78 200 270 114 6 $pBorder $bSub
tx "Middleware"                         $fH3    $bText  78 200  270 22 $sfC
tx "• Rate Limiter (60 req / 60 s)"     $fSmall $bMuted  92 223  250 17 $sfL
tx "• Request Logger + TraceId"         $fSmall $bMuted  92 241  250 17 $sfL
tx "• OWASP Security Headers"           $fSmall $bMuted  92 259  250 17 $sfL
tx "• X-Request-Id response header"     $fSmall $bMuted  92 277  250 17 $sfL

# Routes sub-box: x=360, y=200, w=768, h=114
rr 360 200 768 114 6 $pBorder $bSub
tx "Routes" $fH3 $bText 360 200 768 22 $sfC

# Vertical divider between the two route columns at x=744
$g.DrawLine($pBorder, 744, 206, 744, 308)

# Left route column  (GET /, GET /winrm, POST /winrm/run)
$ry = 227; $rh = 18
tx "GET"  $fMono $bGet  375 $ry 36 $rh $sfL; tx "/"           $fMono $bMuted  416 $ry 320 $rh $sfL; $ry += $rh + 1
tx "GET"  $fMono $bGet  375 $ry 36 $rh $sfL; tx "/winrm"      $fMono $bBlue   416 $ry 320 $rh $sfL; $ry += $rh + 1
tx "POST" $fMono $bPost 375 $ry 42 $rh $sfL; tx "/winrm/run"  $fMono $bBlue   416 $ry 320 $rh $sfL

# Right route column  (GET /health, GET /ssh, POST /ssh/run)
$ry = 227
tx "GET"  $fMono $bGet  762 $ry 36 $rh $sfL; tx "/health"     $fMono $bMuted  803 $ry 320 $rh $sfL; $ry += $rh + 1
tx "GET"  $fMono $bGet  762 $ry 36 $rh $sfL; tx "/ssh"        $fMono $bPurple 803 $ry 320 $rh $sfL; $ry += $rh + 1
tx "POST" $fMono $bPost 762 $ry 42 $rh $sfL; tx "/ssh/run"    $fMono $bPurple 803 $ry 320 $rh $sfL

# =====================================================================
# T-JUNCTION BRANCH  from Pode bottom y=328
# =====================================================================
#   vertical stub: 600,328 → 600,352
#   horizontal bar: 280,352 → 920,352
#   drop left (green arrow): 280,352 → 280,380
#   drop right (purple arrow): 920,352 → 920,380
$g.DrawLine($pGray,   600, 328, 600, 352)
$g.DrawLine($pGray,   280, 352, 920, 352)
$g.DrawLine($aGreen,  280, 352, 280, 380)
$g.DrawLine($aPurple, 920, 352, 920, 380)

# =====================================================================
# WINRM COLUMN  (center x=280)
# =====================================================================
rr 130 380 300 70 8 $pGreen $bPanel
tx "Parallel PS Jobs"           $fH2  $bGreen 130 380 300 30 $sfC
tx "WinRM / HTTPS / Port 5986"  $fBody $bMuted 130 408 300 28 $sfC

$g.DrawLine($aGreen, 280, 450, 280, 490)

rr 130 490 300 70 8 $pGreen $bPanel
tx "Windows Servers"              $fH2  $bGreen 130 490 300 30 $sfC
tx "WinRM HTTPS (self-signed OK)" $fBody $bMuted 130 518 300 28 $sfC

$g.DrawLine($aGreen, 280, 560, 280, 598)

rr 130 598 300 56 8 $pGreen $bPanel
tx "logs/winrm/" $fH2 $bGreen 130 598 300 56 $sfC

# =====================================================================
# SSH COLUMN  (center x=920)
# =====================================================================
rr 770 380 300 70 8 $pPurple $bPanel
tx "Parallel PS Jobs"          $fH2  $bPurple 770 380 300 30 $sfC
tx "SSH / Port 22 / Key Auth"  $fBody $bMuted  770 408 300 28 $sfC

$g.DrawLine($aPurple, 920, 450, 920, 490)

rr 770 490 300 70 8 $pPurple $bPanel
tx "Linux / Unix Servers"          $fH2  $bPurple 770 490 300 30 $sfC
tx "SSH key auth (no passwords)"   $fBody $bMuted  770 518 300 28 $sfC

$g.DrawLine($aPurple, 920, 560, 920, 598)

rr 770 598 300 56 8 $pPurple $bPanel
tx "logs/ssh/" $fH2 $bPurple 770 598 300 56 $sfC

# =====================================================================
# FEATURE STRIP  y=676, h=78
# =====================================================================
rr 60 676 1080 78 6 $pBorder $bPanel

$cols  = @(90, 360, 630, 900)
$rows  = @(
    @("No passwords stored",           "SSH key auth only",          "Per-execution log files",   "Parallel execution"),
    @("Rate limiting (Pode built-in)",  "OWASP security headers",     "TraceId correlation",        "Async stdout/stderr"),
    @("Input validation",               "Auto retry (WinRM)",         "Daily log rotation",         "30s SSH timeout")
)
$fy0 = 686
for ($row = 0; $row -lt 3; $row++) {
    for ($col = 0; $col -lt 4; $col++) {
        tx $rows[$row][$col] $fSmall $bMuted $cols[$col] ($fy0 + $row * 17) 260 17 $sfL
    }
}

# =====================================================================
# FOOTER
# =====================================================================
tx "MIT License  ·  github.com/D4ri0Rookie/PodeRemoteRunner  ·  PowerShell + Pode Framework" $fFoot $bMuted 0 768 $W 22 $sfC

# =====================================================================
# SAVE
# =====================================================================
$outPath = Join-Path (Split-Path $PSScriptRoot -Parent) "image.png"
$bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()

Write-Host "Saved: $outPath" -ForegroundColor Green
