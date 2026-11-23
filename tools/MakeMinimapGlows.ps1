param([string]$OutDir = (Join-Path $PSScriptRoot "..\img\minimap\glow"))
# Makes the minimap glows of pfUI Octo's map styles (modules/minimap-style.lua, map.GLOWS):
#   <style>-<shape>.tga   a glow round the map's shape, white (tinted in game), alpha = strength
#   sweep-round.tga       a bright arc running round the round map (turned in game)
# (23 Nov 2026, Javelin: the game's glow pictures sat further from the map at the top right than at the
# bottom left - they are not centred.) These are worked out from the shape that masks the map
# (MakeMinimapMasks.ps1's Inside, the round map = a perfect circle): the shape's edge is traced with
# 4096 rays from the middle, every pixel gets its true distance to that edge, and each style is a
# curve of that distance - so the glow is the same all the way round, pixel for pixel.
# Units: the map's half-width = 1. A texture spans -F..F (F per style, the SAME numbers as map.GLOWS):
# drawn at map size * F, centred on the map, its edge lands exactly on the map's edge.
# Round and square 256 px, the other shapes 128 px. Uncompressed 32-bit TGA, bottom-left origin,
# white premultiplied (rgb = alpha) so it works in ADD and BLEND. Same output every run.
#   powershell -ExecutionPolicy Bypass -File tools\MakeMinimapGlows.ps1

$src = @"
using System;
using System.IO;
public static class Glows {
  public static bool Inside(string kind, double u, double v) {
    double au = Math.Abs(u), av = Math.Abs(v);
    switch (kind) {
      case "square":   return au <= 1 && av <= 1;
      case "round":    return u * u + v * v <= 1;
      case "rounded":  return Box(au, av, 0.22);
      case "rounder":  return Box(au, av, 0.45);
      case "squircle": return Math.Pow(au, 4) + Math.Pow(av, 4) <= 1;
      case "octagon":  return au <= 1 && av <= 1 && au + av <= 1.4142;
      case "diamond":  return au + av <= 1;
      case "corner-tl": return (u <= 0 && v >= 0) ? (au <= 1 && av <= 1) : u * u + v * v <= 1;
      case "corner-tr": return (u >= 0 && v >= 0) ? (au <= 1 && av <= 1) : u * u + v * v <= 1;
      case "corner-bl": return (u <= 0 && v <= 0) ? (au <= 1 && av <= 1) : u * u + v * v <= 1;
      case "corner-br": return (u >= 0 && v <= 0) ? (au <= 1 && av <= 1) : u * u + v * v <= 1;
    }
    return false;
  }
  static bool Box(double au, double av, double r) {
    double qx = au - (1 - r), qy = av - (1 - r);
    double ox = Math.Max(qx, 0), oy = Math.Max(qy, 0);
    return Math.Sqrt(ox * ox + oy * oy) + Math.Min(Math.Max(qx, qy), 0) - r <= 0;
  }

  const int RAYS = 4096;
  // the shape's edge: on each ray from the middle, where inside turns to outside (every shape here
  // is star-shaped round the middle)
  static double[] EdgeX, EdgeY;
  static void Trace(string kind) {
    EdgeX = new double[RAYS]; EdgeY = new double[RAYS];
    for (int k = 0; k < RAYS; k++) {
      double a = 2 * Math.PI * k / RAYS, cx = Math.Cos(a), cy = Math.Sin(a);
      double lo = 0, hi = 1.6;
      for (int it = 0; it < 40; it++) {
        double m = (lo + hi) / 2;
        if (Inside(kind, cx * m, cy * m)) lo = m; else hi = m;
      }
      double r = (lo + hi) / 2;
      EdgeX[k] = cx * r; EdgeY[k] = cy * r;
    }
  }
  // signed distance to the edge (minus = inside), map half-widths
  static double Dist(string kind, double u, double v) {
    double best = 1e9;
    for (int k = 0; k < RAYS; k++) {
      double dx = u - EdgeX[k], dy = v - EdgeY[k];
      double d = dx * dx + dy * dy;
      if (d < best) best = d;
    }
    best = Math.Sqrt(best);
    return Inside(kind, u, v) ? -best : best;
  }

