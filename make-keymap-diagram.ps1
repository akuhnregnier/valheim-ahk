# Generates keymap.svg, a diagram of the bindings described in keymap.json.
#
#   powershell -ExecutionPolicy Bypass -File make-keymap-diagram.ps1
#
# Key positions, sizes, styles and text all come from keymap.json. The layout of
# the buttons inside the mouse body and the colour values are defined here.
param(
    [string]$In = (Join-Path $PSScriptRoot 'keymap.json'),
    [string]$Out = (Join-Path $PSScriptRoot 'keymap.svg')
)

$map = Get-Content -Raw -Encoding UTF8 $In | ConvertFrom-Json
$geo = $map.geometry

# Colour names that keymap.json's styles may use: a light fill and a border.
$palette = @{
    teal    = @{ fill = '#cdeee6'; stroke = '#1b9e8a' }
    purple  = @{ fill = '#e0dcf7'; stroke = '#6b5bd0' }
    coral   = @{ fill = '#fbdcd2'; stroke = '#e0603a' }
    pink    = @{ fill = '#fbdbe8'; stroke = '#d55181' }
    amber   = @{ fill = '#fbe8bf'; stroke = '#c98500' }
    blue    = @{ fill = '#d6e6fb'; stroke = '#2a78d6' }
    gray    = @{ fill = '#ecebe7'; stroke = '#6b6a66' }
    neutral = @{ fill = '#f4f3f0'; stroke = '#c3c2b7' }
}
$ink = '#0b0b0b'        # key names
$ink2 = '#52514e'       # actions, legend, note
$muted = '#898781'      # unused keys and secondary remarks
$surface = '#fcfcfb'
$hairline = '#e1e0d9'

function Esc([string]$text) {
    [System.Security.SecurityElement]::Escape($text)
}

# "os_remap" -> "OS remap"
function Pretty([string]$name) {
    $words = $name -split '_' | ForEach-Object { if ($_ -eq 'os') { 'OS' } else { $_ } }
    $text = $words -join ' '
    $text.Substring(0, 1).ToUpper() + $text.Substring(1)
}

function Wrap([string]$text, [int]$maxChars) {
    $lines = @()
    $line = ''
    foreach ($word in $text -split ' ') {
        if ($line -and ($line.Length + 1 + $word.Length) -gt $maxChars) {
            $lines += $line
            $line = $word
        } elseif ($line) {
            $line = "$line $word"
        } else {
            $line = $word
        }
    }
    if ($line) { $lines += $line }
    $lines
}

# Fill and border attributes for one of keymap.json's styles.
function ShapeStyle([string]$styleName) {
    $style = $map.styles.$styleName
    if (-not $style) { throw "keymap.json uses style '$styleName' but does not define it." }
    $colour = $palette[$style.color]
    if (-not $colour) { throw "Style '$styleName' uses colour '$($style.color)', which this script does not know." }
    $attributes = "fill=`"$($colour.fill)`" stroke=`"$($colour.stroke)`" stroke-width=`"1.5`""
    if ($style.border -eq 'dashed') { $attributes += ' stroke-dasharray="4 3"' }
    $attributes
}

# A name with its actions and remarks stacked underneath.
function TextBlock($x, $y, [string]$name, $entry, [int]$maxChars, [string]$anchor = 'start') {
    $nameInk = if ($entry.style -eq 'unused') { $muted } else { $ink }
    $svg = "<text x=`"$x`" y=`"$y`" text-anchor=`"$anchor`" font-size=`"13`" font-weight=`"600`" fill=`"$nameInk`">$(Esc $name)</text>"
    $lineY = $y + 14
    if ($entry.actions) {
        foreach ($action in $entry.actions) {
            foreach ($line in @(Wrap $action $maxChars)) {
                $svg += "<text x=`"$x`" y=`"$lineY`" text-anchor=`"$anchor`" font-size=`"9`" fill=`"$ink2`">$(Esc $line)</text>"
                $lineY += 11
            }
        }
    }
    foreach ($remark in @($entry.sub, $entry.mode, $entry.label)) {
        if ($remark) {
            $svg += "<text x=`"$x`" y=`"$lineY`" text-anchor=`"$anchor`" font-size=`"8.5`" font-style=`"italic`" fill=`"$muted`">$(Esc $remark)</text>"
            $lineY += 11
        }
    }
    $svg
}

function Tooltip([string]$name, $entry) {
    $what = if ($entry.actions) { $entry.actions -join ', ' } else { 'unused' }
    "<title>$(Esc "${name}: $what")</title>"
}

