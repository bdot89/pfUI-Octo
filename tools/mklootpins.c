/* pfUI Octo OctoLoot world map pins (26 Nov 2026): a doorway (dungeon), a skull (raid) and a horned skull (world
   boss), white shapes with a black outline (tinted in game), 64x64 32-bit TGA - drawn on img\transports' badge + ring.
   Build: gcc -O1 -o mklootpins.exe mklootpins.c -lm ; run in img\octoloot */
#include <stdio.h>
#include <math.h>
#include <string.h>

#define N 64
static float M[N][N];

static float clamp01(float v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
static void put(int x, int y, float a) { if (a > M[y][x]) M[y][x] = a; }
static void cut(int x, int y, float a) { M[y][x] *= (1 - a); }

static void ellipse(float cx, float cy, float rx, float ry, int hole) {
  for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
    float dx = (x + .5f - cx) / rx, dy = (y + .5f - cy) / ry;
    float d = (sqrtf(dx * dx + dy * dy) - 1) * (rx < ry ? rx : ry);
    float a = clamp01(.5f - d);
    if (hole) cut(x, y, a); else put(x, y, a);
  }
}
static void poly(const float *p, int n, int hole) {
  for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
    float px = x + .5f, py = y + .5f, best = 1e9f, out = -1e9f; int inside = 1;
    for (int i = 0; i < n; i++) {
      float ax = p[2 * i], ay = p[2 * i + 1], bx = p[2 * ((i + 1) % n)], by = p[2 * ((i + 1) % n) + 1];
      float ex = bx - ax, ey = by - ay, len = sqrtf(ex * ex + ey * ey);
      float d = ((px - ax) * ey - (py - ay) * ex) / len;
      if (d > 0) inside = 0;
      if (d > out) out = d;
      float ad = fabsf(d); if (ad < best) best = ad;
    }
    /* outside: the farthest half-plane, not the nearest edge LINE (that leaked streaks along the edges' extensions) */
    float a = clamp01(.5f + (inside ? best : -out));
    if (hole) cut(x, y, a); else put(x, y, a);
  }
}
static void rect(float x0, float y0, float x1, float y1, int hole) {
  float p[8] = { x0, y0, x1, y0, x1, y1, x0, y1 };
  poly(p, 4, hole);
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

static void skull(void) {
  ellipse(32, 27, 17, 16, 0);          /* head */
  rect(22, 34, 42, 48, 0);             /* jaw */
  ellipse(25, 29, 5, 5.5f, 1);         /* eyes */
  ellipse(39, 29, 5, 5.5f, 1);
  { float n[6] = { 32, 34, 29, 40, 35, 40 }; poly(n, 3, 1); } /* nose */
  rect(26.5f, 44, 28.5f, 48, 1);       /* teeth */
  rect(31, 44, 33, 48, 1);
  rect(35.5f, 44, 37.5f, 48, 1);
}

int main(void) {
  /* dungeon: a stone doorway - an arch with its dark door, two steps */
  ellipse(32, 26, 18, 16, 0);
  rect(14, 26, 50, 50, 0);
  ellipse(32, 28, 10, 10, 1);
  rect(22, 28, 42, 50, 1);
  rect(10, 50, 54, 55, 0);
  rect(31, 18, 33, 24, 0);             /* keystone */
  save("dungeon.tga");
  /* raid: a skull */
  skull();
  save("raid.tga");
  /* world boss: a horned skull */
  skull();
  { float h1[6] = { 16, 24, 11, 9, 23, 15 }; poly(h1, 3, 0); }
  { float h2[6] = { 48, 24, 41, 15, 53, 9 }; poly(h2, 3, 0); }
  save("worldboss.tga");
  return 0;
}
