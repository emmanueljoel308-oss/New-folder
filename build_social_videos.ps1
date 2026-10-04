$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Speech

$root = $PSScriptRoot
$ffmpeg = (Get-Command ffmpeg.exe -ErrorAction Stop).Source
$ffprobe = (Get-Command ffprobe.exe -ErrorAction Stop).Source
$workRoot = Join-Path $root "build\social-videos"
$packageDir = Join-Path $root "dist\Wi-Fi-Guard-Social-Video"
$zipPath = Join-Path $root "dist\Wi-Fi-Guard-Social-Videos.zip"
$fps = 30
$transition = 0.45
$voice = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice.SelectVoice("Microsoft Zira Desktop")
$voice.Rate = 0
$voice.Volume = 100
$voiceLines = @(
    "Does your Windows PC keep joining a Wi-Fi network you don't want? Meet Wi-Fi Guard.",
    "Enter the exact network name and select Block Network.",
    "The Wi-Fi block is managed by Windows and applies on this PC.",
    "To remove the block, enter the name and select Allow Network.",
    "Get the standalone 32-bit and 64-bit versions on Payhip. Administrator permission is required. Compatibility with Windows 7 and 8 has not been verified."
)
$scenes = @(
    @{
        Title = "A Wi-Fi network`nkeeps joining?"
        Caption = "Does your Windows PC keep joining a Wi-Fi network you don't want? Meet Wi-Fi Guard."
        State = "networks"
    },
    @{
        Title = "Block it by`nnetwork name."
        Caption = "Enter the exact network name and select Block Network."
        State = "block"
    },
    @{
        Title = "A Wi-Fi block`nfor this PC."
        Caption = "The Wi-Fi block is managed by Windows and applies on this PC."
        State = "blocked"
    },
    @{
        Title = "Allow it again`nwhen you choose."
        Caption = "To remove the block, enter the name and select Allow Network."
        State = "allow"
    },
    @{
        Title = "Choose your`nWindows version."
        Caption = "Get the standalone 32-bit and 64-bit versions on Payhip. Administrator permission is required. Compatibility with Windows 7 and 8 has not been verified."
        State = "download"
    }
)
$formats = @(
    @{ Name = "vertical"; Width = 1080; Height = 1920 },
    @{ Name = "square"; Width = 1080; Height = 1080 },
    @{ Name = "widescreen"; Width = 1920; Height = 1080 }
)

function New-RoundRect([float]$x, [float]$y, [float]$width, [float]$height, [float]$radius) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $diameter = [Math]::Min($radius * 2, [Math]::Min($width, $height))
    [void]$path.AddArc($x, $y, $diameter, $diameter, 180, 90)
    [void]$path.AddArc($x + $width - $diameter, $y, $diameter, $diameter, 270, 90)
    [void]$path.AddArc($x + $width - $diameter, $y + $height - $diameter, $diameter, $diameter, 0, 90)
    [void]$path.AddArc($x, $y + $height - $diameter, $diameter, $diameter, 90, 90)
    $path.CloseFigure()
    return $path
}

function Draw-RoundRect($graphics, [float]$x, [float]$y, [float]$width, [float]$height, [float]$radius, $brush, $pen = $null) {
    $path = New-RoundRect $x $y $width $height $radius
    $graphics.FillPath($brush, $path)
    if ($pen) {
        $graphics.DrawPath($pen, $path)
    }
    $path.Dispose()
}

function Draw-Text($graphics, [string]$text, [float]$x, [float]$y, [float]$size, [bool]$bold, $brush, [float]$width = 0, [System.Drawing.StringAlignment]$align = [System.Drawing.StringAlignment]::Near) {
    $style = if ($bold) { [System.Drawing.FontStyle]::Bold } else { [System.Drawing.FontStyle]::Regular }
    $font = [System.Drawing.Font]::new("Segoe UI", $size, $style, [System.Drawing.GraphicsUnit]::Pixel)
    $format = [System.Drawing.StringFormat]::new()
    $format.Alignment = $align
    $format.LineAlignment = [System.Drawing.StringAlignment]::Near
    $format.Trimming = [System.Drawing.StringTrimming]::Word
    if ($width -gt 0) {
        $rectangle = [System.Drawing.RectangleF]::new($x, $y, $width, 240)
        $graphics.DrawString($text, $font, $brush, $rectangle, $format)
    } else {
        $graphics.DrawString($text, $font, $brush, $x, $y, $format)
    }
    $format.Dispose()
    $font.Dispose()
}

