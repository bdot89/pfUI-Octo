param([string]$Root = (Join-Path $PSScriptRoot ".."))
# Draws pfUI Octo's game-icons.net crests and raid mark sets (16 Nov 2026; user: "Download about 100 icons and put
# them in tidy the best rated ones that look good put if there are any raid markers also").
# Icons: tools\gameicons\*.png (512 x 512, white on black, from https://game-icons.net, CC BY 3.0 - the authors
# are in tools\gameicons\list.txt and on the Art page). Each picture becomes a signed distance field (its outline),
# then is lit like MakeMarkArt.ps1's crests: bevelled metal, highlight, dark outline, drop shadow.
#   img\elite\gi\<author>-<icon>-<elite|rare|boss>.tga   64 x 64, gold / silver / red   (unit frames, Art page)
#   img\plates\gi\<author>-<icon>.tga                    32 x 32, chrome, tinted in game (nameplate marks)
#   img\marks\emblems.tga, img\marks\fantasy.tga         the game's 4 x 4 raid mark sheet (marks1 / marks2)
#   modules\art-icons.lua                                the list for the Lua side (GENERATED)
# Uncompressed 32-bit TGA, bottom-left origin, 4 x 4 samples per pixel. Same output every run.
#   powershell -ExecutionPolicy Bypass -File tools\MakeIconArt.ps1

