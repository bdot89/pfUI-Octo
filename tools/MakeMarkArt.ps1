param([string]$Root = (Join-Path $PSScriptRoot ".."))
# Draws pfUI Octo's raid mark sets (img\marks) and elite crest styles (img\elite)
# (modules/art.lua, "Art" page). Our own drawings: every shape is a signed distance
# field, lit like a bevelled metal / gel button (normal from the height of the bevel,
# a light from the top left, a highlight, a dark outline and a drop shadow).
#   marks\gloss  flat  neon   256 x 256, the 4 x 4 sheet of the game's raid marks
#                             (star, circle, diamond, triangle, moon, square, cross, skull)
#   elite\<style>-<elite|rare|boss>   64 x 32 crests; styles wings, star, shield, skull, crown
# Uncompressed 32-bit TGA, bottom-left origin, 4 x 4 samples per pixel. Same output every run.
#   powershell -ExecutionPolicy Bypass -File tools\MakeMarkArt.ps1

$src = @'
using System;
using System.IO;
using System.Collections.Generic;
public delegate double Sdf(double x, double y);
public static class MarkArt {
  // ---------------------------------------------------------------- shapes
  static double Circ(double x, double y, double cx, double cy, double r) {
    return Math.Sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy)) - r;
  }
  static double Poly(double[] p, double x, double y) {
    double best = 1e9; bool inside = false;
    int n = p.Length / 2;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      double xi = p[2 * i], yi = p[2 * i + 1], xj = p[2 * j], yj = p[2 * j + 1];
      double vx = xi - xj, vy = yi - yj, wx = x - xj, wy = y - yj;
      double t = (vx * wx + vy * wy) / (vx * vx + vy * vy);
      t = Math.Max(0, Math.Min(1, t));
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
    double a = deg * Math.PI / 180, c = Math.Cos(a), s = Math.Sin(a);
    double dx = x - cx, dy = y - cy;
    return Box(cx + dx * c + dy * s, cy - dx * s + dy * c, cx, cy, hw, hh, r);
  }
  static double Un(double a, double b) { return Math.Min(a, b); }
  static double Df(double a, double b) { return Math.Max(a, -b); }
  static double[] StarPts(double cx, double cy, double R, double k) {
    double[] p = new double[20];
    for (int i = 0; i < 10; i++) {
      double a = -Math.PI / 2 + i * Math.PI / 5, r = (i % 2 == 0) ? R : R * k;
      p[2 * i] = cx + r * Math.Cos(a); p[2 * i + 1] = cy + r * Math.Sin(a);
    }
    return p;
  }
  static double[] Mirror(double[] p, double w) {
    double[] q = new double[p.Length];
    for (int i = 0; i < p.Length / 2; i++) { q[2 * i] = w - p[2 * i]; q[2 * i + 1] = p[2 * i + 1]; }
    return q;
  }

  // raid marks, 64 x 64 cells
  static Sdf Mark(int i) {
    switch (i) {
      case 0: { double[] s = StarPts(32, 34, 29, 0.42); return (x, y) => Poly(s, x, y) - 0; }
      case 1: return (x, y) => Circ(x, y, 32, 32, 24);
      case 2: { double[] d = { 32, 4, 58, 32, 32, 60, 6, 32 }; return (x, y) => Poly(d, x, y); }
      case 3: { double[] t = { 32, 5, 59, 55, 5, 55 }; return (x, y) => Poly(t, x, y); }
      case 4: return (x, y) => Df(Circ(x, y, 29, 32, 24), Circ(x, y, 42, 26, 19));
      case 5: return (x, y) => Box(x, y, 32, 32, 24, 24, 4);
      case 6: return (x, y) => Un(RotBox(x, y, 32, 32, 27, 6.5, 3, 45), RotBox(x, y, 32, 32, 27, 6.5, 3, -45));
      default: {
        double[] nose = { 32, 35, 28.5, 42, 35.5, 42 };
        return (x, y) => Df(Df(Df(Un(Circ(x, y, 32, 27, 20), Box(x, y, 32, 47, 11, 9, 3)), Circ(x, y, 24.5, 28, 5.2)),
          Circ(x, y, 39.5, 28, 5.2)), Poly(nose, x, y));
      }
    }
  }
  // elite crests, 64 x 32
  static Sdf Crest(string style) {
    switch (style) {
      case "wings": {
        double[] f1 = { 27, 13, 1, 4, 8, 11, 27, 17 };
        double[] f2 = { 27, 16, 0, 14, 8, 19, 27, 20 };
        double[] f3 = { 27, 19, 3, 24, 11, 25, 27, 23 };
        double[] g = { 32, 3, 40, 16, 32, 29, 24, 16 };
        double[] r1 = Mirror(f1, 64), r2 = Mirror(f2, 64), r3 = Mirror(f3, 64);
        return (x, y) => Un(Un(Un(Poly(f1, x, y), Poly(f2, x, y)), Un(Poly(f3, x, y), Poly(r1, x, y))),
          Un(Un(Poly(r2, x, y), Poly(r3, x, y)), Poly(g, x, y)));
      }
      case "star": { double[] s = StarPts(32, 17, 15.5, 0.42); return (x, y) => Poly(s, x, y); }
      case "shield": {
        double[] sh = { 19, 3, 45, 3, 45, 14, 32, 29.5, 19, 14 };
        double[] em = StarPts(32, 13.5, 6.2, 0.45);
        return (x, y) => Df(Poly(sh, x, y), Poly(em, x, y));
      }
      case "skull": {
        double[] nose = { 32, 15, 30, 19.5, 34, 19.5 };
        return (x, y) => Df(Df(Df(Un(Circ(x, y, 32, 13, 11.5), Box(x, y, 32, 24, 7, 5, 2)), Circ(x, y, 27.6, 13, 3.3)),
          Circ(x, y, 36.4, 13, 3.3)), Poly(nose, x, y));
      }
      default: { // crown
        double[] c = { 13, 22, 11, 7, 22, 15, 32, 3, 42, 15, 53, 7, 51, 22 };
        return (x, y) => Un(Poly(c, x, y), Box(x, y, 32, 25, 20, 4, 1.5));
      }
    }
  }

  // ---------------------------------------------------------------- colours
  // a three stop ramp: dark, middle, light
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
  static string[] MarkColors = { "yellow", "orange", "purple", "green", "ice", "blue", "red", "bone" };
  static double[] Pick(double[][] r, double t) {
    t = Math.Max(0, Math.Min(1, t));
    double[] a = t < 0.5 ? r[0] : r[1], b = t < 0.5 ? r[1] : r[2];
    double u = t < 0.5 ? t * 2 : (t - 0.5) * 2;
    return new double[] { a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u };
  }

  // ---------------------------------------------------------------- lighting
  // returns r, g, b, a (0 - 255, straight alpha) at one point
  static double[] Shade(Sdf f, double[][] ramp, string mode, double x, double y, double bevel, double outline, double shadow) {
    double d = f(x, y);
    if (mode == "neon") {
      double[] c = ramp[2];
      if (d <= 0) {
        double ring = d > -1.7 ? 1.0 : 0.20;
        double[] inner = ramp[1];
        return ring > 0.5 ? new double[] { c[0], c[1], c[2], 255 } : new double[] { inner[0], inner[1], inner[2], 56 };
      }
      double g = 0.6 * Math.Exp(-d / 2.4);
      return new double[] { ramp[1][0], ramp[1][1], ramp[1][2], 255 * g };
    }
    if (d > 0) {
      double sd = f(x - 1.0, y - 1.5);
      if (sd <= 0 && shadow > 0) return new double[] { 0, 0, 0, 255 * shadow };
      return new double[] { 0, 0, 0, 0 };
    }
    double[] dark = ramp[0];
    if (d > -outline) return new double[] { dark[0] * 0.35, dark[1] * 0.35, dark[2] * 0.35, 255 };
    if (mode == "flat") {
      double[] m = ramp[1];
      return new double[] { m[0], m[1], m[2], 255 };
    }
    // bevelled: height from the distance to the edge
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
    double[] col = Pick(ramp, 0.12 + diff * 0.95);
    double s = spec * 0.85;
    return new double[] { Math.Min(255, col[0] + 255 * s), Math.Min(255, col[1] + 255 * s), Math.Min(255, col[2] + 255 * s), 255 };
  }
  static double Height(Sdf f, double x, double y, double bevel, double outline) {
    double d = f(x, y);
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
  // draws one shape into a cell at (ox, oy), averaging 4 x 4 samples (premultiplied)
  static void Cell(byte[] data, int W, int H, int ox, int oy, int cw, int ch, Sdf f, double[][] ramp, string mode,
                   double bevel, double outline, double shadow) {
    int SS = 4;
    for (int py = 0; py < ch; py++) for (int px = 0; px < cw; px++) {
      double r = 0, g = 0, b = 0, a = 0;
      for (int sy = 0; sy < SS; sy++) for (int sx = 0; sx < SS; sx++) {
        double x = px + (sx + 0.5) / SS, y = py + (sy + 0.5) / SS;
        double[] c = Shade(f, ramp, mode, x, y, bevel, outline, shadow);
        double al = c[3] / 255;
        r += c[0] * al; g += c[1] * al; b += c[2] * al; a += al;
      }
      double n = SS * SS;
      double[] o = a > 0 ? new double[] { r / a, g / a, b / a, 255 * a / n } : new double[] { 0, 0, 0, 0 };
      Put(data, W, H, ox + px, oy + py, o);
    }
  }
  public static void Marks(string path, string mode) {
    byte[] data = Tga(256, 256);
    for (int i = 0; i < 8; i++) {
      Cell(data, 256, 256, (i % 4) * 64, (i / 4) * 64, 64, 64, Mark(i), Ramp(MarkColors[i]), mode,
           mode == "gloss" ? 6.5 : 3, mode == "neon" ? 1 : (mode == "flat" ? 1.6 : 1.3), mode == "neon" ? 0 : 0.5);
    }
    File.WriteAllBytes(path, data);
  }
  public static void Elite(string path, string style, string kind) {
    byte[] data = Tga(64, 32);
    string col = kind == "elite" ? "gold" : (kind == "rare" ? "silver" : (kind == "metal" ? "chrome" : "red"));
    Cell(data, 64, 32, 0, 0, 64, 32, Crest(style), Ramp(col), "gloss", 3.2, 0.9, 0.5);
    File.WriteAllBytes(path, data);
  }
}
'@
Add-Type -TypeDefinition $src
$marks = Join-Path $Root "img\marks"
$elite = Join-Path $Root "img\elite"
New-Item -ItemType Directory -Force $marks | Out-Null
New-Item -ItemType Directory -Force $elite | Out-Null
foreach ($m in "gloss", "flat", "neon") { [MarkArt]::Marks((Join-Path $marks ($m + ".tga")), $m) }
foreach ($s in "wings", "star", "shield", "skull", "crown") {
  foreach ($k in "elite", "rare", "boss") { [MarkArt]::Elite((Join-Path $elite ("$s-$k.tga")), $s, $k) }
}
Get-ChildItem $marks, $elite -Filter *.tga | ForEach-Object { "{0,-18} {1,7} bytes" -f $_.Name, $_.Length }
# neutral chrome crests for the nameplates: tinted by the elite / rare / boss colours in game
$plates = Join-Path $Root "img\plates"
foreach ($s in "wings", "star", "shield", "skull", "crown") { [MarkArt]::Elite((Join-Path $plates ("crest-$s.tga")), $s, "metal") }