function Draw-WiFiMark($graphics, [float]$x, [float]$y, [float]$scale, $cyan, $white, $outline) {
    $shield = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $points = [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new($x + 0.08 * $scale, $y),
        [System.Drawing.PointF]::new($x + 0.92 * $scale, $y + 0.16 * $scale),
        [System.Drawing.PointF]::new($x + 0.84 * $scale, $y + 0.76 * $scale),
        [System.Drawing.PointF]::new($x + 0.50 * $scale, $y + 1.00 * $scale),
        [System.Drawing.PointF]::new($x + 0.16 * $scale, $y + 0.76 * $scale)
    )
    $shield.AddPolygon($points)
    $graphics.FillPath($cyan, $shield)
    $graphics.DrawPath($outline, $shield)
    $shield.Dispose()
    $pen = [System.Drawing.Pen]::new($white, [Math]::Max(1, 0.05 * $scale))
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $graphics.DrawArc($pen, $x + 0.24 * $scale, $y + 0.28 * $scale, 0.52 * $scale, 0.37 * $scale, 218, 104)
    $graphics.DrawArc($pen, $x + 0.36 * $scale, $y + 0.42 * $scale, 0.28 * $scale, 0.19 * $scale, 218, 104)
    $graphics.FillEllipse($white, $x + 0.48 * $scale, $y + 0.63 * $scale, 0.05 * $scale, 0.05 * $scale)
    $pen.Dispose()
}

