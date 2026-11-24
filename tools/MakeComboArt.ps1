param([string]$OutDir = (Join-Path $PSScriptRoot "..\img\plates"))
# Makes the combo point shapes of pfUI Octo (modules/combo.lua; 24 Nov 2026, user: "more options for combo points ...
# art work ... make them amazing"). Our own: signed-distance shapes, bevelled and lit like polished chrome (the same
# lighting as MakeMarkArt.ps1), a dark rim and a soft shadow, white so the game tints each point any colour.
#   cp-<shape>.tga   64 x 64, uncompressed 32-bit TGA, bottom-left origin, 4 x 4 samples a pixel
# Shapes: diamond hex star drop flame blade rune crescent skull chevron heart shard
#   powershell -ExecutionPolicy Bypass -File tools\MakeComboArt.ps1

$src = @"
using System;
using System.IO;
public delegate double Sdf(double x, double y);
public static class ComboArt {
  static double Circ(double x, double y, double cx, double cy, double r) { return Math.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) - r; }
  static double Poly(double[] p, double x, double y) {
    double best = 1e9; bool inside = false; int n = p.Length / 2;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      double xi = p[2 * i], yi = p[2 * i + 1], xj = p[2 * j], yj = p[2 * j + 1];
      double vx = xi - xj, vy = yi - yj, wx = x - xj, wy = y - yj;
      double t = Math.Max(0, Math.Min(1, (vx * wx + vy * wy) / (vx * vx + vy * vy)));
      double dx = wx - vx * t, dy = wy - vy * t;
      best = Math.Min(best, Math.Sqrt(dx * dx + dy * dy));
      if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) inside = !inside;
    }
    return inside ? -best : best;
  }
  static double Box(double x, double y, double cx, double cy, double hw, double hh, double r) {
    double qx = Math.Abs(x - cx) - (hw - r), qy = Math.Abs(y - cy) - (hh - r);
    double ox = Math.Max(qx, 0), oy = Math.Max(qy, 0);
    return Math.Sqrt(ox * ox + oy * oy) + Math.Min(Math.Max(qx, qy), 0) - r;
  }
  static double RotBox(double x, double y, double cx, double cy, double hw, double hh, double r, double deg) {
    double a = deg * Math.PI / 180, c = Math.Cos(a), s = Math.Sin(a), dx = x - cx, dy = y - cy;
    return Box(cx + dx * c + dy * s, cy - dx * s + dy * c, cx, cy, hw, hh, r);
  }
  static double Un(double a, double b) { return Math.Min(a, b); }
  static double Df(double a, double b) { return Math.Max(a, -b); }
  static double[] Ngon(double cx, double cy, double R, int n, double rot) {
    double[] p = new double[n * 2];
    for (int i = 0; i < n; i++) { double a = rot + i * 2 * Math.PI / n; p[2 * i] = cx + R * Math.Cos(a); p[2 * i + 1] = cy + R * Math.Sin(a); }
    return p;
  }
  static double[] Star(double cx, double cy, double R, double k) {
    double[] p = new double[20];
    for (int i = 0; i < 10; i++) { double a = -Math.PI / 2 + i * Math.PI / 5, r = (i % 2 == 0) ? R : R * k; p[2 * i] = cx + r * Math.Cos(a); p[2 * i + 1] = cy + r * Math.Sin(a); }
    return p;
  }

  // y grows downwards (row 0 = top); the shapes fill about 52 of 64 px, centred
  public static Sdf Shape(string s) {
    switch (s) {
      case "diamond": { double[] p = { 32, 5, 55, 32, 32, 59, 9, 32 }; return (x, y) => Poly(p, x, y); }
      case "hex": { double[] p = Ngon(32, 32, 26, 6, Math.PI / 6); return (x, y) => Poly(p, x, y); }
      case "star": { double[] p = Star(32, 34, 28, 0.45); return (x, y) => Poly(p, x, y); }
      case "drop": {
        double[] t = { 32, 4, 49, 36, 15, 36 };
        return (x, y) => Un(Circ(x, y, 32, 40, 17), Poly(t, x, y));
      }
      case "flame": {
        // three tongues of fire: a tall one in the middle, a shorter one each side leaning out
        double[] t = { 33, 2, 46, 36, 20, 36 };
        double[] l = { 13, 14, 26, 40, 12, 44 };
        double[] r = { 53, 18, 52, 46, 40, 42 };
        return (x, y) => Un(Un(Un(Circ(x, y, 32, 44, 15), Poly(t, x, y)), Un(Circ(x, y, 18, 46, 9), Poly(l, x, y))),
          Un(Circ(x, y, 46, 47, 8), Poly(r, x, y)));
      }
      case "blade": {
        double[] b = { 32, 2, 43, 36, 32, 44, 21, 36 };
        return (x, y) => Un(Un(Poly(b, x, y), Box(x, y, 32, 45, 17, 4, 2)), Box(x, y, 32, 54, 5, 8, 2.5));
      }
      case "rune": {
        // a ring with a carved rune: a stave and two arms
        return (x, y) => Un(Df(Circ(x, y, 32, 32, 26), Circ(x, y, 32, 32, 19)),
          Un(Box(x, y, 32, 32, 3, 17, 1), Un(RotBox(x, y, 37, 25, 2.6, 9, 1, -40), RotBox(x, y, 27, 39, 2.6, 9, 1, -40))));
      }
      case "crescent": return (x, y) => Df(Circ(x, y, 32, 32, 26), Circ(x, y, 43, 26, 21));
      case "skull": {
        double[] nose = { 32, 33, 28, 41, 36, 41 };
        return (x, y) => Df(Df(Df(Un(Circ(x, y, 32, 27, 23), Box(x, y, 32, 50, 14, 10, 4)), Circ(x, y, 23, 28, 6.5)),
          Circ(x, y, 41, 28, 6.5)), Poly(nose, x, y));
      }
      case "chevron": { double[] p = { 8, 12, 32, 30, 56, 12, 56, 30, 32, 52, 8, 30 }; return (x, y) => Poly(p, x, y); }
      case "heart": {
        double[] t = { 8, 30, 56, 30, 32, 58 };
        return (x, y) => Un(Un(Circ(x, y, 21, 23, 14), Circ(x, y, 43, 23, 14)), Poly(t, x, y));
      }
      case "shard": { double[] p = { 36, 3, 50, 22, 40, 60, 16, 44, 18, 14 }; return (x, y) => Poly(p, x, y); }
    }
    return (x, y) => Circ(x, y, 32, 32, 26);
  }

  static double Height(Sdf f, double x, double y, double bevel, double outline) {
    double d = f(x, y), depth = Math.Max(0, -d - outline), t = Math.Min(1, depth / bevel);
    return bevel * 0.9 * Math.Sin(t * Math.PI / 2);
  }
  // chrome: dark, middle, light
  static double[][] RAMP = { new double[] { 96, 98, 108 }, new double[] { 222, 224, 232 }, new double[] { 255, 255, 255 } };
  static double[] Pick(double t) {
    t = Math.Max(0, Math.Min(1, t));
    double[] a, b; double k;
    if (t < 0.5) { a = RAMP[0]; b = RAMP[1]; k = t / 0.5; } else { a = RAMP[1]; b = RAMP[2]; k = (t - 0.5) / 0.5; }
    return new double[] { a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k };
  }
  static double[] Shade(Sdf f, double x, double y) {
    double bevel = 7, outline = 1.6, shadow = 0.45;
    double d = f(x, y);
    if (d > 0) {
      if (f(x - 1.2, y - 1.8) <= 0) return new double[] { 0, 0, 0, 255 * shadow };
      return new double[] { 0, 0, 0, 0 };
    }
    if (d > -outline) return new double[] { 22, 22, 26, 255 };
    double e = 0.35;
    double hx = Height(f, x + e, y, bevel, outline) - Height(f, x - e, y, bevel, outline);
    double hy = Height(f, x, y + e, bevel, outline) - Height(f, x, y - e, bevel, outline);
    double nx = -hx / (2 * e) * 1.15, ny = -hy / (2 * e) * 1.15, nz = 1, nl = Math.Sqrt(nx * nx + ny * ny + nz * nz);
    nx /= nl; ny /= nl; nz /= nl;
    double lx = -0.45, ly = -0.65, lz = 0.62, ll = Math.Sqrt(lx * lx + ly * ly + lz * lz);
    lx /= ll; ly /= ll; lz /= ll;
    double diff = Math.Max(0, nx * lx + ny * ly + nz * lz);
    double hxv = lx, hyv = ly, hzv = lz + 1, hl = Math.Sqrt(hxv * hxv + hyv * hyv + hzv * hzv);
    double spec = Math.Pow(Math.Max(0, (nx * hxv + ny * hyv + nz * hzv) / hl), 28);
    double[] col = Pick(0.12 + diff * 0.95);
    double s = spec * 0.85;
    return new double[] { Math.Min(255, col[0] + 255 * s), Math.Min(255, col[1] + 255 * s), Math.Min(255, col[2] + 255 * s), 255 };
  }

  public static void Write(string path, string shape) {
    int N = 64, SS = 4;
    Sdf f = Shape(shape);
    byte[] data = new byte[18 + N * N * 4];
    data[2] = 2; data[12] = (byte)N; data[14] = (byte)N; data[16] = 32; data[17] = 8;
    for (int row = 0; row < N; row++) for (int px = 0; px < N; px++) {
      double r = 0, g = 0, b = 0, a = 0;
      for (int sy = 0; sy < SS; sy++) for (int sx = 0; sx < SS; sx++) {
        double[] c = Shade(f, px + (sx + 0.5) / SS, row + (sy + 0.5) / SS);
        double ca = c[3] / 255;
        r += c[0] * ca; g += c[1] * ca; b += c[2] * ca; a += ca;
      }
      int n2 = SS * SS;
      double A = a / n2;
      double R = A > 0 ? r / a : 0, G = A > 0 ? g / a : 0, B = A > 0 ? b / a : 0;
      int o = 18 + ((N - 1 - row) * N + px) * 4;
      data[o] = (byte)Math.Round(B); data[o + 1] = (byte)Math.Round(G); data[o + 2] = (byte)Math.Round(R); data[o + 3] = (byte)Math.Round(A * 255);
    }
    File.WriteAllBytes(path, data);
  }
}
"@
Add-Type -TypeDefinition $src
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
$shapes = "diamond", "hex", "star", "drop", "flame", "blade", "rune", "crescent", "skull", "chevron", "heart", "shard"
foreach ($s in $shapes) { [ComboArt]::Write((Join-Path $OutDir "cp-$s.tga"), $s) }
"{0} combo point shapes written to {1}" -f $shapes.Count, $OutDir
