/* pfUI Octo transport map icons: a ship and a zeppelin, white shapes with a
   black outline (tinted in game), 64x64 32-bit TGA.
   Build: gcc -O1 -o mktransport.exe mktransport.c -lm ; run in img\transports */
#include <stdio.h>
#include <math.h>
#include <string.h>

#define N 64
static float M[N][N]; /* shape coverage */

static float clamp01(float v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
static void put(int x, int y, float a) { if (a > M[y][x]) M[y][x] = a; }

/* filled ellipse */
static void ellipse(float cx, float cy, float rx, float ry) {
  for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
    float dx = (x + .5f - cx) / rx, dy = (y + .5f - cy) / ry;
    float d = (sqrtf(dx * dx + dy * dy) - 1) * (rx < ry ? rx : ry);
    put(x, y, clamp01(.5f - d));
  }
}
/* filled convex polygon (points in order) */
static void poly(const float *p, int n) {
  for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
    float px = x + .5f, py = y + .5f, best = 1e9f; int inside = 1;
    for (int i = 0; i < n; i++) {
      float ax = p[2 * i], ay = p[2 * i + 1], bx = p[2 * ((i + 1) % n)], by = p[2 * ((i + 1) % n) + 1];
      float ex = bx - ax, ey = by - ay, len = sqrtf(ex * ex + ey * ey);
      float d = ((px - ax) * ey - (py - ay) * ex) / len; /* >0 = right of edge */
      if (d > 0) inside = 0;
      float ad = fabsf(d); if (ad < best) best = ad;
    }
    float s = inside ? best : -best;
    put(x, y, clamp01(.5f + s));
  }
}
static void rect(float x0, float y0, float x1, float y1) {
  float p[8] = { x0, y0, x1, y0, x1, y1, x0, y1 };
  poly(p, 4);
}

static void save(const char *name) {
  static float O[N][N];
  for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
    float m = 0;
    for (int j = -3; j <= 3; j++) for (int i = -3; i <= 3; i++) {
      int xx = x + i, yy = y + j;
      if (xx < 0 || yy < 0 || xx >= N || yy >= N) continue;
      float d = sqrtf((float)(i * i + j * j));
      float w = clamp01(3.2f - d);
      if (M[yy][xx] * w > m) m = M[yy][xx] * w;
    }
    O[y][x] = m;
  }
  FILE *f = fopen(name, "wb");
  unsigned char h[18];
  memset(h, 0, 18);
  h[2] = 2; h[12] = N; h[14] = N; h[16] = 32; h[17] = 8;
  fwrite(h, 1, 18, f);
  for (int y = N - 1; y >= 0; y--) for (int x = 0; x < N; x++) {
    float a = M[y][x], o = O[y][x];
    float alpha = a + (1 - a) * o;
    unsigned char c = (unsigned char)(alpha > 0 ? 255 * a / alpha + .5f : 0);
    unsigned char px[4] = { c, c, c, (unsigned char)(alpha * 255 + .5f) };
    fwrite(px, 1, 4, f);
  }
  fclose(f);
  memset(M, 0, sizeof(M));
}

int main(void) {
  /* ship: hull, mast, two sails, flag (y grows down) */
  { float hull[8] = { 8, 40, 56, 40, 48, 52, 16, 52 }; poly(hull, 4); }
  rect(30.5f, 8, 33.5f, 41);
  { float s1[6] = { 34, 12, 50, 36, 34, 36 }; poly(s1, 3); }
  { float s2[6] = { 30, 16, 30, 36, 16, 36 }; poly(s2, 3); }
  { float fl[6] = { 33, 8, 42, 11, 33, 14 }; poly(fl, 3); }
  save("ship.tga");
  /* zeppelin: balloon, fins, gondola */
  ellipse(30, 26, 22, 12);
  { float f1[6] = { 46, 22, 59, 13, 56, 26 }; poly(f1, 3); }
  { float f2[6] = { 46, 30, 56, 26, 59, 39 }; poly(f2, 3); }
  rect(24, 37, 27, 44); rect(35, 37, 38, 44);
  rect(20, 43, 42, 51);
  save("zeppelin.tga");
  /* tram: a car body (windows cut out below) on a rail with wheels */
  rect(10, 18, 54, 44);
  rect(6, 50, 58, 53);
  ellipse(20, 47, 4, 4); ellipse(44, 47, 4, 4);
  rect(28, 10, 36, 18);
  { /* windows: clear holes */
    for (int y = 22; y < 32; y++) for (int x = 14; x < 50; x++) {
      int cx = (x - 14) % 12;
      if (cx < 9) M[y][x] = 0;
    }
  }
  save("tram.tga");
  return 0;
}
