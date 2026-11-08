/* pfUI Octo sidebar icons: simple white line glyphs, drawn from distances
   (anti-aliased), written as 64x64 32-bit TGA (white, shape in alpha). */
#include <stdio.h>
#include <math.h>
#include <string.h>

#define N 64
static float A[N][N];
static float W = 4.6f; /* stroke width */

static float clamp01(float v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
static void put(int x, int y, float a) { if (a > A[y][x]) A[y][x] = a; }

static float segd(float px, float py, float ax, float ay, float bx, float by) {
  float vx = bx - ax, vy = by - ay, wx = px - ax, wy = py - ay;
  float t = (vx * wx + vy * wy) / (vx * vx + vy * vy + 1e-6f);
  t = t < 0 ? 0 : (t > 1 ? 1 : t);
  float dx = px - (ax + t * vx), dy = py - (ay + t * vy);
  return sqrtf(dx * dx + dy * dy);
}
static void line(float ax, float ay, float bx, float by) {
  for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
    float d = segd(x + .5f, y + .5f, ax, ay, bx, by);
    put(x, y, clamp01(W / 2 + .5f - d));
  }
}
/* ring of radius r; gap: skip angles within gap degrees of straight up */
static void ring(float cx, float cy, float r, float gap) {
  for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
    float dx = x + .5f - cx, dy = y + .5f - cy;
    float d = fabsf(sqrtf(dx * dx + dy * dy) - r);
    if (gap > 0) {
      float ang = atan2f(dx, -dy) * 57.2958f; /* 0 = up (y grows down) */
      if (fabsf(ang) < gap) continue;
    }
    put(x, y, clamp01(W / 2 + .5f - d));
  }
}
/* upper half of a ring (shoulders) */
static void halfring(float cx, float cy, float r) {
  for (int y = 0; y < N; y++) for (int x = 0; x < N; x++) {
    float dx = x + .5f - cx, dy = y + .5f - cy;
    if (dy > 0) continue;
    float d = fabsf(sqrtf(dx * dx + dy * dy) - r);
    put(x, y, clamp01(W / 2 + .5f - d));
  }
}

static void save(const char *name) {
  FILE *f = fopen(name, "wb");
  unsigned char h[18];
  memset(h, 0, 18);
  h[2] = 2; h[12] = N; h[14] = N; h[16] = 32; h[17] = 8; /* bottom-left origin, 8 alpha bits */
  fwrite(h, 1, 18, f);
  for (int y = N - 1; y >= 0; y--) for (int x = 0; x < N; x++) {
    unsigned char px[4] = { 255, 255, 255, (unsigned char)(A[y][x] * 255 + .5f) };
    fwrite(px, 1, 4, f);
  }
  fclose(f);
  memset(A, 0, sizeof(A));
}

int main(void) {
  /* move: a cross with four arrow heads */
  line(32, 9, 32, 55); line(9, 32, 55, 32);
  line(32, 9, 25, 16); line(32, 9, 39, 16);
  line(32, 55, 25, 48); line(32, 55, 39, 48);
  line(9, 32, 16, 25); line(9, 32, 16, 39);
  line(55, 32, 48, 25); line(55, 32, 48, 39);
  save("move.tga");
  /* key: a ring and a toothed blade */
  ring(20, 32, 9, 0);
  line(29, 32, 56, 32); line(47, 32, 47, 41); line(54, 32, 54, 39);
  save("key.tga");
  /* profiles: a head and shoulders */
  ring(32, 22, 9, 0);
  halfring(32, 54, 17);
  save("profile.tga");
  /* install: an arrow down into a tray */
  line(32, 8, 32, 40); line(32, 40, 22, 30); line(32, 40, 42, 30);
  line(11, 42, 11, 54); line(11, 54, 53, 54); line(53, 54, 53, 42);
  save("install.tga");
  /* settings: a gear */
  ring(32, 32, 13, 0); ring(32, 32, 5, 0);
  for (int i = 0; i < 8; i++) {
    float a = i * 3.14159f / 4;
    W = 8.5f; line(32 + cosf(a) * 14, 32 + sinf(a) * 14, 32 + cosf(a) * 19, 32 + sinf(a) * 19); W = 4.6f;
  }
  save("settings.tga");
  /* power: a ring open at the top and a bar */
  ring(32, 34, 17, 38);
  line(32, 8, 32, 30);
  save("power.tga");
  return 0;
}