function Draw-ProductPanel($graphics, [float]$x, [float]$y, [float]$width, [float]$height, [string]$state, $palette) {
    $scale = $width / 520
    $panelPath = New-RoundRect $x $y $width $height (22 * $scale)
    $graphics.FillPath($palette.Panel, $panelPath)
    $graphics.DrawPath($palette.Border, $panelPath)
    $panelPath.Dispose()

    $graphics.FillEllipse($palette.Cyan, $x + 24 * $scale, $y + 24 * $scale, 11 * $scale, 11 * $scale)
    Draw-Text $graphics "WI-FI GUARD" ($x + 47 * $scale) ($y + 19 * $scale) (17 * $scale) $true $palette.White
    Draw-Text $graphics "WINDOWS UTILITY" ($x + $width - 166 * $scale) ($y + 22 * $scale) (10 * $scale) $false $palette.Muted
    $graphics.DrawLine($palette.PanelRule, $x + 20 * $scale, $y + 61 * $scale, $x + $width - 20 * $scale, $y + 61 * $scale)

    if ($state -eq "networks") {
        Draw-Text $graphics "Example nearby networks" ($x + 25 * $scale) ($y + 91 * $scale) (15 * $scale) $false $palette.Muted
        $cards = @(
            @{ Name = "CoffeeShop_Public"; Status = "Auto-join"; Color = $palette.Warning; Y = 128 },
            @{ Name = "Home_WiFi"; Status = "Saved"; Color = $palette.Muted; Y = 201 }
        )
        foreach ($card in $cards) {
            Draw-RoundRect $graphics ($x + 19 * $scale) ($y + $card.Y * $scale) ($width - 38 * $scale) (60 * $scale) (10 * $scale) $palette.Inner
            Draw-Text $graphics $card.Name ($x + 35 * $scale) ($y + ($card.Y + 12) * $scale) (16 * $scale) $true $palette.White
            Draw-Text $graphics $card.Status ($x + $width - 137 * $scale) ($y + ($card.Y + 16) * $scale) (12 * $scale) $false $card.Color
        }
        Draw-Text $graphics "Decide which networks this PC can join." ($x + 25 * $scale) ($y + 300 * $scale) (14 * $scale) $false $palette.Muted ($width - 50 * $scale)
    } elseif ($state -eq "block" -or $state -eq "allow") {
        $heading = if ($state -eq "allow") { "Remove a block" } else { "Network name (SSID)" }
        $action = if ($state -eq "allow") { "ALLOW NETWORK" } else { "BLOCK NETWORK" }
        Draw-Text $graphics $heading ($x + 25 * $scale) ($y + 93 * $scale) (15 * $scale) $false $palette.Muted
        Draw-RoundRect $graphics ($x + 20 * $scale) ($y + 127 * $scale) ($width - 40 * $scale) (59 * $scale) (8 * $scale) $palette.Inner $palette.Border
        Draw-Text $graphics "CoffeeShop_Public" ($x + 37 * $scale) ($y + 144 * $scale) (16 * $scale) $false $palette.White
        Draw-RoundRect $graphics ($x + 20 * $scale) ($y + 212 * $scale) ($width - 40 * $scale) (55 * $scale) (10 * $scale) $palette.Button
        Draw-Text $graphics $action ($x + 37 * $scale) ($y + 230 * $scale) (14 * $scale) $true $palette.White ($width - 75 * $scale) ([System.Drawing.StringAlignment]::Center)
        Draw-Text $graphics "Enter the exact Wi-Fi name, then apply your choice." ($x + 25 * $scale) ($y + 297 * $scale) (13 * $scale) $false $palette.Muted ($width - 48 * $scale)
    } elseif ($state -eq "blocked") {
        Draw-Text $graphics "Your block applies on this PC" ($x + 25 * $scale) ($y + 93 * $scale) (15 * $scale) $false $palette.Muted
        Draw-RoundRect $graphics ($x + 20 * $scale) ($y + 127 * $scale) ($width - 40 * $scale) (70 * $scale) (10 * $scale) $palette.Inner
        $graphics.FillEllipse($palette.Success, $x + 37 * $scale, $y + 150 * $scale, 12 * $scale, 12 * $scale)
        Draw-Text $graphics "CoffeeShop_Public" ($x + 60 * $scale) ($y + 145 * $scale) (15 * $scale) $true $palette.White
        Draw-Text $graphics "BLOCK ACTIVE" ($x + 60 * $scale) ($y + 169 * $scale) (11 * $scale) $false $palette.Success
        Draw-RoundRect $graphics ($x + 20 * $scale) ($y + 223 * $scale) ($width - 40 * $scale) (48 * $scale) (8 * $scale) $palette.Badge
        Draw-Text $graphics "Saved by Windows" ($x + 34 * $scale) ($y + 238 * $scale) (13 * $scale) $false $palette.Cyan
    } else {
        Draw-Text $graphics "Your download includes both builds" ($x + 25 * $scale) ($y + 94 * $scale) (15 * $scale) $false $palette.Muted ($width - 48 * $scale)
        foreach ($item in @(@{ Y = 136; Label = "WINDOWS-X86"; Bits = "32-bit"; Note = "32-bit or 64-bit PCs" }, @{ Y = 216; Label = "WINDOWS-X64"; Bits = "64-bit"; Note = "64-bit PCs" })) {
            Draw-RoundRect $graphics ($x + 19 * $scale) ($y + $item.Y * $scale) ($width - 38 * $scale) (67 * $scale) (10 * $scale) $palette.Inner
            Draw-Text $graphics $item.Label ($x + 34 * $scale) ($y + ($item.Y + 9) * $scale) (10 * $scale) $true $palette.Cyan
            Draw-Text $graphics "$($item.Bits) app" ($x + 34 * $scale) ($y + ($item.Y + 29) * $scale) (15 * $scale) $true $palette.White
            Draw-Text $graphics $item.Note ($x + $width - 159 * $scale) ($y + ($item.Y + 27) * $scale) (10 * $scale) $false $palette.Muted
        }
        Draw-RoundRect $graphics ($x + 19 * $scale) ($y + 310 * $scale) ($width - 38 * $scale) (46 * $scale) (9 * $scale) $palette.Button
        Draw-Text $graphics "GET IT ON PAYHIP" ($x + 34 * $scale) ($y + 323 * $scale) (13 * $scale) $true $palette.White ($width - 68 * $scale) ([System.Drawing.StringAlignment]::Center)
        Draw-Text $graphics "payhip.com/b/cVBTb" ($x + 23 * $scale) ($y + 370 * $scale) (12 * $scale) $true $palette.Cyan ($width - 46 * $scale) ([System.Drawing.StringAlignment]::Center)
    }
}

