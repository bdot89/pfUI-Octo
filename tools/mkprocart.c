/* pfUI Octo :: OctoProcs art (20 Nov 2026). Our own glow shapes, drawn by maths (nothing taken from ProcDoc):
 * white light on a clear ground, tinted in the game (SetVertexColor) and drawn with ADD blending.
 *   wing.tga  128x256  a feathered crescent wing (the left one; the right one is it mirrored)
 *   crown.tga 256x128  an arc with rays, over the character
 *   beam.tga   64x256  a soft pillar of light
 *   ring.tga  128x128  a glowing ring round an icon
 *   orb.tga   128x128  a soft round glow
 * Build: gcc -O2 -o mkprocart.exe mkprocart.c -lm   then   mkprocart.exe <pfUI\img\procs folder>
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define PI 3.14159265358979

static double clamp01(double v) { return v < 0 ? 0 : (v > 1 ? 1 : v); }
static double gauss(double d, double s) { return exp(-(d * d) / (2 * s * s)); }

typedef struct { int w, h; double *a, *b; } Img;   /* a = coverage, b = brightness */

static Img make(int w, int h) {
  Img m; m.w = w; m.h = h;
  m.a = calloc((size_t)w * h, sizeof(double));
  m.b = calloc((size_t)w * h, sizeof(double));
  return m;
}
/* light adds up: coverage and brightness both */
static void add(Img *m, int x, int y, double a, double b) {
  int i = y * m->w + x;
  m->a[i] = clamp01(m->a[i] + a);
  m->b[i] = clamp01(m->b[i] + a * b);
}

static int save(const Img *m, const char *dir, const char *name) {
  char path[1024];
  snprintf(path, sizeof path, "%s/%s", dir, name);
  FILE *f = fopen(path, "wb");
  if (!f) { fprintf(stderr, "cannot write %s\n", path); return 1; }
  unsigned char hd[18] = { 0 };
  hd[2] = 2;                       /* uncompressed true colour */
  hd[12] = m->w & 255; hd[13] = m->w >> 8;
  hd[14] = m->h & 255; hd[15] = m->h >> 8;
  hd[16] = 32;
  hd[17] = 8 | 0x20;               /* 8 alpha bits, top-left origin */
  fwrite(hd, 1, 18, f);
  for (int i = 0; i < m->w * m->h; i++) {
    double a = clamp01(m->a[i]);
    /* brightness relative to coverage: a hot white core, softer at the edge */
    double b = a > 0 ? clamp01(m->b[i] / a) : 0;
    unsigned char g = (unsigned char)(255 * clamp01(.55 + .45 * b));
    unsigned char px[4] = { g, g, g, (unsigned char)(255 * a) };
    fwrite(px, 1, 4, f);
  }
  fclose(f);
  printf("%s %dx%d\n", name, m->w, m->h);
  return 0;
}

/* a band of light along a circle (centre cx, cy, radius r), thickness th, between angles a0..a1,
 * tapering to points at both ends; streaks = how many flame lines along it */
static void arc(Img *m, double cx, double cy, double r, double th, double a0, double a1, double power, double streaks) {
  for (int y = 0; y < m->h; y++)
    for (int x = 0; x < m->w; x++) {
      double dx = x + .5 - cx, dy = y + .5 - cy;
      double d = sqrt(dx * dx + dy * dy);
      double ang = atan2(dy, dx);
      while (ang < a0) ang += 2 * PI;
      if (ang > a1) continue;
      double k = (ang - a0) / (a1 - a0);           /* 0..1 along the arc */
      double taper = pow(sin(PI * k), .8);
      double t = th * (.25 + .75 * taper);
      double off = d - r;
      double core = gauss(off, t * .45) * taper;
      double halo = gauss(off, t * 1.6) * taper * .35;
      /* a slow ripple only (fast ones read as dots) */
      double flick = streaks > 0 ? .9 + .1 * sin(ang * streaks) : 1;
      add(m, x, y, (core + halo) * power * flick, core > halo ? 1 : .3);
    }
}

/* flame tongues out of an arc (outward = away from its centre): n of them between angles a0..a1,
 * curling by "curl" (radians over their length) */
