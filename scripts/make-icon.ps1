param(
	[string]$OutPath = "$PSScriptRoot\lwc.ico",
	# Six comma-separated channels: two background/header colours, then the header.
	[string]$Palette = '19,26,38,41,98,255',
	[switch]$ShowVolume
)

Add-Type -AssemblyName System.Drawing

$rgb = $Palette.Split(',') | ForEach-Object { [int]$_.Trim() }

function New-CandleIcon([int]$size) {
	$s = [double]$size
	$bmp = New-Object System.Drawing.Bitmap($size, $size)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g.Clear([System.Drawing.Color]::Transparent)

	$bg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $rgb[0], $rgb[1], $rgb[2]))
	$g.FillRectangle($bg, 0, 0, $s, $s)

	$blue = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $rgb[3], $rgb[4], $rgb[5]))
	$g.FillRectangle($blue, 0, 0, $s, $s * 0.16)

	$up = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 38, 166, 154))
	$down = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 239, 83, 80))
	$wick = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 240, 245, 255))

	# x-centre, body-top, body-height as fractions of the icon width
	$candles = @(
		@{ x = 0.24; top = 0.50; h = 0.22; rising = $false; wickTop = 0.40; wickBottom = 0.80 },
		@{ x = 0.43; top = 0.40; h = 0.20; rising = $true; wickTop = 0.28; wickBottom = 0.68 },
		@{ x = 0.62; top = 0.30; h = 0.18; rising = $true; wickTop = 0.22; wickBottom = 0.56 },
		@{ x = 0.81; top = 0.20; h = 0.22; rising = $true; wickTop = 0.14; wickBottom = 0.50 }
	)

	$bodyW = $s * 0.13
	# The volume variant keeps the candles in the upper part of the tile so the
	# histogram strip below them has room of its own.
	$priceScale = if ($ShowVolume) { 0.70 } else { 1.0 }

	foreach ($c in $candles) {
		$cx = $s * $c.x
		$wickW = [Math]::Max(1.0, $s * 0.022)
		$wickTop = $s * ($c.wickTop * $priceScale)
		$wickBottom = $s * ($c.wickBottom * $priceScale)
		$g.FillRectangle($wick, $cx - $wickW / 2, $wickTop, $wickW, $wickBottom - $wickTop)

		$body = if ($c.rising) { $up } else { $down }
		$g.FillRectangle($body, $cx - $bodyW / 2, $s * ($c.top * $priceScale), $bodyW, $s * ($c.h * $priceScale))

		if ($ShowVolume) {
			# Taller bars where the candle moved more, like a real volume strip.
			$volH = $s * (0.07 + 0.16 * (1 - $c.top))
			$g.FillRectangle($body, $cx - $bodyW / 2, $s - $volH, $bodyW, $volH)
		}
	}

	$g.Dispose()
	$bg.Dispose(); $blue.Dispose(); $up.Dispose(); $down.Dispose(); $wick.Dispose()
	return $bmp
}

$sizes = @(256, 128, 64, 48, 32, 24, 16)
function ConvertTo-Dib([System.Drawing.Bitmap]$bmp) {
	$w = $bmp.Width
	$h = $bmp.Height
	$xorStride = $w * 4
	$andStride = [int]([Math]::Floor((($w + 31) / 32)) * 4)

	$ms = New-Object System.IO.MemoryStream
	$bw = New-Object System.IO.BinaryWriter($ms)

	$bw.Write([Int32]40)
	$bw.Write([Int32]$w)
	$bw.Write([Int32]($h * 2))
	$bw.Write([UInt16]1)
	$bw.Write([UInt16]32)
	$bw.Write([Int32]0)
	$bw.Write([Int32](($xorStride * $h) + ($andStride * $h)))
	$bw.Write([Int32]0)
	$bw.Write([Int32]0)
	$bw.Write([Int32]0)
	$bw.Write([Int32]0)

	for ($y = $h - 1; $y -ge 0; $y--) {
		for ($x = 0; $x -lt $w; $x++) {
			$c = $bmp.GetPixel($x, $y)
			$bw.Write([Byte]$c.B)
			$bw.Write([Byte]$c.G)
			$bw.Write([Byte]$c.R)
			$bw.Write([Byte]$c.A)
		}
	}

	for ($y = 0; $y -lt $h; $y++) {
		for ($b = 0; $b -lt $andStride; $b++) { $bw.Write([Byte]0) }
	}

	$bw.Dispose()
	$dib = $ms.ToArray()
	$ms.Dispose()
	return $dib
}

$images = @()
foreach ($size in $sizes) {
	$bmp = New-CandleIcon $size
	$images += , @{ Size = $size; Bytes = (ConvertTo-Dib $bmp) }
	$bmp.Dispose()
}

$fs = [System.IO.File]::Create($OutPath)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0)
$bw.Write([UInt16]1)
$bw.Write([UInt16]$images.Count)

$offset = 6 + (16 * $images.Count)
foreach ($img in $images) {
	$dim = 0
	if ($img.Size -lt 256) { $dim = $img.Size }
	$bw.Write([Byte]$dim)
	$bw.Write([Byte]$dim)
	$bw.Write([Byte]0)
	$bw.Write([Byte]0)
	$bw.Write([UInt16]1)
	$bw.Write([UInt16]32)
	$bw.Write([UInt32]$img.Bytes.Length)
	$bw.Write([UInt32]$offset)
	$offset += $img.Bytes.Length
}
foreach ($img in $images) {
	$bw.Write($img.Bytes, 0, $img.Bytes.Length)
}
$bw.Dispose()
$fs.Dispose()

Write-Output "Wrote $OutPath ($($images.Count) sizes: $($sizes -join ', '))"