$src = @'
using System;
using System.IO;
public static class IconArt {
  // ---------------------------------------------------------------- the outline of a picture
  // a signed distance field on an N x N grid (grid pixels; < 0 inside), fitted into an output box
  public class Field {
    public int N; public double[] D; public double cx, cy, scale, ow, oh;
    public double F(double x, double y) {
      double gx = cx + (x - ow / 2) * scale - 0.5, gy = cy + (y - oh / 2) * scale - 0.5;
      int x0 = (int)Math.Floor(gx), y0 = (int)Math.Floor(gy);
      double fx = gx - x0, fy = gy - y0;
      double a = At(x0, y0), b = At(x0 + 1, y0), c = At(x0, y0 + 1), d = At(x0 + 1, y0 + 1);
      return ((a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy) / scale;
    }
    double At(int x, int y) {
      if (x < 0 || y < 0 || x >= N || y >= N) {
        int cx2 = Math.Max(0, Math.Min(N - 1, x)), cy2 = Math.Max(0, Math.Min(N - 1, y));
        return D[cy2 * N + cx2] + Math.Abs(x - cx2) + Math.Abs(y - cy2);
      }
      return D[y * N + x];
    }
  }
  // squared distance transform in one line (Felzenszwalb & Huttenlocher)
  static void Edt1(double[] f, int n, double[] d, int[] v, double[] z) {
    int k = 0; v[0] = 0; z[0] = -1e20; z[1] = 1e20;
    for (int q = 1; q < n; q++) {
      double s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2.0 * q - 2.0 * v[k]);
      while (s <= z[k]) { k--; s = ((f[q] + q * q) - (f[v[k]] + v[k] * v[k])) / (2.0 * q - 2.0 * v[k]); }
      k++; v[k] = q; z[k] = s; z[k + 1] = 1e20;
    }
    k = 0;
    for (int q = 0; q < n; q++) { while (z[k + 1] < q) k++; d[q] = (q - v[k]) * (q - v[k]) + f[v[k]]; }
  }
  static double[] Edt(bool[] seed, int N) {
    double[] g = new double[N * N], f = new double[N], d = new double[N], z = new double[N + 1];
    int[] v = new int[N];
    for (int i = 0; i < N * N; i++) g[i] = seed[i] ? 0 : 1e20;
    for (int x = 0; x < N; x++) {
      for (int y = 0; y < N; y++) f[y] = g[y * N + x];
      Edt1(f, N, d, v, z);
      for (int y = 0; y < N; y++) g[y * N + x] = d[y];
    }
    for (int y = 0; y < N; y++) {
      for (int x = 0; x < N; x++) f[x] = g[y * N + x];
      Edt1(f, N, d, v, z);
      for (int x = 0; x < N; x++) g[y * N + x] = d[x];
    }
    return g;
  }
  // red channel of a W x W picture (white = the shape) -> its field, fitted into ow x oh less a margin
  public static Field Make(byte[] red, int W, double ow, double oh, double margin) {
    int N = 256, k = W / N;
    bool[] inside = new bool[N * N], outside = new bool[N * N];
    int x0 = N, y0 = N, x1 = -1, y1 = -1;
    for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
      int sum = 0;
      for (int sy = 0; sy < k; sy++) for (int sx = 0; sx < k; sx++) sum += red[(y * k + sy) * W + x * k + sx];
      bool on = sum >= 128 * k * k;
      inside[y * N + x] = on; outside[y * N + x] = !on;
      if (on) { x0 = Math.Min(x0, x); y0 = Math.Min(y0, y); x1 = Math.Max(x1, x); y1 = Math.Max(y1, y); }
    }
    double[] toIn = Edt(inside, N), toOut = Edt(outside, N);
    Field fd = new Field(); fd.N = N; fd.D = new double[N * N];
    for (int i = 0; i < N * N; i++) fd.D[i] = inside[i] ? -(Math.Sqrt(toOut[i]) - 0.5) : (Math.Sqrt(toIn[i]) - 0.5);
    double w = x1 - x0 + 1, h = y1 - y0 + 1;
    fd.cx = (x0 + x1 + 1) / 2.0; fd.cy = (y0 + y1 + 1) / 2.0;
    fd.ow = ow; fd.oh = oh;
    fd.scale = Math.Max(w / (ow - 2 * margin), h / (oh - 2 * margin));
    return fd;
  }

  // ---------------------------------------------------------------- colours (as MakeMarkArt.ps1)
  static double[][] Ramp(string name) {
    switch (name) {
      case "gold": return new double[][] { new double[] { 92, 54, 6 }, new double[] { 214, 160, 36 }, new double[] { 255, 238, 150 } };
      case "chrome": return new double[][] { new double[] { 96, 98, 108 }, new double[] { 222, 224, 232 }, new double[] { 255, 255, 255 } };
      case "silver": return new double[][] { new double[] { 56, 62, 76 }, new double[] { 172, 182, 198 }, new double[] { 248, 252, 255 } };
      case "red": return new double[][] { new double[] { 76, 6, 8 }, new double[] { 206, 38, 34 }, new double[] { 255, 176, 150 } };
      case "yellow": return new double[][] { new double[] { 120, 80, 0 }, new double[] { 255, 214, 20 }, new double[] { 255, 252, 190 } };
      case "orange": return new double[][] { new double[] { 120, 44, 0 }, new double[] { 255, 130, 20 }, new double[] { 255, 220, 160 } };
      case "purple": return new double[][] { new double[] { 56, 14, 100 }, new double[] { 168, 70, 235 }, new double[] { 238, 196, 255 } };
      case "green": return new double[][] { new double[] { 10, 80, 20 }, new double[] { 60, 220, 70 }, new double[] { 200, 255, 190 } };
      case "ice": return new double[][] { new double[] { 50, 70, 100 }, new double[] { 170, 205, 240 }, new double[] { 250, 253, 255 } };
      case "blue": return new double[][] { new double[] { 8, 40, 120 }, new double[] { 40, 130, 255 }, new double[] { 180, 225, 255 } };
      default: return new double[][] { new double[] { 70, 70, 80 }, new double[] { 226, 226, 232 }, new double[] { 255, 255, 255 } };
    }
  }
  public static string[] MarkColors = { "yellow", "orange", "purple", "green", "ice", "blue", "red", "bone" };
  static double[] Pick(double[][] r, double t) {
    t = Math.Max(0, Math.Min(1, t));
    double[] a = t < 0.5 ? r[0] : r[1], b = t < 0.5 ? r[1] : r[2];
    double u = t < 0.5 ? t * 2 : (t - 0.5) * 2;
    return new double[] { a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u };
  }

  // ---------------------------------------------------------------- lighting (bevelled metal)
  static double[] Shade(Field f, double[][] ramp, double x, double y, double bevel, double outline, double shadow) {
    double d = f.F(x, y);
    if (d > 0) {
      double sd = f.F(x - 1.0, y - 1.5);
      if (sd <= 0 && shadow > 0) return new double[] { 0, 0, 0, 255 * shadow };
      // a soft dark rim just outside, so thin shapes stand out on any background
      if (d < 1.2) return new double[] { 0, 0, 0, 255 * 0.45 * (1 - d / 1.2) };
      return new double[] { 0, 0, 0, 0 };
    }
    double[] dark = ramp[0];
    if (d > -outline) return new double[] { dark[0] * 0.35, dark[1] * 0.35, dark[2] * 0.35, 255 };
    double e = 0.35;
    double hx = Height(f, x + e, y, bevel, outline) - Height(f, x - e, y, bevel, outline);
    double hy = Height(f, x, y + e, bevel, outline) - Height(f, x, y - e, bevel, outline);
    double nx = -hx / (2 * e) * 1.15, ny = -hy / (2 * e) * 1.15, nz = 1;
    double nl = Math.Sqrt(nx * nx + ny * ny + nz * nz);
    nx /= nl; ny /= nl; nz /= nl;
    double lx = -0.45, ly = -0.65, lz = 0.62, ll = Math.Sqrt(lx * lx + ly * ly + lz * lz);
    lx /= ll; ly /= ll; lz /= ll;
    double diff = Math.Max(0, nx * lx + ny * ly + nz * lz);
    double hxv = lx, hyv = ly, hzv = lz + 1, hl = Math.Sqrt(hxv * hxv + hyv * hyv + hzv * hzv);
    double spec = Math.Pow(Math.Max(0, (nx * hxv + ny * hyv + nz * hzv) / hl), 28);
    // a little top-to-bottom sheen on the flat parts, so big shapes are not one flat colour
    double sheen = 0.08 * (1 - y / f.oh);
    double[] col = Pick(ramp, 0.12 + diff * 0.95 + sheen);
    double s = spec * 0.85;
    return new double[] { Math.Min(255, col[0] + 255 * s), Math.Min(255, col[1] + 255 * s), Math.Min(255, col[2] + 255 * s), 255 };
  }
  static double Height(Field f, double x, double y, double bevel, double outline) {
    double d = f.F(x, y);
    double depth = Math.Max(0, -d - outline);
    double t = Math.Min(1, depth / bevel);
    return bevel * 0.9 * Math.Sin(t * Math.PI / 2);
  }

  // ---------------------------------------------------------------- writing
  static byte[] Tga(int W, int H) {
    byte[] data = new byte[18 + W * H * 4];
    data[2] = 2;
    data[12] = (byte)(W & 255); data[13] = (byte)(W >> 8);
    data[14] = (byte)(H & 255); data[15] = (byte)(H >> 8);
    data[16] = 32; data[17] = 8;
    return data;
  }
  static void Put(byte[] data, int W, int H, int px, int row, double[] c) {
    int o = 18 + ((H - 1 - row) * W + px) * 4;
    data[o] = (byte)Math.Round(c[2]); data[o + 1] = (byte)Math.Round(c[1]);
    data[o + 2] = (byte)Math.Round(c[0]); data[o + 3] = (byte)Math.Round(c[3]);
  }
  static void Cell(byte[] data, int W, int H, int ox, int oy, int cw, int ch, Field f, double[][] ramp,
                   double bevel, double outline, double shadow) {
    int SS = 4;
    for (int py = 0; py < ch; py++) for (int px = 0; px < cw; px++) {
      double r = 0, g = 0, b = 0, a = 0;
      for (int sy = 0; sy < SS; sy++) for (int sx = 0; sx < SS; sx++) {
        double x = px + (sx + 0.5) / SS, y = py + (sy + 0.5) / SS;
        double[] c = Shade(f, ramp, x, y, bevel, outline, shadow);
        double al = c[3] / 255;
        r += c[0] * al; g += c[1] * al; b += c[2] * al; a += al;
      }
      double n = SS * SS;
      double[] o = a > 0 ? new double[] { r / a, g / a, b / a, 255 * a / n } : new double[] { 0, 0, 0, 0 };
      Put(data, W, H, ox + px, oy + py, o);
    }
  }
  public static void Crest(string path, byte[] red, int W, string col, int size, double bevel, double outline) {
    byte[] data = Tga(size, size);
    Field f = Make(red, W, size, size, size / 16.0);
    Cell(data, size, size, 0, 0, size, size, f, Ramp(col), bevel, outline, 0.55);
    File.WriteAllBytes(path, data);
  }
  public static byte[] Sheet() { return Tga(256, 256); }
  public static void SheetCell(byte[] data, int i, byte[] red, int W) {
    Field f = Make(red, W, 64, 64, 3.5);
    Cell(data, 256, 256, (i % 4) * 64, (i / 4) * 64, 64, 64, f, Ramp(MarkColors[i]), 3.6, 1.1, 0.5);
  }
  public static void Save(string path, byte[] data) { File.WriteAllBytes(path, data); }
}
'@
Add-Type -TypeDefinition $src
Add-Type -AssemblyName System.Drawing

