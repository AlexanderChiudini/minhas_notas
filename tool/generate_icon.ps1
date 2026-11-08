# Renders the editable SVG primitives with Windows System.Drawing. No downloads.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
[xml]$svg = Get-Content -LiteralPath (Join-Path $projectRoot 'assets/icon/app_icon.svg') -Raw
$bitmap = New-Object System.Drawing.Bitmap 1024,1024
$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
foreach ($shape in $svg.svg.ChildNodes) {
    if ($shape.NodeType -ne [System.Xml.XmlNodeType]::Element) { continue }
    if ($shape.Name -eq 'line') {
        $pen = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml($shape.stroke)),([single]$shape.'stroke-width')
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawLine($pen,[single]$shape.x1,[single]$shape.y1,[single]$shape.x2,[single]$shape.y2)
        $pen.Dispose()
        continue
    }
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml($shape.fill))
    if ($shape.Name -eq 'polygon') {
        [System.Drawing.PointF[]]$points = @($shape.points.Split(' ') | ForEach-Object {
            $xy = $_.Split(',')
            New-Object System.Drawing.PointF ([single]$xy[0]),([single]$xy[1])
        })
        $graphics.FillPolygon($brush,$points)
    } elseif ($shape.Name -eq 'rect') {
        $x = [single]$shape.x
        $y = [single]$shape.y
        $w = [single]$shape.width
        $h = [single]$shape.height
        $d = [single]$shape.rx * 2
        $outline = New-Object System.Drawing.Drawing2D.GraphicsPath
        $outline.AddArc($x,$y,$d,$d,180,90)
        $outline.AddArc(($x+$w-$d),$y,$d,$d,270,90)
        $outline.AddArc(($x+$w-$d),($y+$h-$d),$d,$d,0,90)
        $outline.AddArc($x,($y+$h-$d),$d,$d,90,90)
        $outline.CloseFigure()
        $graphics.FillPath($brush,$outline)
        $outline.Dispose()
    }
    $brush.Dispose()
}
$bitmap.Save((Join-Path $projectRoot 'assets/icon/app_icon.png'),[System.Drawing.Imaging.ImageFormat]::Png)
$graphics.Dispose()
$bitmap.Dispose()
