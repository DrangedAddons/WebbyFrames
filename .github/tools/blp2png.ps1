# Decodes a BLP2 (DXT1/3/5) texture's first mip to PNG. Usage: blp2png.ps1 -In x.blp -Out x.png
param([string]$In, [string]$Out)
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System; using System.Drawing; using System.Drawing.Imaging;
public static class Blp {
    static void C565(int c, out int r, out int g, out int b) { r = ((c >> 11) & 31) * 255 / 31; g = ((c >> 5) & 63) * 255 / 63; b = (c & 31) * 255 / 31; }
    public static Bitmap Decode(byte[] d) {
        int w = BitConverter.ToInt32(d, 12), h = BitConverter.ToInt32(d, 16);
        int alphaDepth = d[9], alphaType = d[10];
        int off = BitConverter.ToInt32(d, 20);
        bool dxt1 = alphaDepth <= 1, dxt5 = alphaType == 7;
        var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        int p = off;
        for (int by = 0; by < h; by += 4) for (int bx = 0; bx < w; bx += 4) {
            int[] alpha = new int[16];
            for (int i = 0; i < 16; i++) alpha[i] = 255;
            if (!dxt1) {
                if (dxt5) {
                    int a0 = d[p], a1 = d[p + 1];
                    ulong bits = 0; for (int i = 0; i < 6; i++) bits |= (ulong)d[p + 2 + i] << (8 * i);
                    int[] av = new int[8]; av[0] = a0; av[1] = a1;
                    if (a0 > a1) for (int i = 1; i < 7; i++) av[i + 1] = ((7 - i) * a0 + i * a1) / 7;
                    else { for (int i = 1; i < 5; i++) av[i + 1] = ((5 - i) * a0 + i * a1) / 5; av[6] = 0; av[7] = 255; }
                    for (int i = 0; i < 16; i++) alpha[i] = av[(int)((bits >> (3 * i)) & 7)];
                } else {
                    for (int i = 0; i < 16; i++) { int v = (d[p + i / 2] >> ((i % 2) * 4)) & 15; alpha[i] = v * 17; }
                }
                p += 8;
            }
            int c0 = d[p] | (d[p + 1] << 8), c1 = d[p + 2] | (d[p + 3] << 8);
            uint idx = BitConverter.ToUInt32(d, p + 4); p += 8;
            int r0, g0, b0, r1, g1, b1; C565(c0, out r0, out g0, out b0); C565(c1, out r1, out g1, out b1);
            int[,] col = new int[4, 4];
            col[0, 0] = r0; col[0, 1] = g0; col[0, 2] = b0; col[0, 3] = 255;
            col[1, 0] = r1; col[1, 1] = g1; col[1, 2] = b1; col[1, 3] = 255;
            if (c0 > c1 || !dxt1) {
                col[2, 0] = (2 * r0 + r1) / 3; col[2, 1] = (2 * g0 + g1) / 3; col[2, 2] = (2 * b0 + b1) / 3; col[2, 3] = 255;
                col[3, 0] = (r0 + 2 * r1) / 3; col[3, 1] = (g0 + 2 * g1) / 3; col[3, 2] = (b0 + 2 * b1) / 3; col[3, 3] = 255;
            } else {
                col[2, 0] = (r0 + r1) / 2; col[2, 1] = (g0 + g1) / 2; col[2, 2] = (b0 + b1) / 2; col[2, 3] = 255;
                col[3, 0] = 0; col[3, 1] = 0; col[3, 2] = 0; col[3, 3] = 0;
            }
            for (int i = 0; i < 16; i++) {
                int k = (int)((idx >> (2 * i)) & 3);
                int x = bx + i % 4, y = by + i / 4;
                if (x < w && y < h) {
                    int a = dxt1 ? col[k, 3] : alpha[i];
                    bmp.SetPixel(x, y, Color.FromArgb(a, col[k, 0], col[k, 1], col[k, 2]));
                }
            }
        }
        return bmp;
    }
}
'@
$bmp = [Blp]::Decode([IO.File]::ReadAllBytes($In))
$bmp.Save($Out, [Drawing.Imaging.ImageFormat]::Png)
"saved $Out ($($bmp.Width)x$($bmp.Height))"
