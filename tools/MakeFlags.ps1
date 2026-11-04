param([string]$OutDir = (Join-Path $PSScriptRoot "..\img\flags"))
# Draws the language flags of the options window's title row (modules/octo-options.lua,
# O.Flags): our own simple drawings of eight national flags, 64 x 64 uncompressed 32-bit
# TGA with the flag in the top 64 x 40 (the rest clear), 4 x 4 samples per pixel.
#   enUS (United Kingdom)  deDE  frFR  esES  ruRU  koKR  zhCN  zhTW
#   powershell -ExecutionPolicy Bypass -File tools\MakeFlags.ps1

$src = @"
using System;
using System.IO;
public static class Flag {
  static bool Poly(double[] p, double x, double y) {
    bool c = false;
    int n = p.Length / 2;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      double xi = p[2 * i], yi = p[2 * i + 1], xj = p[2 * j], yj = p[2 * j + 1];
      if (((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)) c = !c;
    }
    return c;
  }
  static bool Circle(double x, double y, double cx, double cy, double r) {
    return (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r;
  }
  static bool InStar(double x, double y, double cx, double cy, double R) {
    double[] p = new double[20];
    for (int i = 0; i < 10; i++) {
      double a = -Math.PI / 2 + i * Math.PI / 5;
      double r = (i % 2 == 0) ? R : R * 0.382;
      p[2 * i] = cx + r * Math.Cos(a);
      p[2 * i + 1] = cy + r * Math.Sin(a);
    }
    return Poly(p, x, y);
  }
  static int[] C(int r, int g, int b) { return new int[] { r, g, b }; }
  // colour of the flag at (x, y) in a 64 x 40 field
  static int[] At(string f, double x, double y) {
    double L = Math.Sqrt(64.0 * 64.0 + 40.0 * 40.0);
    switch (f) {
      case "enUS": {
        int[] col = C(1, 33, 105);
        double d1 = Math.Abs((x - 32) * 40 - (y - 20) * 64) / L;
        double d2 = Math.Abs((x - 32) * 40 + (y - 20) * 64) / L;
        if (d1 < 5.5 || d2 < 5.5) col = C(255, 255, 255);
        if (d1 < 2 || d2 < 2) col = C(200, 16, 46);
        if (Math.Abs(x - 32) < 6.5 || Math.Abs(y - 20) < 6.5) col = C(255, 255, 255);
        if (Math.Abs(x - 32) < 3.8 || Math.Abs(y - 20) < 3.8) col = C(200, 16, 46);
        return col;
      }
      case "deDE":
        if (y < 40.0 / 3) return C(20, 20, 20);
        if (y < 80.0 / 3) return C(221, 0, 0);
        return C(255, 206, 0);
      case "frFR":
        if (x < 64.0 / 3) return C(0, 85, 164);
        if (x < 128.0 / 3) return C(255, 255, 255);
        return C(239, 65, 53);
      case "esES":
        if (y < 10 || y >= 30) return C(170, 21, 27);
        return C(241, 191, 0);
      case "ruRU":
        if (y < 40.0 / 3) return C(255, 255, 255);
        if (y < 80.0 / 3) return C(0, 57, 166);
        return C(213, 43, 30);
      case "koKR": {
        int[] col = C(255, 255, 255);
        if (Circle(x, y, 32, 20, 10)) {
          if (Circle(x, y, 27, 20, 5)) col = C(205, 46, 58);
          else if (Circle(x, y, 37, 20, 5)) col = C(0, 71, 160);
          else if (y < 20) col = C(205, 46, 58);
          else col = C(0, 71, 160);
        }
        double[,] k = { { 9, 7, 1, 1 }, { 55, 7, -1, 1 }, { 9, 33, 1, -1 }, { 55, 33, -1, -1 } };
        for (int i = 0; i < 4; i++) {
          double dx = k[i, 2] / Math.Sqrt(2), dy = k[i, 3] / Math.Sqrt(2);
          double t = (x - k[i, 0]) * dx + (y - k[i, 1]) * dy;
          double s = -(x - k[i, 0]) * dy + (y - k[i, 1]) * dx;
          if (Math.Abs(s) < 6 && (Math.Abs(t + 3.4) < 1.0 || Math.Abs(t) < 1.0 || Math.Abs(t - 3.4) < 1.0)) col = C(0, 0, 0);
        }
        return col;
      }
      case "zhCN": {
        int[] col = C(222, 41, 16);
        if (InStar(x, y, 11, 12, 7.5) || InStar(x, y, 23, 4.5, 2.4) || InStar(x, y, 27.5, 9.5, 2.4)
            || InStar(x, y, 27.5, 15.5, 2.4) || InStar(x, y, 23, 20.5, 2.4)) col = C(255, 222, 0);
        return col;
      }
      case "zhTW": {
        int[] col = C(254, 0, 0);
        if (x < 32 && y < 20) {
          col = C(0, 0, 149);
          if (Circle(x, y, 16, 10, 6.6)) col = C(255, 255, 255);
          if (Circle(x, y, 16, 10, 5.0)) col = C(0, 0, 149);
          if (Circle(x, y, 16, 10, 3.8)) col = C(255, 255, 255);
        }
        return col;
      }
    }
    return C(128, 128, 128);
  }
  public static void Write(string path, string f) {
    int W = 64, H = 64, FH = 40, SS = 4;
    byte[] data = new byte[18 + W * H * 4];
    data[2] = 2;
    data[12] = (byte)(W & 255); data[13] = (byte)(W >> 8);
    data[14] = (byte)(H & 255); data[15] = (byte)(H >> 8);
    data[16] = 32; data[17] = 8;
    for (int row = 0; row < H; row++) {           // row 0 = top of the picture
      for (int px = 0; px < W; px++) {
        double r = 0, g = 0, b = 0, a = 0;
        if (row < FH) {
          for (int sy = 0; sy < SS; sy++) for (int sx = 0; sx < SS; sx++) {
            double x = px + (sx + 0.5) / SS, y = row + (sy + 0.5) / SS;
            int[] c = At(f, x, y);
            if (x < 1.2 || y < 1.2 || x > W - 1.2 || y > FH - 1.2) c = C(15, 15, 15);
            r += c[0]; g += c[1]; b += c[2]; a += 255;
          }
          double n = SS * SS;
          r /= n; g /= n; b /= n; a /= n;
        }
        int o = 18 + ((H - 1 - row) * W + px) * 4;   // bottom-left origin
        data[o] = (byte)Math.Round(b); data[o + 1] = (byte)Math.Round(g);
        data[o + 2] = (byte)Math.Round(r); data[o + 3] = (byte)Math.Round(a);
      }
    }
    File.WriteAllBytes(path, data);
  }
}
"@
Add-Type -TypeDefinition $src
New-Item -ItemType Directory -Force $OutDir | Out-Null
foreach ($f in "enUS", "deDE", "frFR", "esES", "ruRU", "koKR", "zhCN", "zhTW") {
  [Flag]::Write((Join-Path $OutDir ($f + ".tga")), $f)
}
Get-ChildItem $OutDir -Filter *.tga | ForEach-Object { "{0,-12} {1,7} bytes" -f $_.Name, $_.Length }