function New-Palette([int]$width, [int]$height) {
    return @{
        Background = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
            [System.Drawing.Point]::new(0, 0),
            [System.Drawing.Point]::new($width, $height),
            [System.Drawing.Color]::FromArgb(12, 21, 39),
            [System.Drawing.Color]::FromArgb(21, 42, 69)
        )
        Panel = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(24, 40, 58))
        Inner = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(31, 50, 70))
        White = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(247, 250, 252))
        Muted = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(179, 197, 214))
        Dim = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(126, 151, 172))
        Cyan = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(90, 226, 225))
        Button = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(34, 145, 183))
        Badge = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(29, 70, 82))
        Warning = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(249, 183, 95))
        Success = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(100, 224, 168))
        Border = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(67, 98, 125), 1)
        PanelRule = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(53, 74, 95), 1)
        ShieldOutline = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(180, 233, 255, 255), 1)
        Grid = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(14, 152, 192, 201), 1)
    }
}

function Render-Scene([string]$path, $format, $scene, [int]$index, [int]$total) {
    $width = $format.Width
    $height = $format.Height
    $bitmap = [System.Drawing.Bitmap]::new($width, $height)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $palette = New-Palette $width $height
    try {
        $graphics.FillRectangle($palette.Background, 0, 0, $width, $height)

        $gridWidth = if ($format.Name -eq "vertical") { 390 } elseif ($format.Name -eq "square") { 320 } else { 470 }
        for ($gx = ($width - $gridWidth); $gx -lt $width; $gx += 64) {
            $graphics.DrawLine($palette.Grid, $gx, 0, $gx, $height)
        }
        for ($gy = 20; $gy -lt $height; $gy += 64) {
            $graphics.DrawLine($palette.Grid, [Math]::Max(0, $width - $gridWidth), $gy, $width, $gy)
        }

        $vertical = $format.Name -eq "vertical"
        $square = $format.Name -eq "square"
        if ($vertical) {
            $brandScale = 47
            Draw-WiFiMark $graphics 73 82 $brandScale $palette.Cyan $palette.White $palette.ShieldOutline
            Draw-Text $graphics "WI-FI GUARD" 139 91 28 $true $palette.White
            Draw-Text $graphics "$('{0:D2}' -f ($index + 1))  /  05" 829 98 16 $true $palette.Cyan
            Draw-RoundRect $graphics 75 221 276 42 21 $palette.Badge
            Draw-Text $graphics "SIMPLE WI-FI CONTROL" 93 232 14 $true $palette.Cyan
            Draw-Text $graphics $scene.Title 74 310 68 $true $palette.White 920
            Draw-ProductPanel $graphics 74 572 932 806 $scene.State $palette
            Draw-RoundRect $graphics 66 1410 948 210 22 $palette.Inner
            Draw-Text $graphics $scene.Caption 96 1438 30 $false $palette.White 888
            Draw-Text $graphics "YOUR NETWORK. YOUR RULES." 79 1670 17 $true $palette.Cyan
            Draw-Text $graphics "Standalone app  ·  Administrator permission required" 79 1724 17 $false $palette.Muted 912
            Draw-Text $graphics "Windows 7/8 compatibility not verified" 79 1771 15 $false $palette.Dim 912
            if ($index -eq 4) {
                Draw-Text $graphics "payhip.com/b/cVBTb" 79 1815 19 $true $palette.Cyan
            }
        } elseif ($square) {
            Draw-WiFiMark $graphics 58 49 40 $palette.Cyan $palette.White $palette.ShieldOutline
            Draw-Text $graphics "WI-FI GUARD" 113 56 24 $true $palette.White
            Draw-Text $graphics "$('{0:D2}' -f ($index + 1)) / 05" 884 63 14 $true $palette.Cyan
            Draw-RoundRect $graphics 67 164 226 34 17 $palette.Badge
            Draw-Text $graphics "WI-FI CONTROL FOR WINDOWS" 81 174 11 $true $palette.Cyan
            Draw-Text $graphics $scene.Title 67 236 44 $true $palette.White 432
            Draw-ProductPanel $graphics 544 200 474 595 $scene.State $palette
            Draw-RoundRect $graphics 60 814 960 167 19 $palette.Inner
            Draw-Text $graphics $scene.Caption 84 839 25 $false $palette.White 910
            Draw-Text $graphics "Standalone 32-bit + 64-bit  ·  Admin permission required" 68 1023 13 $true $palette.Muted 930
            if ($index -eq 4) {
                Draw-Text $graphics "payhip.com/b/cVBTb  ·  Windows 7/8 compatibility not verified" 67 1055 11 $false $palette.Cyan 940
            }
        } else {
            Draw-WiFiMark $graphics 74 49 45 $palette.Cyan $palette.White $palette.ShieldOutline
            Draw-Text $graphics "WI-FI GUARD" 136 59 25 $true $palette.White
            Draw-Text $graphics "$('{0:D2}' -f ($index + 1))  /  05" 1731 68 14 $true $palette.Cyan
            Draw-RoundRect $graphics 79 239 248 37 19 $palette.Badge
            Draw-Text $graphics "SIMPLE WI-FI CONTROL" 97 249 12 $true $palette.Cyan
            Draw-Text $graphics $scene.Title 78 316 61 $true $palette.White 850
            Draw-Text $graphics "Your network. Your rules." 82 489 23 $false $palette.Muted 805
            Draw-ProductPanel $graphics 1044 198 795 648 $scene.State $palette
            Draw-RoundRect $graphics 73 857 1770 137 20 $palette.Inner
            Draw-Text $graphics $scene.Caption 102 878 27 $false $palette.White 1710
            Draw-Text $graphics "Standalone 32-bit + 64-bit  ·  Administrator permission required" 80 1014 16 $false $palette.Muted 1340
            if ($index -eq 4) {
                Draw-Text $graphics "payhip.com/b/cVBTb  ·  Windows 7/8 compatibility not verified" 1210 1014 14 $true $palette.Cyan 620
            }
        }

        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        foreach ($item in $palette.Values) {
            $item.Dispose()
        }
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

function Invoke-CheckedProcess([string]$executable, [string[]]$arguments, [string]$description) {
    & $executable @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$description failed with exit code $LASTEXITCODE."
    }
}

try {
    $voiceDirectory = Join-Path $workRoot "voice"
    New-Item -ItemType Directory -Path $voiceDirectory -Force | Out-Null
    $voiceFiles = @()
    for ($i = 0; $i -lt $scenes.Count; $i++) {
        $voicePath = Join-Path $voiceDirectory ("scene-{0:D2}.wav" -f ($i + 1))
        $voice.SetOutputToWaveFile($voicePath)
        $voice.Speak($voiceLines[$i])
        $voice.SetOutputToNull()
        $voiceFiles += $voicePath
    }

    New-Item -ItemType Directory -Path $packageDir -Force | Out-Null
    $durationSum = 0.0
    $durations = @()
    foreach ($voicePath in $voiceFiles) {
        $probeOutput = & $ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $voicePath
        if ($LASTEXITCODE -ne 0) {
            throw "Could not measure generated voice-over audio: $voicePath"
        }
        $spokenDuration = [double]::Parse($probeOutput.Trim(), [Globalization.CultureInfo]::InvariantCulture)
        $sceneDuration = [Math]::Max(4.2, $spokenDuration + 0.85)
        $durations += $sceneDuration
        $durationSum += $sceneDuration
    }

    $totalTransitions = $transition * ($scenes.Count - 1)
    for ($formatIndex = 0; $formatIndex -lt $formats.Count; $formatIndex++) {
        $format = $formats[$formatIndex]
        $frameDirectory = Join-Path $workRoot $format.Name
        $outputDirectory = Join-Path $packageDir $format.Name
        New-Item -ItemType Directory -Path $frameDirectory -Force | Out-Null
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

        for ($i = 0; $i -lt $scenes.Count; $i++) {
            $frame = Join-Path $frameDirectory ("scene-{0:D2}.png" -f ($i + 1))
            Render-Scene $frame $format $scenes[$i] $i $scenes.Count
        }

        $filterParts = @()
        for ($i = 0; $i -lt $scenes.Count; $i++) {
            $frames = [Math]::Ceiling($durations[$i] * $fps)
            $filterParts += "[$($i * 2):v]zoompan=z='min(zoom+0.00024,1.04)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=$($format.Width)x$($format.Height):fps=$fps,trim=end_frame=$frames,setpts=PTS-STARTPTS,format=yuv420p[v$i]"
        }

        $previous = "v0"
        $cumulative = $durations[0]
        for ($i = 1; $i -lt $scenes.Count; $i++) {
            $offset = $cumulative - ($transition * $i)
            $nextLabel = if ($i -eq $scenes.Count - 1) { "vout" } else { "mix$i" }
            $filterParts += "[$previous][v$i]xfade=transition=fade:duration=$transition`:offset=$([Math]::Round($offset, 3).ToString([Globalization.CultureInfo]::InvariantCulture))[$nextLabel]"
            $previous = $nextLabel
            $cumulative += $durations[$i]
        }

        $audioInputs = @()
        $inputArguments = @()
        for ($i = 0; $i -lt $scenes.Count; $i++) {
            $inputArguments += @("-loop", "1", "-framerate", "$fps", "-t", "$($durations[$i])", "-i", (Join-Path $frameDirectory ("scene-{0:D2}.png" -f ($i + 1))))
            $inputArguments += @("-i", $voiceFiles[$i])
            $audioInputs += "[$($i * 2 + 1):a]"
        }
        $audioFilter = ($audioInputs -join "") + "concat=n=$($scenes.Count):v=0:a=1,apad=pad_dur=8[aout]"
        $filterParts += $audioFilter
        $filterComplex = $filterParts -join ";"

        $fileName = switch ($format.Name) {
            "vertical" { "Wi-Fi-Guard-Vertical-Reels-Shorts-TikTok.mp4" }
            "square" { "Wi-Fi-Guard-Square-Feed.mp4" }
            "widescreen" { "Wi-Fi-Guard-Widescreen-YouTube.mp4" }
        }
        $videoPath = Join-Path $outputDirectory $fileName
        $arguments = @("-hide_banner", "-loglevel", "error") + $inputArguments + @(
            "-filter_complex", $filterComplex,
            "-map", "[vout]",
            "-map", "[aout]",
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-crf", "21",
            "-pix_fmt", "yuv420p",
            "-r", "$fps",
            "-c:a", "aac",
            "-b:a", "128k",
            "-movflags", "+faststart",
            "-metadata", "title=Wi-Fi Guard",
            "-metadata", "comment=Standalone Windows Wi-Fi utility. Administrator permission required; Windows 7/8 compatibility has not been verified.",
            "-shortest",
            "-y",
            $videoPath
        )
        Invoke-CheckedProcess $ffmpeg $arguments "Encoding the $($format.Name) social video"

        $probe = & $ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,width,height,pix_fmt -show_entries format=duration -of json $videoPath
        if ($LASTEXITCODE -ne 0) {
            throw "Could not verify the $($format.Name) social video."
        }
        $videoInfo = $probe | ConvertFrom-Json
        $videoStream = $videoInfo.streams | Select-Object -First 1
        if (-not $videoStream -or $videoStream.codec_name -ne "h264" -or $videoStream.width -ne $format.Width -or $videoStream.height -ne $format.Height -or $videoStream.pix_fmt -ne "yuv420p") {
            throw "The $($format.Name) video has an unexpected codec, resolution, or pixel format."
        }
        Write-Host ("Verified {0}: {1}x{2}, H.264/AAC, {3:N1}s" -f $format.Name, $videoStream.width, $videoStream.height, [double]$videoInfo.format.duration)
    }

    $captions = @"
WI-FI GUARD | SOCIAL MEDIA COPY

Meet Wi-Fi Guard: enter the exact Wi-Fi network name, block it on this PC, and allow it again whenever you choose.

Includes standalone Windows x86 (32-bit) and x64 (64-bit) apps. Administrator permission is required to change Windows WLAN filters. Windows 7/8 compatibility has not been verified.

Get Wi-Fi Guard: https://payhip.com/b/cVBTb

#Windows #WiFi #PCtips #TechTools

Video files:
vertical\Wi-Fi-Guard-Vertical-Reels-Shorts-TikTok.mp4 — TikTok, Instagram Reels, YouTube Shorts
square\Wi-Fi-Guard-Square-Feed.mp4 — square social feeds
widescreen\Wi-Fi-Guard-Widescreen-YouTube.mp4 — YouTube and widescreen posts
"@
    Set-Content -LiteralPath (Join-Path $packageDir "SOCIAL-CAPTION.txt") -Value $captions -Encoding UTF8

    if (Test-Path -LiteralPath $zipPath) {
        Remove-Item -LiteralPath $zipPath -Force
    }
    Compress-Archive -Path (Join-Path $packageDir "*") -DestinationPath $zipPath -CompressionLevel Optimal
    Write-Host "`nReady-to-share bundle: $zipPath"
} finally {
    $voice.Dispose()
}