function Key($key, $x, $y, $width, $height) {
    $svg = "<g>$(Tooltip $key.key $key)"
    $svg += "<rect x=`"$x`" y=`"$y`" width=`"$width`" height=`"$height`" rx=`"$($geo.key.radius)`" $(ShapeStyle $key.style)/>"
    if ($key.os_remap_marker) {
        $svg += "<rect x=`"$($x + $width - 18)`" y=`"$($y + 7)`" width=`"11`" height=`"11`" rx=`"2.5`" $(ShapeStyle 'os_remap')/>"
    }
    if ($key.home_key) {
        $middle = $x + $width / 2
        $bumpY = $y + $height - 7
        $svg += "<line x1=`"$($middle - 7)`" y1=`"$bumpY`" x2=`"$($middle + 7)`" y2=`"$bumpY`" stroke=`"$ink2`" stroke-width=`"2`" stroke-linecap=`"round`"/>"
    }
    $svg += TextBlock ($x + 7) ($y + 18) $key.key $key 11
    $svg + '</g>'
}

# A rectangle whose corners can each have a different radius.
function RoundedPath($x, $y, $width, $height, $topLeft, $topRight, $bottomRight, $bottomLeft) {
    $right = $x + $width
    $bottom = $y + $height
    "M$($x + $topLeft),$y H$($right - $topRight) A$topRight,$topRight 0 0 1 $right,$($y + $topRight) " +
    "V$($bottom - $bottomRight) A$bottomRight,$bottomRight 0 0 1 $($right - $bottomRight),$bottom " +
    "H$($x + $bottomLeft) A$bottomLeft,$bottomLeft 0 0 1 $x,$($bottom - $bottomLeft) " +
    "V$($y + $topLeft) A$topLeft,$topLeft 0 0 1 $($x + $topLeft),$y Z"
}

function MouseButton([string]$name, $path, $textX, $textY, [int]$maxChars) {
    $button = $map.mouse.$name
    if (-not $button) { return '' }
    "<g>$(Tooltip (Pretty $name) $button)<path d=`"$path`" $(ShapeStyle $button.style)/>" +
    (TextBlock $textX $textY (Pretty $name) $button $maxChars 'middle') + '</g>'
}

function Mouse {
    $body = $geo.mouse_body
    $inset = 8
    $wheelWidth = 14
    $centre = $body.x + $body.width / 2
    $top = $body.y + $inset
    $buttonWidth = ($body.width - 2 * $inset - $wheelWidth - 8) / 2
    $buttonHeight = 104
    $outer = $body.radius - $inset
    $leftX = $body.x + $inset
    $rightX = $body.x + $body.width - $inset - $buttonWidth

    $svg = "<rect x=`"$($body.x)`" y=`"$($body.y)`" width=`"$($body.width)`" height=`"$($body.height)`" rx=`"$($body.radius)`" " +
        "fill=`"$($palette.neutral.fill)`" stroke=`"$($palette.neutral.stroke)`" stroke-width=`"1.5`"/>"
    $svg += MouseButton 'left' (RoundedPath $leftX $top $buttonWidth $buttonHeight $outer 6 6 6) ($leftX + $buttonWidth / 2) ($top + 50) 10
    $svg += MouseButton 'right' (RoundedPath $rightX $top $buttonWidth $buttonHeight 6 $outer 6 6) ($rightX + $buttonWidth / 2) ($top + 50) 10

    # The wheel itself is too narrow for text, so its actions go in the first box below.
    $boxX = $body.x + 16
    $boxWidth = $body.width - 32
    $boxY = $top + $buttonHeight + 10
    if ($map.mouse.wheel_click) {
        $svg += "<rect x=`"$($centre - $wheelWidth / 2)`" y=`"$($top + 18)`" width=`"$wheelWidth`" height=`"46`" rx=`"$($wheelWidth / 2)`" $(ShapeStyle $map.mouse.wheel_click.style)/>"
    }
    foreach ($box in @(@{ name = 'wheel_click'; height = 50 }, @{ name = 'forward'; height = 52 }, @{ name = 'back'; height = 40 })) {
        $svg += MouseButton $box.name (RoundedPath $boxX $boxY $boxWidth $box.height 6 6 6 6) $centre ($boxY + 17) 20
        $boxY += $box.height + 6
    }
    $svg
}

function Legend {
    $left = $geo.mouse_body.x
    $step = ($geo.viewbox[0] - 2 * $left) / $map.legend.Count
    $svg = ''
    for ($i = 0; $i -lt $map.legend.Count; $i++) {
        $x = $left + $i * $step
        $svg += "<rect x=`"$x`" y=`"$($geo.legend_y - 11)`" width=`"14`" height=`"14`" rx=`"3`" $(ShapeStyle $map.legend[$i])/>"
        $svg += "<text x=`"$($x + 20)`" y=`"$($geo.legend_y)`" font-size=`"10`" fill=`"$ink2`">$(Esc (Pretty $map.legend[$i]))</text>"
    }
    $svg
}

$width = $geo.viewbox[0]
$height = $geo.viewbox[1]
$parts = @(
    "<svg xmlns=`"http://www.w3.org/2000/svg`" viewBox=`"0 0 $width $height`" width=`"$width`" height=`"$height`" role=`"img`" font-family=`"system-ui, -apple-system, 'Segoe UI', sans-serif`">"
    "<title>$(Esc $map.title)</title>"
    "<desc>$(Esc $map.keyboard_layout)</desc>"
    "<rect x=`"0.5`" y=`"0.5`" width=`"$($width - 1)`" height=`"$($height - 1)`" rx=`"8`" fill=`"$surface`" stroke=`"$hairline`"/>"
    (Mouse)
)
foreach ($row in $geo.rows.PSObject.Properties) {
    $keys = @($map.keyboard.($row.Name))
    for ($i = 0; $i -lt $keys.Count; $i++) {
        $parts += Key $keys[$i] ($row.Value.x + $i * $geo.key.pitch) $row.Value.y $geo.key.width $geo.key.height
    }
}
$parts += Key $map.keyboard.space $geo.space.x $geo.space.y $geo.space.width $geo.space.height
$parts += Legend
$parts += "<text x=`"$($geo.mouse_body.x)`" y=`"$($geo.note_y)`" font-size=`"10`" fill=`"$ink2`">$(Esc $map.note)</text>"
$parts += '</svg>'

[System.IO.File]::WriteAllText($Out, ($parts -join "`n") + "`n", (New-Object System.Text.UTF8Encoding $false))
"Wrote $Out"
