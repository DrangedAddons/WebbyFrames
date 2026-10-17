# Generates Media\castbox-mask-target.tga: the cast box's mask on the target layout. White (shown)
# everywhere except inside a circle around the portrait ring's centre, so the box's right end curves
# along the ring. The cut is at the middle of the ring's gold band (about 26.5-29.5px from its centre);
# the band, drawn on top, covers it.
param([string]$Out)
# box in frame TOPLEFT coordinates (must match CAST_BOX in WebbyFrames.lua)
$x1 = 20.5; $x2 = 200; $top = -71; $h = 16
# portrait ring centre and the cut radius
$cx = 177; $cy = -48; $rCut = 28
$W = 512; $H = 64          # power-of-two image, stretched over the box
$bytes = New-Object byte[] (18 + $W * $H * 4)
$bytes[2] = 2                                   # uncompressed true colour
[BitConverter]::GetBytes([uint16]$W).CopyTo($bytes, 12)
[BitConverter]::GetBytes([uint16]$H).CopyTo($bytes, 14)
$bytes[16] = 32                                  # bits per pixel
$bytes[17] = 8                                   # 8 alpha bits, origin bottom left
$i = 18
for ($row = 0; $row -lt $H; $row++) {           # bottom row first
    $v = ($H - 1 - $row + 0.5) / $H * $h        # distance down from the box's top, in frame units
    $fy = $top - $v
    for ($col = 0; $col -lt $W; $col++) {
        $fx = $x1 + ($col + 0.5) / $W * ($x2 - $x1)
        $d = [Math]::Sqrt(($fx - $cx) * ($fx - $cx) + ($fy - $cy) * ($fy - $cy))
        $a = [Math]::Min(1.0, [Math]::Max(0.0, ($d - $rCut) * 2))     # soft 0.5px edge
        $b = [byte][Math]::Round($a * 255)
        $bytes[$i] = $b; $bytes[$i + 1] = $b; $bytes[$i + 2] = $b; $bytes[$i + 3] = $b
        $i += 4
    }
}
[IO.File]::WriteAllBytes($Out, $bytes)
"wrote $Out ($($bytes.Length) bytes)"