static void rays(Img *m, double cx, double cy, double r, double a0, double a1, int n, double len, double curl, double power) {
  for (int i = 0; i < n; i++) {
    double k = n > 1 ? (double)i / (n - 1) : .5;
    double ang = a0 + k * (a1 - a0);
    double l = len * (.55 + .45 * sin(PI * k)) * (i % 2 ? .7 : 1);
    for (int y = 0; y < m->h; y++)
      for (int x = 0; x < m->w; x++) {
        double dx = x + .5 - cx, dy = y + .5 - cy;
        double d = sqrt(dx * dx + dy * dy);
        double along = d - r;
        if (along < -2 || along > l) continue;
        double f = along < 0 ? 0 : along / l;
        double a = atan2(dy, dx);
        while (a < ang - PI) a += 2 * PI;
        while (a > ang + PI) a -= 2 * PI;
        double side = (a - (ang + curl * f * f)) * d;   /* across the tongue, bending as it goes */
        double fade = pow(1 - f, 1.3);
        add(m, x, y, gauss(side, 1.2 + 3.2 * (1 - f)) * fade * power, f < .4 ? 1 : .5);
      }
  }
}

static void wing(const char *dir) {
  Img m = make(128, 256);
  /* the circle's centre right of the picture: the wing bows out to the left; three feathers,
   * flame tongues curling up off the outer one */
  double cx = 160, cy = 128;
  arc(&m, cx, cy, 128, 10, PI * .64, PI * 1.36, 1.0, 9);
  arc(&m, cx, cy, 110, 7, PI * .71, PI * 1.29, .7, 11);
  arc(&m, cx, cy, 94, 5, PI * .78, PI * 1.22, .5, 13);
  rays(&m, cx, cy, 128, PI * .70, PI * 1.30, 13, 26, -.35, .8);
  save(&m, dir, "wing.tga");
}

static void crown(const char *dir) {
  Img m = make(256, 128);
  /* an arc over the top: centre far below; rays up from it, the middle one tallest */
  double cx = 128, cy = 250;
  arc(&m, cx, cy, 190, 8, -PI * .80, -PI * .20, 1.0, 7);
  arc(&m, cx, cy, 172, 5, -PI * .74, -PI * .26, .6, 9);
  rays(&m, cx, cy, 190, -PI * .72, -PI * .28, 11, 44, 0, .85);
  save(&m, dir, "crown.tga");
}

static void beam(const char *dir) {
  Img m = make(64, 256);
  for (int y = 0; y < m.h; y++)
    for (int x = 0; x < m.w; x++) {
      double v = (y + .5) / m.h;
      double taper = pow(sin(PI * v), .7);
      double dx = x + .5 - 32;
      add(&m, x, y, (gauss(dx, 3.5) + gauss(dx, 14) * .5) * taper, .3 + .7 * gauss(dx, 4));
    }
  save(&m, dir, "beam.tga");
}

static void ring(const char *dir) {
  Img m = make(128, 128);
  for (int y = 0; y < m.h; y++)
    for (int x = 0; x < m.w; x++) {
      double dx = x + .5 - 64, dy = y + .5 - 64;
      double off = sqrt(dx * dx + dy * dy) - 44;
      add(&m, x, y, gauss(off, 2.6) + gauss(off, 9) * .4, gauss(off, 2.6) > .3 ? 1 : .3);
    }
  save(&m, dir, "ring.tga");
}

static void orb(const char *dir) {
  Img m = make(128, 128);
  for (int y = 0; y < m.h; y++)
    for (int x = 0; x < m.w; x++) {
      double dx = x + .5 - 64, dy = y + .5 - 64;
      double d = sqrt(dx * dx + dy * dy);
      add(&m, x, y, gauss(d, 26) * .85 + gauss(d, 9) * .4, .4 + .6 * gauss(d, 10));
    }
  save(&m, dir, "orb.tga");
}

int main(int argc, char **argv) {
  const char *dir = argc > 1 ? argv[1] : ".";
  wing(dir); crown(dir); beam(dir); ring(dir); orb(dir);
  return 0;
}
