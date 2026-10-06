param(
	[string]$Repo = 'C:\Users\Compumar\proyectos\lightweight-charts',
	[string]$Desktop = [Environment]::GetFolderPath('Desktop')
)

# Creates the two desktop shortcuts: one for the local documentation site and
# one for the candle demo. Both icons are produced by scripts/make-icon.ps1 and
# are generated here when missing, so a fresh checkout needs no binary in git.

$icons = @(
	@{ Path = 'scripts\lwc.ico'; Palette = '19,26,38,41,98,255'; Switch = @() },
	@{ Path = 'scripts\lwc-demo.ico'; Palette = '45,26,14,240,160,32'; Switch = @('-ShowVolume') },
	@{ Path = 'scripts\lwc-live.ico'; Palette = '14,20,28,0,200,150'; Switch = @('-Motif', 'Live') }
)

foreach ($icon in $icons) {
	$path = Join-Path $Repo $icon.Path
	if (Test-Path $path) { continue }
	Write-Output "Generating $path"
	& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Repo 'scripts\make-icon.ps1') -OutPath $path -Palette $icon.Palette @($icon.Switch)
	if (-not (Test-Path $path)) { throw "Icon generation failed: $path" }
}

$targets = @(
	@{
		Name = 'Lightweight Charts'
		Target = Join-Path $Repo 'open-website.cmd'
		Icon = Join-Path $Repo 'scripts\lwc.ico'
		Description = 'Lightweight Charts - documentacion y demos (sitio local)'
	},
	@{
		Name = 'Lightweight Charts - Demo'
		Target = Join-Path $Repo 'demo\index.html'
		Icon = Join-Path $Repo 'scripts\lwc-demo.ico'
		Description = 'Lightweight Charts - demo de velas con volumen y media movil'
	},
	@{
		Name = 'Lightweight Charts - Datos reales'
		Target = Join-Path $Repo 'demo\live.html'
		Icon = Join-Path $Repo 'scripts\lwc-live.ico'
		Description = 'Lightweight Charts - velas reales de Binance, con auto-refresh'
	}
)

$shell = New-Object -ComObject WScript.Shell

foreach ($entry in $targets) {
	if (-not (Test-Path $entry.Target)) { throw "Target not found: $($entry.Target)" }
	if (-not (Test-Path $entry.Icon)) { throw "Icon not found: $($entry.Icon)" }

	$link = Join-Path $Desktop ($entry.Name + '.lnk')
	$shortcut = $shell.CreateShortcut($link)
	$shortcut.TargetPath = $entry.Target
	$shortcut.WorkingDirectory = $Repo
	$shortcut.IconLocation = "$($entry.Icon),0"
	$shortcut.Description = $entry.Description
	$shortcut.WindowStyle = 1
	$shortcut.Save()

	Write-Output "Created $link"
	Write-Output "  Target : $($entry.Target)"
	Write-Output "  Icon   : $($entry.Icon)"
}