param([string]$OutDir = (Join-Path $PSScriptRoot "..\img\honor"))
# Makes the battle-worn art of pfUI Octo's honor page (modules/honor.lua; 23 Nov 2026, user: "make it look amazing
# like PvP ... battle and worn"). All our own, drawn from seeded noise, so the same every run:
#   grime.tga    256 x 256  dark stains, chips and speckles (BLEND over the page)
#   scratch.tga  256 x 256  thin light scratches (ADD, faint)
#   burn.tga     256 x 256  burnt, ragged edges round a panel (BLEND)
#   bar.tga      256 x 32   worn metal for the progress bars (white, tinted in game)
#   tick.tga     16 x 64    a glowing tick with a bright tip (the 25 / 50 / 75 marks)
#   spark.tga    32 x 32    a soft glow for the end of a filling bar
# Uncompressed 32-bit TGA, bottom-left origin.
#   powershell -ExecutionPolicy Bypass -File tools\MakeHonorArt.ps1

$src = @"
using System;
using System.IO;
public static class HonorArt {
  static double Hash(int x, int y, int s) {
    unchecked {
      uint h = (uint)(x * 374761393 + y * 668265263 + s * 1442695041);
      h = (h ^ (h >> 13)) * 1274126177u;
      h ^= h >> 16;
      return (h & 0xFFFFFF) / (double)0xFFFFFF;
    }
  }
  static double Smooth(double t) { return t * t * (3 - 2 * t); }
  // value noise, tiling every `per` cells
  static double Noise(double x, double y, int s, int per) {
    int x0 = (int)Math.Floor(x), y0 = (int)Math.Floor(y);
    double fx = Smooth(x - x0), fy = Smooth(y - y0);
    int ax = ((x0 % per) + per) % per, ay = ((y0 % per) + per) % per;
    int bx = (ax + 1) % per, by = (ay + 1) % per;
    double a = Hash(ax, ay, s), b = Hash(bx, ay, s), c = Hash(ax, by, s), d = Hash(bx, by, s);
    return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
  }
  static double Fbm(double u, double v, int s, int oct) {
    double sum = 0, amp = 0.5, tot = 0; int per = 4;
    for (int o = 0; o < oct; o++) {
      sum += amp * Noise(u * per, v * per, s + o * 17, per);
      tot += amp; amp *= 0.5; per *= 2;
    }
    return sum / tot;
  }
  static double Clamp(double x) { return x < 0 ? 0 : (x > 1 ? 1 : x); }