  static double Clamp(double x) { return x < 0 ? 0 : (x > 1 ? 1 : x); }
  // falls from 1 at the edge to 0 at w, smoothly
  static double Fall(double d, double w, double pow) {
    if (d <= 0) return 1;
    if (d >= w) return 0;
    return Math.Pow(1 - d / w, pow);
  }
  static double Gauss(double x, double s) { return Math.Exp(-(x / s) * (x / s)); }
  // the glow meets the edge with no gap but does not reach over the map (2% of its half-width)
  static double Lip(double d) { return Clamp(1 + d / 0.02); }

  public static double Profile(string style, double d) {
    switch (style) {
      case "tight":  return d < 0 ? Lip(d) : Fall(d, 0.10, 2.0);
      case "soft":   return d < 0 ? Lip(d) : Fall(d, 0.21, 2.2);
      case "wide":   return d < 0 ? Lip(d) : Fall(d, 0.42, 2.6);
      case "neon": {
        double line = Gauss(d, 0.014);
        double outer = d > 0 ? 0.55 * Fall(d, 0.17, 2.0) : 0.3 * Clamp(1 + d / 0.05);
        return Clamp(line + outer);
      }
      case "halo":   return Clamp(Gauss(d - 0.075, 0.022) + (d > 0.075 ? 0.35 * Fall(d - 0.075, 0.2, 2.0) : 0));
      case "double": return Clamp(Gauss(d - 0.03, 0.011) + 0.75 * Gauss(d - 0.085, 0.011));
      case "inner":  return d > 0 ? Clamp(1 - d / 0.01) : Fall(-d, 0.17, 2.2);
      case "sweep":  return d < 0 ? Lip(d) : Fall(d, 0.21, 1.8);
    }
    return 0;
  }

  // the bright head of the sweep at the top, a tail trailing behind it (anticlockwise from the head)
  static double Arc(double u, double v) {
    double t = Math.Atan2(v, u);               // -pi..pi, top = pi/2
    double phi = t - Math.PI / 2;              // 0 at the head, growing anticlockwise
    while (phi < 0) phi += 2 * Math.PI;
    while (phi >= 2 * Math.PI) phi -= 2 * Math.PI;
    double head = Gauss(2 * Math.PI - phi, 0.18); // a soft front ahead of the head (about 10 degrees)
    double tail = Math.Exp(-phi / 0.9);
    return Clamp(Math.Max(head, tail) * 1.4);
  }

  public static void Write(string path, string kind, string style, double F, int N) {
    Trace(kind);
    using (var f = new BinaryWriter(File.Create(path))) {
      f.Write(new byte[] { 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0 });
      f.Write((ushort)N); f.Write((ushort)N);
      f.Write((byte)32); f.Write((byte)8);
      for (int y = 0; y < N; y++) {
        for (int x = 0; x < N; x++) {
          double u = ((x + 0.5) / N * 2 - 1) * F, v = ((y + 0.5) / N * 2 - 1) * F;
          double a = Profile(style, Dist(kind, u, v));
          if (style == "sweep") a *= Arc(u, v);
          // nothing on the outermost pixel: a turned or stretched texture never smears its edge
          if (x == 0 || y == 0 || x == N - 1 || y == N - 1) a = 0;
          byte b = (byte)Math.Round(Clamp(a) * 255);
          f.Write(b); f.Write(b); f.Write(b); f.Write(b);
        }
      }
    }
  }
}
"@
Add-Type -TypeDefinition $src

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force $OutDir | Out-Null }
$OutDir = (Resolve-Path $OutDir).Path
# style -> F (half-size of the texture in map half-widths): keep in step with map.GLOWS in minimap-style.lua
$styles = [ordered]@{ tight = 1.13; soft = 1.24; wide = 1.45; neon = 1.20; halo = 1.32; double = 1.12; inner = 1.04 }
$shapes = "round", "square", "rounded", "rounder", "squircle", "octagon", "diamond", "corner-tl", "corner-tr", "corner-bl", "corner-br"
foreach ($sh in $shapes) {
  $n = if ($sh -eq "round" -or $sh -eq "square") { 256 } else { 128 }
  foreach ($st in $styles.Keys) {
    [Glows]::Write((Join-Path $OutDir "$st-$sh.tga"), $sh, $st, $styles[$st], $n)
  }
}
[Glows]::Write((Join-Path $OutDir "sweep-round.tga"), "round", "sweep", 1.24, 256)
$all = Get-ChildItem $OutDir -Filter *.tga
"{0} textures, {1:N1} MB" -f $all.Count, (($all | Measure-Object Length -Sum).Sum / 1MB)
