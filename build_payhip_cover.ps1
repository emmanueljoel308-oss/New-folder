$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = $PSScriptRoot
$output = Join-Path $root "dist\Wi-Fi-Guard-Payhip-Cover.png"
$width = 1200
$height = 630

New-Item -ItemType Directory -Path (Split-Path $output) -Force | Out-Null
$bitmap = [System.Drawing.Bitmap]::new($width, $height)
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

function New-RoundedPath([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = $radius * 2
    [void]$path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    [void]$path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    [void]$path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    [void]$path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-RoundedBox($graphics, [float]$x, [float]$y, [float]$width, [float]$height, [float]$radius, $brush) {
    $path = New-RoundedPath $x $y $width $height $radius
    $graphics.FillPath($brush, $path)
    $path.Dispose()
}

function Draw-Text($graphics, [string]$text, [float]$x, [float]$y, [float]$size, [string]$fontStyle, $brush) {
    $font = [System.Drawing.Font]::new("Segoe UI", $size, [System.Drawing.FontStyle]::$fontStyle, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.DrawString($text, $font, $brush, $x, $y)
    $font.Dispose()
}

try {
    $background = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.Point]::new(0, 0),
        [System.Drawing.Point]::new($width, $height),
        [System.Drawing.Color]::FromArgb(12, 21, 39),
        [System.Drawing.Color]::FromArgb(21, 42, 69)
    )
    $graphics.FillRectangle($background, 0, 0, $width, $height)

    $softGlow = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(25, 40, 187, 195))
    $graphics.FillEllipse($softGlow, 770, 16, 500, 500)
    $graphics.FillEllipse($softGlow, 870, 430, 240, 240)

    $gridPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(18, 184, 210, 211), 1)
    foreach ($x in 720..1200 | Where-Object { $_ % 64 -eq 16 }) {
        $graphics.DrawLine($gridPen, $x, 0, $x, $height)
    }
    foreach ($y in 24..630 | Where-Object { $_ % 64 -eq 24 }) {
        $graphics.DrawLine($gridPen, 680, $y, $width, $y)
    }

    $cyan = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(90, 226, 225))
    $white = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(247, 250, 252))
    $muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(181, 199, 215))
    $dim = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(110, 139, 158))

    $logoPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $logoPoints = [System.Drawing.Point[]]@(
        [System.Drawing.Point]::new(76, 63),
        [System.Drawing.Point]::new(104, 73),
        [System.Drawing.Point]::new(101, 94),
        [System.Drawing.Point]::new(90, 105),
        [System.Drawing.Point]::new(79, 94),
        [System.Drawing.Point]::new(76, 73)
    )
    $logoPath.AddPolygon($logoPoints)
    $logoBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.Point]::new(76, 63),
        [System.Drawing.Point]::new(104, 105),
        [System.Drawing.Color]::FromArgb(47, 199, 207),
        [System.Drawing.Color]::FromArgb(45, 141, 196)
    )
    $graphics.FillPath($logoBrush, $logoPath)
    $logoPath.Dispose()

    $logoLine = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 235, 252, 255), 2.5)
    $logoLine.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $logoLine.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawArc($logoLine, 81, 76, 18, 12, 218, 104)
    $graphics.DrawArc($logoLine, 85, 81, 10, 7, 218, 104)
    $graphics.FillEllipse([System.Drawing.Brushes]::White, 89, 89, 3, 3)

    Draw-Text $graphics "WI-FI" 128 65 24 "Bold" $white
    Draw-Text $graphics "GUARD" 214 65 24 "Regular" $muted

    $pillBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(32, 90, 226, 225))
    Draw-RoundedBox $graphics 78 174 188 38 19 $pillBrush
    Draw-Text $graphics "YOUR NETWORK. YOUR RULES." 94 183 12 "Bold" $cyan

    Draw-Text $graphics "Choose which" 76 231 49 "Bold" $white
    Draw-Text $graphics "Wi-Fi networks" 76 286 49 "Bold" $white
    Draw-Text $graphics "your PC can join." 76 341 49 "Bold" $white
    Draw-Text $graphics "Block a network by name. Allow it again whenever you choose." 80 424 17 "Regular" $muted

    $chipBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(27, 43, 62))
    $chipOutline = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(66, 94, 119), 1)
    foreach ($chip in @(@{ X = 80; W = 88; Text = "WINDOWS 7" }, @{ X = 181; W = 88; Text = "WINDOWS 8" }, @{ X = 282; W = 96; Text = "WINDOWS 10" }, @{ X = 391; W = 93; Text = "WINDOWS 11" })) {
        $chipPath = New-RoundedPath $chip.X 508 $chip.W 30 15
        $graphics.FillPath($chipBrush, $chipPath)
        $graphics.DrawPath($chipOutline, $chipPath)
        $chipPath.Dispose()
        Draw-Text $graphics $chip.Text ($chip.X + 11) 516 9 "Bold" $muted
    }

    $badgeBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(35, 90, 226, 225))
    Draw-RoundedBox $graphics 80 556 109 29 14 $badgeBrush
    Draw-Text $graphics "32-BIT" 106 562 12 "Bold" $cyan
    Draw-RoundedBox $graphics 199 556 109 29 14 $badgeBrush
    Draw-Text $graphics "64-BIT" 225 562 12 "Bold" $cyan
    Draw-Text $graphics "Standalone app  ·  Admin permission required" 326 561 13 "Regular" $dim

    $iconHalo = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(24, 106, 228, 220))
    $graphics.FillEllipse($iconHalo, 763, 114, 362, 362)
    $haloOutline = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(35, 127, 215, 214), 1)
    $graphics.DrawEllipse($haloOutline, 785, 136, 318, 318)
    $graphics.DrawEllipse($haloOutline, 812, 163, 264, 264)

    $shieldPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $shieldPoints = [System.Drawing.Point[]]@(
        [System.Drawing.Point]::new(944, 169),
        [System.Drawing.Point]::new(1038, 202),
        [System.Drawing.Point]::new(1035, 285),
        [System.Drawing.Point]::new(1014, 344),
        [System.Drawing.Point]::new(944, 395),
        [System.Drawing.Point]::new(874, 344),
        [System.Drawing.Point]::new(853, 285),
        [System.Drawing.Point]::new(850, 202)
    )
    $shieldPath.AddPolygon($shieldPoints)
    $shieldFill = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
        [System.Drawing.Point]::new(866, 180),
        [System.Drawing.Point]::new(1022, 374),
        [System.Drawing.Color]::FromArgb(33, 105, 144),
        [System.Drawing.Color]::FromArgb(22, 49, 80)
    )
    $graphics.FillPath($shieldFill, $shieldPath)
    $shieldStroke = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(186, 93, 221, 218), 2)
    $graphics.DrawPath($shieldStroke, $shieldPath)

    $wifiPen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(230, 235, 253, 255), 8)
    $wifiPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $wifiPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawArc($wifiPen, 882, 222, 124, 95, 222, 96)
    $graphics.DrawArc($wifiPen, 903, 243, 82, 62, 222, 96)
    $graphics.DrawArc($wifiPen, 924, 265, 40, 31, 222, 96)
    $graphics.FillEllipse([System.Drawing.Brushes]::White, 939, 296, 12, 12)

    $statusBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(22, 35, 53))
    $statusPath = New-RoundedPath 891 414 107 34 17
    $graphics.FillPath($statusBrush, $statusPath)
    $graphics.DrawPath($chipOutline, $statusPath)
    $statusPath.Dispose()
    $graphics.FillEllipse($cyan, 906, 427, 8, 8)
    Draw-Text $graphics "ON THIS PC" 922 421 11 "Bold" $muted

    $bitmap.Save($output, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Created product cover: $output ($width x $height)"
}
finally {
    $graphics.Dispose()
    $bitmap.Dispose()
}
