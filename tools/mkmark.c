/* pfUI Octo watermark: our own octopus emblem in a ring, white line art,
   256x256 32-bit TGA (shape in alpha). Build: gcc -O2 -o mkmark mkmark.c -lm
   Writes octomark.tga in the current folder (copy to img\octo\icons). */
#include <stdio.h>
#include <math.h>
#include <string.h>

#define N 256
static float A[N][N];
static float W = 9.0f;

static float clamp01(float v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
static void put(int x, int y, float a) { if (x >= 0 && y >= 0 && x < N && y < N && a > A[y][x]) A[y][x] = a; }

static float segd(float px, float py, float ax, float ay, float bx, float by) {
  float vx = bx - ax, vy = by - ay, wx = px - ax, wy = py - ay;
  float t = (vx * wx + vy * wy) / (vx * vx + vy * vy + 1e-6f);
  t = t < 0 ? 0 : (t > 1 ? 1 : t);
  float dx = px - (ax + t * vx), dy = py - (ay + t * vy);
  return sqrtf(dx * dx + dy * dy);
}
/* a stroke along a segment; only the pixels near it are visited */
static void line(float ax, float ay, float bx, float by, float w) {
  int x0 = (int)fminf(ax, bx) - (int)w - 2, x1 = (int)fmaxf(ax, bx) + (int)w + 2;
  int y0 = (int)fminf(ay, by) - (int)w - 2, y1 = (int)fmaxf(ay, by) + (int)w + 2;
  for (int y = y0; y <= y1; y++) for (int x = x0; x <= x1; x++) {
    float d = segd(x + .5f, y + .5f, ax, ay, bx, by);
    put(x, y, clamp01(w / 2 + .5f - d));
  }
}
static void ring(float cx, float cy, float rx, float ry, float a0, float a1, float w) {
  float prevx = 0, prevy = 0;
  for (int i = 0; i <= 240; i++) {
    float a = a0 + (a1 - a0) * i / 240.0f;
    float x = cx + cosf(a) * rx, y = cy + sinf(a) * ry;
    if (i > 0) line(prevx, prevy, x, y, w);
    prevx = x; prevy = y;
  }
}
static void dot(float cx, float cy, float r) {
  for (int y = (int)(cy - r - 2); y <= (int)(cy + r + 2); y++)
    for (int x = (int)(cx - r - 2); x <= (int)(cx + r + 2); x++) {
      float dx = x + .5f - cx, dy = y + .5f - cy;
      put(x, y, clamp01(r + .5f - sqrtf(dx * dx + dy * dy)));
    }
}
/* a tentacle: from (x, y) downward, waving, ending in a curl to side s */
static void tentacle(float x, float y, float dir, float len, float s) {
  float px = x, py = y;
  int steps = 60;
  for (int i = 1; i <= steps; i++) {
    float t = (float)i / steps;
    float nx = x + dir * len * .55f * t + sinf(t * 5.2f) * 9 * s;
    float ny = y + len * t;
    float w = W * (1.0f - .55f * t);
    line(px, py, nx, ny, w);
    px = nx; py = ny;
  }
  /* the curl */
  float r = 9;
  for (int i = 1; i <= 30; i++) {
    float a0 = (i - 1) / 30.0f * 4.4f, a1 = i / 30.0f * 4.4f;
    float r0 = r * (1 - (i - 1) / 40.0f), r1 = r * (1 - i / 40.0f);
    float cx = px + s * r, cy = py;
    line(cx - s * cosf(a0) * r0, cy + sinf(a0) * r0 * -1, cx - s * cosf(a1) * r1, cy + sinf(a1) * r1 * -1, W * .45f);
  }
}

int main(void) {
  /* the ring round it */
  ring(128, 128, 118, 118, 0, 6.2832f, 7);
  /* head: a dome */
  ring(128, 104, 50, 56, 3.1416f * .95f, 3.1416f * 2.05f, W);
  line(78, 106, 82, 132, W); line(178, 106, 174, 132, W);
  /* eyes */
  dot(110, 108, 8); dot(146, 108, 8);
  /* eight arms: four each side, fanning out */
  float xs[8] = { 84, 98, 112, 124, 132, 144, 158, 172 };
  float dirs[8] = { -1.3f, -.85f, -.4f, -.1f, .1f, .4f, .85f, 1.3f };
  float lens[8] = { 52, 64, 72, 76, 76, 72, 64, 52 };
  for (int i = 0; i < 8; i++) tentacle(xs[i], 134, dirs[i], lens[i], i < 4 ? -1.0f : 1.0f);
  FILE *f = fopen("octomark.tga", "wb");
  unsigned char h[18];
  memset(h, 0, 18);
  h[2] = 2; h[12] = N & 255; h[13] = N >> 8; h[14] = N & 255; h[15] = N >> 8; h[16] = 32; h[17] = 8;
  fwrite(h, 1, 18, f);
  for (int y = N - 1; y >= 0; y--) for (int x = 0; x < N; x++) {
    unsigned char px[4] = { 255, 255, 255, (unsigned char)(A[y][x] * 255 + .5f) };
    fwrite(px, 1, 4, f);
  }
  fclose(f);
  return 0;
}