$icons = Join-Path $Root "tools\gameicons"
$eliteDir = Join-Path $Root "img\elite\gi"
$plateDir = Join-Path $Root "img\plates\gi"
$markDir = Join-Path $Root "img\marks"
foreach ($d in $eliteDir, $plateDir, $markDir) { New-Item -ItemType Directory -Force $d | Out-Null }

# the red channel of a picture, row by row from the top
function Red($file) {
  $bmp = [Drawing.Bitmap]::FromFile($file)
  $w = $bmp.Width
  $rect = New-Object Drawing.Rectangle 0, 0, $w, $bmp.Height
  $bd = $bmp.LockBits($rect, [Drawing.Imaging.ImageLockMode]::ReadOnly, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $raw = New-Object byte[] ($bd.Stride * $bmp.Height)
  [Runtime.InteropServices.Marshal]::Copy($bd.Scan0, $raw, 0, $raw.Length)
  $bmp.UnlockBits($bd)
  $bmp.Dispose()
  $red = New-Object byte[] ($w * $w)
  for ($i = 0; $i -lt $red.Length; $i++) { $red[$i] = $raw[$i * 4 + 2] }
  return , $red
}

$crests = @()
$sheets = @{ marks1 = @(); marks2 = @() }
foreach ($line in Get-Content (Join-Path $icons "list.txt")) {
  if ($line -match '^#' -or $line -notmatch '\|') { continue }
  $g, $p, $label = $line -split '\|'
  $id = $p -replace '/', '-'
  if ($sheets.ContainsKey($g)) { $sheets[$g] += $id } else { $crests += , @($id, $label, $g) }
}

$cache = @{}
function RedOf($id) {
  if (-not $cache.ContainsKey($id)) { $cache[$id] = Red (Join-Path $icons "$id.png") }
  return , $cache[$id]
}
foreach ($c in $crests) {
  $id = $c[0]
  $red = RedOf $id
  foreach ($k in @(@("elite", "gold"), @("rare", "silver"), @("boss", "red"))) {
    [IconArt]::Crest((Join-Path $eliteDir "$id-$($k[0]).tga"), $red, 512, $k[1], 64, 3.0, 1.1)
  }
  [IconArt]::Crest((Join-Path $plateDir "$id.tga"), $red, 512, "chrome", 32, 1.7, 0.8)
}
foreach ($set in @(@("marks1", "emblems"), @("marks2", "fantasy"))) {
  $data = [IconArt]::Sheet()
  $ids = $sheets[$set[0]]
  for ($i = 0; $i -lt 8; $i++) { [IconArt]::SheetCell($data, $i, (RedOf $ids[$i]), 512) }
  [IconArt]::Save((Join-Path $markDir "$($set[1]).tga"), $data)
}

# the list for the Lua side
$lua = New-Object Text.StringBuilder
[void]$lua.AppendLine("-- pfUI Octo :: game-icons.net crests. GENERATED by tools\MakeIconArt.ps1 from tools\gameicons\list.txt - do not edit by hand.")
[void]$lua.AppendLine("-- Icons from https://game-icons.net (CC BY 3.0) by Lorc, Delapouite, Skoll, sbed, Faithtoken, DarkZaitzev, Caro Asercion")
[void]$lua.AppendLine("-- and Carl Olsen, lit as bevelled metal. { file id, shown name, group }; files img\elite\gi\<id>-<elite|rare|boss>, img\plates\gi\<id>.")
[void]$lua.AppendLine("pfUI.artIcons = {")
foreach ($c in $crests) {
  $label = $c[1] -replace '"', '\"'
  [void]$lua.AppendLine("  { `"$($c[0])`", `"$label`", `"$($c[2])`" },")
}
[void]$lua.AppendLine("}")
[IO.File]::WriteAllText((Join-Path $Root "modules\art-icons.lua"), $lua.ToString().Replace("`r`n", "`n"), (New-Object Text.UTF8Encoding $false))
"crests: $($crests.Count) x 3 + plate marks; mark sheets: emblems, fantasy"
"{0:N0} KB in img\elite\gi, {1:N0} KB in img\plates\gi" -f ((Get-ChildItem $eliteDir | Measure-Object Length -Sum).Sum / 1KB), ((Get-ChildItem $plateDir | Measure-Object Length -Sum).Sum / 1KB)