  static void Save(string path, int w, int h, Func<int, int, double[]> px) {
    using (var f = new BinaryWriter(File.Create(path))) {
      f.Write(new byte[] { 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
      f.Write((ushort)w); f.Write((ushort)h);
      f.Write((byte)32); f.Write((byte)8);
      for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
        double[] c = px(x, y); // r g b a, 0..1
        f.Write((byte)Math.Round(Clamp(c[2]) * 255)); f.Write((byte)Math.Round(Clamp(c[1]) * 255));
        f.Write((byte)Math.Round(Clamp(c[0]) * 255)); f.Write((byte)Math.Round(Clamp(c[3]) * 255));
      }
    }
  }

  // lines drawn into an alpha buffer: scratches
  static double[,] Scratches(int n, int count, int seed, double strength) {
    var buf = new double[n, n];
    for (int i = 0; i < count; i++) {
      double x = Hash(i, 1, seed) * n, y = Hash(i, 2, seed) * n;
      double ang = -0.6 + Hash(i, 3, seed) * 0.5 + (Hash(i, 7, seed) < 0.3 ? 1.6 : 0);
      double len = 12 + Hash(i, 4, seed) * 70, wob = Hash(i, 5, seed) * 0.02;
      double a = strength * (0.35 + 0.65 * Hash(i, 6, seed));
      for (double t = 0; t < len; t += 0.5) {
        double px = x + Math.Cos(ang + wob * t) * t, py = y + Math.Sin(ang + wob * t) * t;
        // fades in and out along its length
        double k = Math.Sin(Math.PI * t / len);
        int ix = ((int)px % n + n) % n, iy = ((int)py % n + n) % n;
        buf[ix, iy] = Math.Max(buf[ix, iy], a * k);
      }
    }
    return buf;
  }

  public static void Make(string dir) {
    int N = 256;
    // grime: stains (big noise), chips (thresholded fine noise), speckles
    Save(Path.Combine(dir, "grime.tga"), N, N, (x, y) => {
      double u = x / (double)N, v = y / (double)N;
      double big = Fbm(u, v, 11, 5);
      double stain = Clamp((big - 0.48) * 3.2) * 0.55;
      double chip = Fbm(u * 2, v * 2, 29, 4);
      double chips = chip > 0.66 ? Clamp((chip - 0.66) * 9) * 0.5 : 0;
      double speck = Hash(x, y, 5) > 0.985 ? 0.35 + Hash(x, y, 6) * 0.3 : 0;
      double a = Clamp(stain + chips + speck);
      return new double[] { 0.07, 0.045, 0.03, a };
    });
    // light scratches (ADD)
    var sc = Scratches(N, 70, 41, 1.0);
    Save(Path.Combine(dir, "scratch.tga"), N, N, (x, y) => {
      double a = sc[x, y];
      return new double[] { 0.95, 0.88, 0.75, a };
    });
    // burnt edges: dark towards the border, the edge line torn by noise
    Save(Path.Combine(dir, "burn.tga"), N, N, (x, y) => {
      double u = (x + 0.5) / N, v = (y + 0.5) / N;
      double d = Math.Min(Math.Min(u, v), Math.Min(1 - u, 1 - v));
      double rag = (Fbm(u, v, 77, 5) - 0.5) * 0.09;
      double a = Clamp((0.17 - d + rag) / 0.17);
      a = Math.Pow(a, 1.6) * 0.95;
      // a faint ember brown just inside the burn
      double ember = Clamp(1 - Math.Abs(a - 0.35) / 0.2) * 0.25;
      return new double[] { 0.05 + ember * 0.4, 0.03 + ember * 0.12, 0.02, a };
    });
    // worn metal bar: brushed, bevelled, chipped
    Save(Path.Combine(dir, "bar.tga"), 256, 32, (x, y) => {
      double u = x / 256.0, v = y / 32.0;
      double brushed = Fbm(u * 0.5, v * 8, 3, 4);
      double l = 0.62 + (brushed - 0.5) * 0.35;
      // bevel: light top edge, dark bottom edge (v up)
      if (v > 0.82) l += (v - 0.82) / 0.18 * 0.35;
      if (v < 0.2) l -= (0.2 - v) / 0.2 * 0.35;
      // chips and wear
      double chip = Fbm(u * 3, v * 0.6, 13, 4);
      if (chip > 0.64) l -= Clamp((chip - 0.64) * 6) * 0.3;
      if (Hash(x, y, 9) > 0.99) l += 0.25;
      l = Clamp(l);
      return new double[] { l, l, l, 1 };
    });
    // tick: a thin glowing line, brightest at its top
    Save(Path.Combine(dir, "tick.tga"), 16, 64, (x, y) => {
      double dx = x + 0.5 - 8;
      double v = (y + 0.5) / 64.0;
      double core = Math.Exp(-(dx * dx) / (2 * 0.8 * 0.8));
      double glow = Math.Exp(-(dx * dx) / (2 * 3.0 * 3.0)) * 0.35;
      double along = 0.45 + 0.55 * Math.Pow(v, 1.5);
      double tip = Math.Exp(-Math.Pow((v - 0.9) / 0.1, 2)) * Math.Exp(-(dx * dx) / (2 * 2.2 * 2.2)) * 0.9;
      double a = Clamp((core + glow) * along + tip);
      return new double[] { 1, 1, 1, a };
    });
    // spark: a soft round glow
    Save(Path.Combine(dir, "spark.tga"), 32, 32, (x, y) => {
      double dx = x + 0.5 - 16, dy = y + 0.5 - 16;
      double r = Math.Sqrt(dx * dx + dy * dy) / 16;
      double a = Clamp(Math.Pow(Clamp(1 - r), 2.2));
      return new double[] { 1, 1, 1, a };
    });
  }
}
"@
Add-Type -TypeDefinition $src
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
[HonorArt]::Make($OutDir)
Get-ChildItem $OutDir -Filter *.tga | ForEach-Object { "{0,-12} {1,7} bytes" -f $_.Name, $_.Length }
