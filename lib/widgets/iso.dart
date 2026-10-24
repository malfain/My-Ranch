import 'dart:math';

import 'package:flutter/material.dart';

// Dunia 2.5D: proyeksi isometrik, lempeng tanah, bangunan, kolam, dan hujan.

/// Proyeksi isometrik sederhana. Bidang tanah memakai koordinat (u, v) 0..1:
/// u menyusuri tepi belakang-kanan, v tepi belakang-kiri, (0, 0) = sudut belakang.
class Iso {
  Iso(this.size, {required double top, required double bottom, required double spread, required this.thick})
      : o = Offset(size.width / 2, size.height * top),
        hw = size.width * spread,
        hh = size.height * (bottom - top) / 2;

  /// [scene]: 'unggas', 'ternak', atau 'kolam'.
  factory Iso.of(String scene, Size s) => scene == 'kolam'
      ? Iso(s, top: .2, bottom: .9, spread: .64, thick: 14)
      : Iso(s, top: .3, bottom: .87, spread: .53, thick: 16);

  final Size size;
  final Offset o;
  final double hw, hh, thick;

  /// Skala tinggi bangunan mengikuti tinggi widget (acuan 230 px).
  double get z => size.height / 230;

  /// Titik layar untuk (u, v) setinggi [h] px di atas tanah.
  Offset p(double u, double v, [double h = 0]) => Offset(o.dx + (u - v) * hw, o.dy + (u + v) * hh - h * z);
  Offset delta(double du, double dv) => Offset((du - dv) * hw, (du + dv) * hh);

  /// Kedalaman 0 (belakang) .. 1 (depan) untuk urutan gambar.
  static double depth(double u, double v) => (u + v) / 2;
}

/// Tapak bangunan di bidang tanah (left/right = u, top/bottom = v). Hewan tidak masuk ke sini.
const houseRect = Rect.fromLTRB(.03, .03, .30, .30);
const balesRect = Rect.fromLTRB(.70, .05, .98, .13);
const duckPond = Offset(.22, .74);
const duckPondR = .13;
const _blockedBig = [houseRect, balesRect];
final _blockedSmall = [houseRect, Rect.fromCircle(center: duckPond, radius: duckPondR + .03)];
List<Rect> blockedAreas(bool big) => big ? _blockedBig : _blockedSmall;

/// Warna sedikit kelabu saat mendung atau hujan.
Color _wx(Color c, String w) => switch (w) {
      'hujan' => Color.lerp(c, const Color(0xFF5E6E7A), .24)!,
      'berawan' => Color.lerp(c, const Color(0xFF8A9AA6), .08)!,
      _ => c,
    };

Path _poly(List<Offset> pts) => Path()..addPolygon(pts, true);

Paint _grad(Rect r, List<Color> colors, {Alignment begin = Alignment.topCenter, Alignment end = Alignment.bottomCenter}) =>
    Paint()..shader = LinearGradient(begin: begin, end: end, colors: colors).createShader(r);

final _blur4 = MaskFilter.blur(BlurStyle.normal, 4), _blur8 = MaskFilter.blur(BlurStyle.normal, 8);

/// Langit, bukit jauh, lempeng tanah bertebal, rumput, pagar belakang, dan kolam (bebek/ikan).
/// Tidak beranimasi; bungkus dengan RepaintBoundary.
class IsoGround extends CustomPainter {
  IsoGround(this.weather, this.scene, {this.water});
  final String weather, scene;

  /// Warna air kolam ikan (hanya untuk 'kolam').
  final Color? water;

  @override
  void paint(Canvas canvas, Size size) {
    final iso = Iso.of(scene, size);
    _sky(canvas, size, iso);
    _slab(canvas, iso);
    _fence(canvas, iso);
    if (scene == 'unggas') _duckPond(canvas, iso);
    if (scene == 'kolam') _pondHole(canvas, PondShape(size));
  }

  void _sky(Canvas c, Size s, Iso iso) {
    final (top, bot) = switch (weather) {
      'hujan' => (const Color(0xFF74899A), const Color(0xFFBCC8D0)),
      'berawan' => (const Color(0xFF8DBAD6), const Color(0xFFE2EDF2)),
      _ => (const Color(0xFF4AB2EC), const Color(0xFFD6F1FB)),
    };
    final hz = iso.o.dy + iso.hh * .3;
    c.drawRect(Offset.zero & s, _grad(Rect.fromLTRB(0, 0, s.width, hz), [top, bot]));
    final sun = weather == 'cerah' ? 1.0 : weather == 'berawan' ? .4 : 0.0;
    if (sun > 0) {
      final sc = Offset(s.width * .87, s.height * .15);
      c.drawCircle(sc, 44, Paint()
        ..shader = RadialGradient(colors: [const Color(0xFFFFF6C2).withValues(alpha: .7 * sun), const Color(0x00FFF6C2)])
            .createShader(Rect.fromCircle(center: sc, radius: 44)));
      c.drawCircle(sc, 15, Paint()
        ..shader = RadialGradient(center: const Alignment(-.3, -.3), colors: [
          const Color(0xFFFFF8D0).withValues(alpha: sun), const Color(0xFFFFD447).withValues(alpha: sun)])
            .createShader(Rect.fromCircle(center: sc, radius: 15)));
    }
    final (cloud, under) = switch (weather) {
      'hujan' => (const Color(0xFF9AA8B4), const Color(0xFF7D8C99)),
      'berawan' => (const Color(0xFFF1F4F6), const Color(0xFFC9D3DA)),
      _ => (const Color(0xF2FFFFFF), const Color(0xFFD5E9F3)),
    };
    final clouds = [(.16, .11, 1.0), (.55, .07, .8), (.74, .22, .65), if (weather != 'cerah') ...[(.36, .16, .9), (.95, .08, .85)]];
    for (final (x, y, k) in clouds) {
      final o = Offset(s.width * x, s.height * y);
      final shape = Path()
        ..addOval(Rect.fromCenter(center: o, width: 70 * k, height: 20 * k))
        ..addOval(Rect.fromCircle(center: o + Offset(-12 * k, -6 * k), radius: 11 * k))
        ..addOval(Rect.fromCircle(center: o + Offset(8 * k, -9 * k), radius: 14 * k));
      c.drawPath(shape.shift(const Offset(0, 2.5)), Paint()..color = under);
      c.drawPath(shape, Paint()..color = cloud);
    }
    // Bukit jauh berkabut, lalu padang sekitar yang lebih gelap supaya lempeng menonjol.
    final far = Path()..moveTo(0, hz - 6);
    for (var i = 0; i <= 4; i++) {
      final x0 = s.width * i / 4;
      far.quadraticBezierTo(x0 + s.width / 8, hz - (i.isEven ? 26 : 14), x0 + s.width / 4, hz - 6);
    }
    far..lineTo(s.width, s.height)..lineTo(0, s.height)..close();
    c.drawPath(far, Paint()..color = _wx(const Color(0xFFA9CF96), weather));
    final near = Path()..moveTo(0, hz + 4);
    near
      ..quadraticBezierTo(s.width * .25, hz - 12, s.width * .5, hz + 2)
      ..quadraticBezierTo(s.width * .75, hz + 12, s.width, hz - 4)
      ..lineTo(s.width, s.height)..lineTo(0, s.height)..close();
    c.drawPath(near, _grad(Rect.fromLTRB(0, hz - 12, s.width, s.height),
        [_wx(const Color(0xFF8CC264), weather), _wx(const Color(0xFF5D923A), weather)]));
    for (final (x, y, k) in [(.07, hz + 2, 1.0), (.94, hz - 2, .9), (.82, hz + 1, .6)]) {
      _tree(c, Offset(s.width * x, y), k * iso.z);
    }
  }

  void _tree(Canvas c, Offset b, double k) {
    c.drawRect(Rect.fromLTWH(b.dx - 2 * k, b.dy - 12 * k, 4 * k, 12 * k), Paint()..color = _wx(const Color(0xFF6B4423), weather));
    final r = Rect.fromCircle(center: b + Offset(0, -22 * k), radius: 18 * k);
    final leaf = Paint()
      ..shader = RadialGradient(center: const Alignment(-.4, -.5), radius: .9,
          colors: [_wx(const Color(0xFF8ACB5E), weather), _wx(const Color(0xFF3F7F2C), weather)]).createShader(r);
    c.drawCircle(b + Offset(-7 * k, -17 * k), 10 * k, leaf);
    c.drawCircle(b + Offset(7 * k, -18 * k), 10 * k, leaf);
    c.drawCircle(b + Offset(0, -27 * k), 11 * k, leaf);
  }

  void _slab(Canvas c, Iso iso) {
    final t = Offset(0, iso.thick * iso.z);
    final T = iso.p(0, 0), R = iso.p(1, 0), B = iso.p(1, 1), L = iso.p(0, 1);
    // Bayangan lempeng di padang sekitar.
    c.drawPath(_poly([L + t, B + t + const Offset(0, 5), R + t, B + t - const Offset(0, 6)]),
        Paint()..color = const Color(0x55203010)..maskFilter = _blur8);
    final left = _poly([L, B, B + t, L + t]), right = _poly([B, R, R + t, B + t]);
    c.drawPath(left, _grad(left.getBounds(), [_wx(const Color(0xFFA4723F), weather), _wx(const Color(0xFF6F4526), weather)]));
    c.drawPath(right, _grad(right.getBounds(), [_wx(const Color(0xFF7C4F2C), weather), _wx(const Color(0xFF52321A), weather)]));
    final strata = Paint()
      ..color = const Color(0x40301808)
      ..strokeWidth = 1;
    for (final f in [.42, .74]) {
      c.drawLine(L + t * f, B + t * f, strata);
      c.drawLine(B + t * f, R + t * f, strata);
    }
    final rnd = Random(4);
    final pebble = Paint()..color = const Color(0x99C49A6A);
    for (var i = 0; i < 26; i++) {
      final a = rnd.nextDouble(), q = rnd.nextBool() ? Offset.lerp(L, B, a)! : Offset.lerp(B, R, a)!;
      c.drawOval(Rect.fromCenter(center: q + t * (.2 + rnd.nextDouble() * .7), width: 3 + rnd.nextDouble() * 2, height: 2), pebble);
    }
    // Akar rumput menjuntai di tepi depan.
    final fringe = Path();
    for (final (a, b) in [(L, B), (B, R)]) {
      final n = ((b - a).distance / 6).ceil();
      for (var i = 1; i <= n; i++) {
        final s = Offset.lerp(a, b, (i - 1) / n)!, m = Offset.lerp(a, b, (i - .5) / n)!, e = Offset.lerp(a, b, i / n)!;
        fringe.addPolygon([s - const Offset(0, 1), Offset(m.dx, m.dy + 3 + (i % 3)), e - const Offset(0, 1)], true);
      }
    }
    c.drawPath(fringe, Paint()..color = _wx(const Color(0xFF4C842B), weather));

    final top = _poly([T, R, B, L]);
    c.drawPath(top, _grad(top.getBounds(),
        [_wx(const Color(0xFFA9D873), weather), _wx(const Color(0xFF86C64D), weather), _wx(const Color(0xFF6BAF3C), weather)]));
    c.drawPath(top, _grad(top.getBounds(), const [Color(0x1CFFFFF0), Color(0x00000000), Color(0x1A0A2A00)],
        begin: Alignment.centerLeft, end: Alignment.centerRight));
    c.save();
    c.clipPath(top);
    // Bercak terang-gelap lembut, rumpun rumput, dan bunga kecil.
    for (var i = 0; i < 18; i++) {
      final q = iso.p(rnd.nextDouble(), rnd.nextDouble()), w = 40 + rnd.nextDouble() * 60;
      c.drawOval(Rect.fromCenter(center: q, width: w, height: w * .42), Paint()
        ..color = i.isEven ? const Color(0x24E4F7B0) : const Color(0x1C2F6A16)
        ..maskFilter = _blur8);
    }
    final dark = Path(), light = Path();
    for (var i = 0; i < 300; i++) {
      final u = rnd.nextDouble(), v = rnd.nextDouble(), q = iso.p(u, v), k = .7 + Iso.depth(u, v) * .6;
      final path = i % 3 == 0 ? light : dark;
      for (final dx in [-2.0, 0.0, 2.0]) {
        path..moveTo(q.dx, q.dy)..lineTo(q.dx + dx * k, q.dy - (dx == 0 ? 5 : 3.5) * k);
      }
    }
    final blade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    c.drawPath(dark, blade..color = _wx(const Color(0x804A8A28), weather));
    c.drawPath(light, blade..color = _wx(const Color(0x80D2F29A), weather));
    for (var i = 0; i < 14; i++) {
      final q = iso.p(rnd.nextDouble(), rnd.nextDouble());
      c.drawCircle(q, 1.6, Paint()..color = [const Color(0xFFFFFFFF), const Color(0xFFFFE066), const Color(0xFFFFA3C2)][i % 3]);
    }
    c.restore();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(Path()..moveTo(L.dx, L.dy)..lineTo(B.dx, B.dy)..lineTo(R.dx, R.dy),
        edge..color = const Color(0x99C6EC98)..strokeWidth = 1.6);
    c.drawPath(Path()..moveTo(L.dx, L.dy)..lineTo(T.dx, T.dy)..lineTo(R.dx, R.dy),
        edge..color = const Color(0x804E8A2C)..strokeWidth = 1.2);
  }

  void _fence(Canvas c, Iso iso) {
    final rail = Paint()
      ..color = _wx(const Color(0xFFA86A34), weather)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    final hi = Paint()
      ..color = _wx(const Color(0xFFDDA56A), weather)
      ..strokeWidth = 1;
    final lit = Paint()..color = _wx(const Color(0xFFD29A5C), weather), shade = Paint()..color = _wx(const Color(0xFF94602F), weather);
    final cap = Paint()..color = _wx(const Color(0xFFEBC08A), weather);
    final h = 15 * iso.z;
    for (final along in [(double t) => iso.p(t, 0), (double t) => iso.p(0, t)]) {
      for (final y in [5.0, 11.0]) {
        final a = along(0) - Offset(0, y * iso.z), b = along(1) - Offset(0, y * iso.z);
        c.drawLine(a, b, rail);
        c.drawLine(a - const Offset(0, 1.2), b - const Offset(0, 1.2), hi);
      }
      for (var i = 1; i <= 14; i++) {
        final b = along(i / 14);
        c.drawRect(Rect.fromLTRB(b.dx - 2.2, b.dy - h, b.dx, b.dy), lit);
        c.drawRect(Rect.fromLTRB(b.dx, b.dy - h, b.dx + 2.2, b.dy), shade);
        c.drawOval(Rect.fromCenter(center: b - Offset(0, h), width: 4.4, height: 2), cap);
      }
    }
  }

  void _duckPond(Canvas c, Iso iso) {
    final o = iso.p(duckPond.dx, duckPond.dy);
    final rx = sqrt2 * duckPondR * iso.hw, ry = sqrt2 * duckPondR * iso.hh;
    final rim = Rect.fromCenter(center: o, width: rx * 2, height: ry * 2);
    c.drawOval(rim.inflate(6), Paint()
      ..shader = RadialGradient(colors: [_wx(const Color(0xFF8C7246), weather), _wx(const Color(0x008C7246), weather)], stops: const [.75, 1])
          .createShader(rim.inflate(9)));
    c.drawOval(rim, Paint()..color = _wx(const Color(0xFF5A4630), weather));
    final water = Path.combine(PathOperation.intersect, Path()..addOval(rim), Path()..addOval(rim.shift(const Offset(0, 3))));
    c.drawPath(water, _grad(rim, [_wx(const Color(0xFF86D2F2), weather), _wx(const Color(0xFF3B8EC4), weather)]));
    c.drawOval(Rect.fromCenter(center: o + Offset(-rx * .3, -ry * .15), width: rx * .7, height: ry * .35),
        Paint()..color = const Color(0x4DFFFFFF)..maskFilter = _blur4);
    final rnd = Random(9);
    for (var i = 0; i < 16; i++) {
      final a = i / 16 * pi * 2, q = o + Offset(cos(a) * (rx + 2), sin(a) * (ry + 1.5));
      final st = Rect.fromCenter(center: q, width: 7 + rnd.nextDouble() * 3, height: 4.5);
      c.drawOval(st, Paint()..color = _wx(Color.lerp(const Color(0xFFA39C8E), const Color(0xFFC9C3B6), rnd.nextDouble())!, weather));
      c.drawOval(Rect.fromCenter(center: st.center - const Offset(1, 1), width: st.width * .5, height: 1.6), Paint()..color = const Color(0x66FFFFFF));
    }
    final pad = o + Offset(rx * .45, ry * .2);
    c.drawArc(Rect.fromCenter(center: pad, width: 14, height: 6), .4, pi * 2 - .8, true, Paint()..color = _wx(const Color(0xFF4FA83A), weather));
    c.drawCircle(pad + const Offset(-1, -2), 2, Paint()..color = const Color(0xFFFF9BBE));
    _reeds(c, o + Offset(-rx * .75, -ry * .5), 1);
  }

  void _reeds(Canvas c, Offset b, double k) {
    final stem = Paint()
      ..color = _wx(const Color(0xFF3F7A2A), weather)
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    for (final (dx, h) in [(-4.0, 18.0), (0.0, 24.0), (4.0, 16.0), (7.0, 20.0)]) {
      final top = b + Offset(dx * k + dx * .3, -h * k);
      c.drawLine(b + Offset(dx * k, 0), top, stem);
      if (h > 17) {
        c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: top + const Offset(0, 3), width: 3, height: 7), const Radius.circular(2)),
            Paint()..color = _wx(const Color(0xFF7A4A22), weather));
      }
    }
  }

  /// Lubang kolam ikan: dinding belakang terlihat dan dasar air yang dalam.
  void _pondHole(Canvas c, PondShape g) {
    c.drawOval(g.rim.inflate(9), Paint()..color = _wx(const Color(0xFF8E8676), weather));
    c.drawOval(g.rim, _grad(g.rim, [_wx(const Color(0xFF7A6A52), weather), _wx(const Color(0xFF3E3326), weather)]));
    final course = Paint()
      ..color = const Color(0x33000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final f in [.4, .75]) {
      c.drawArc(g.rim.shift(Offset(0, g.dz * f)), pi * 1.08, pi * .84, false, course);
    }
    final w = water ?? const Color(0xFF5CC0F5);
    final deep = const Color(0xFF0D3A5E);
    c.drawPath(g.water, _grad(g.rim.shift(Offset(0, g.dz)), [Color.lerp(w, deep, .55)!, Color.lerp(w, deep, .3)!]));
  }

  @override
  bool shouldRepaint(IsoGround old) => old.weather != weather || old.scene != scene || old.water != water;
}

/// Lempeng sisi-sisi kotak isometrik: sisi kanan (gelap), sisi kiri (terang), lalu atap/atas.
void _box(Canvas c, Iso iso, Rect r, double z0, double z1, Color top, Color lit, Color shade) {
  final (u0, v0, u1, v1) = (r.left, r.top, r.right, r.bottom);
  c.drawPath(_poly([iso.p(u1, v0, z0), iso.p(u1, v1, z0), iso.p(u1, v1, z1), iso.p(u1, v0, z1)]), Paint()..color = shade);
  c.drawPath(_poly([iso.p(u0, v1, z0), iso.p(u1, v1, z0), iso.p(u1, v1, z1), iso.p(u0, v1, z1)]), Paint()..color = lit);
  c.drawPath(_poly([iso.p(u0, v0, z1), iso.p(u1, v0, z1), iso.p(u1, v1, z1), iso.p(u0, v1, z1)]), Paint()..color = top);
}

/// Bayangan lembut tapak bangunan di tanah (cahaya dari kiri atas).
void _footShadow(Canvas c, Iso iso, Rect r) {
  final s = r.inflate(.015).shift(const Offset(.03, -.01));
  c.drawPath(_poly([iso.p(s.left, s.top), iso.p(s.right, s.top), iso.p(s.right, s.bottom), iso.p(s.left, s.bottom)]),
      Paint()..color = const Color(0x55203010)..maskFilter = _blur4);
}

/// Bangunan di sudut belakang: lumbung merah (ternak) atau rumah ayam kayu (unggas).
class IsoHouse extends CustomPainter {
  const IsoHouse(this.big, this.weather);
  final bool big;
  final String weather;

  @override
  void paint(Canvas c, Size size) {
    final iso = Iso.of(big ? 'ternak' : 'unggas', size);
    const r = houseRect;
    final (u0, v0, u1, v1) = (r.left, r.top, r.right, r.bottom);
    final vm = (v0 + v1) / 2;
    final wall = big ? 36.0 : 26.0, roof = big ? 26.0 : 19.0, o = .02;
    Color w(int c) => _wx(Color(c), weather);
    final (lit, shade, roofLit, roofDark, trim) = big
        ? (w(0xFFC9442F), w(0xFF8E2C1C), w(0xFF8C3A2A), w(0xFF5E2216), w(0xFFF4EBDD))
        : (w(0xFFDCAA6A), w(0xFFA7713C), w(0xFFCC4A32), w(0xFF8A2C1C), w(0xFFF6E6C4));
    // Titik pada sisi kanan (gable) dan sisi kiri, s = 0..1 sepanjang sisi.
    Offset f(double s, double h) => iso.p(u1, v0 + s * (v1 - v0), h);
    Offset g(double s, double h) => iso.p(u0 + s * (u1 - u0), v1, h);
    _footShadow(c, iso, r);
    final gable = _poly([f(0, 0), f(1, 0), f(1, wall), f(.5, wall + roof), f(0, wall)]);
    c.drawPath(gable, _grad(gable.getBounds(), [shade, Color.lerp(shade, Colors.black, .18)!]));
    final front = _poly([g(0, 0), g(1, 0), g(1, wall), g(0, wall)]);
    c.drawPath(front, _grad(front.getBounds(), [lit, Color.lerp(lit, Colors.black, .12)!], begin: Alignment.centerLeft, end: Alignment.centerRight));
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (big) {
      // Papan tegak.
      line.color = const Color(0x22000000);
      for (var s = .1; s < 1; s += .1) {
        c.drawLine(g(s, 0), g(s, wall), line);
        c.drawLine(f(s, 0), f(s, wall), line);
      }
    } else {
      line.color = const Color(0x40502A0C);
      for (var k = 1; k < 5; k++) {
        c.drawLine(g(0, wall * k / 5), g(1, wall * k / 5), line);
        c.drawLine(f(0, wall * k / 5), f(1, wall * k / 5), line);
      }
    }
    final trimP = Paint()
      ..color = trim
      ..style = PaintingStyle.stroke
      ..strokeWidth = big ? 2.2 : 1.6
      ..strokeJoin = StrokeJoin.round;
    final hole = Paint()..color = w(big ? 0xFF3A2418 : 0xFF4A2A12);
    Path quad(Offset Function(double, double) at, double s0, double s1, double h0, double h1) =>
        _poly([at(s0, h0), at(s1, h0), at(s1, h1), at(s0, h1)]);
    if (big) {
      // Pintu besar bersilang di sisi gable, jendela loteng, dua jendela di sisi kiri.
      final door = quad(f, .26, .74, 0, wall * .74);
      c.drawPath(door, Paint()..color = w(0xFF7E2618));
      c.drawPath(door, trimP);
      c.drawLine(f(.26, 0), f(.74, wall * .74), trimP);
      c.drawLine(f(.74, 0), f(.26, wall * .74), trimP);
      c.drawLine(f(.5, 0), f(.5, wall * .74), trimP);
      final loft = quad(f, .42, .58, wall + 3, wall + 13);
      c.drawPath(loft, hole);
      c.drawPath(loft, trimP);
      for (final s in [.18, .62]) {
        final win = quad(g, s, s + .18, wall * .42, wall * .74);
        c.drawPath(win, hole);
        c.drawPath(win, trimP);
      }
      for (final q in [(f, 0.0), (f, 1.0), (g, 0.0)]) {
        c.drawLine(q.$1(q.$2, 0), q.$1(q.$2, wall), trimP);
      }
    } else {
      // Pintu kecil yang ditinggikan + papan titian, jendela kecil.
      final door = quad(f, .38, .62, wall * .14, wall * .66);
      c.drawPath(door, hole);
      c.drawPath(door, trimP);
      final ramp = _poly([f(.4, wall * .14), f(.6, wall * .14), iso.p(u1 + .09, v0 + .6 * (v1 - v0)), iso.p(u1 + .09, v0 + .4 * (v1 - v0))]);
      c.drawPath(ramp, Paint()..color = w(0xFFC08A4C));
      final slat = Paint()
        ..color = w(0xFF7A4A1E)
        ..strokeWidth = 1;
      for (final k in [.3, .55, .8]) {
        c.drawLine(Offset.lerp(f(.4, wall * .14), iso.p(u1 + .09, v0 + .4 * (v1 - v0)), k)!,
            Offset.lerp(f(.6, wall * .14), iso.p(u1 + .09, v0 + .6 * (v1 - v0)), k)!, slat);
      }
      final win = quad(g, .55, .78, wall * .4, wall * .75);
      c.drawPath(win, hole);
      c.drawPath(win, trimP);
      c.drawLine(g(.665, wall * .4), g(.665, wall * .75), trimP);
    }
    // Atap: sisi depan terlihat, list atap di ujung gable.
    final eaveL = iso.p(u0 - o, v1 + o, wall - 3), eaveR = iso.p(u1 + o, v1 + o, wall - 3);
    final ridgeL = iso.p(u0 - o, vm, wall + roof), ridgeR = iso.p(u1 + o, vm, wall + roof);
    final roofP = _poly([eaveL, eaveR, ridgeR, ridgeL]);
    c.drawPath(roofP, _grad(roofP.getBounds(), [Color.lerp(roofLit, Colors.white, .12)!, roofLit, roofDark]));
    final row = Paint()
      ..color = const Color(0x2A000000)
      ..strokeWidth = 1;
    for (final k in [.25, .5, .75]) {
      c.drawLine(Offset.lerp(eaveL, ridgeL, k)!, Offset.lerp(eaveR, ridgeR, k)!, row);
    }
    final fascia = Paint()
      ..color = big ? trim : roofDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    c.drawPath(Path()..moveTo(iso.p(u1 + o, v0 - o, wall - 3).dx, iso.p(u1 + o, v0 - o, wall - 3).dy)..lineTo(ridgeR.dx, ridgeR.dy)..lineTo(eaveR.dx, eaveR.dy), fascia);
    c.drawLine(ridgeL, ridgeR, fascia..color = Color.lerp(roofLit, Colors.white, .25)!..strokeWidth = 1.6);
    c.drawLine(eaveL, eaveR, Paint()..color = const Color(0x40000000)..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(IsoHouse old) => old.big != big || old.weather != weather;
}

/// Tumpukan jerami kotak di tepi belakang kanan padang ternak.
class IsoBales extends CustomPainter {
  const IsoBales(this.weather);
  final String weather;

  @override
  void paint(Canvas c, Size size) {
    final iso = Iso.of('ternak', size), h = 11.0;
    _footShadow(c, iso, balesRect);
    Color w(int c) => _wx(Color(c), weather);
    final straw = Paint()
      ..color = w(0x66A0701E)
      ..strokeWidth = 1;
    final twine = Paint()
      ..color = w(0xFF8A5A1E)
      ..strokeWidth = 1.2;
    for (final (u0, u1, z0) in [(.70, .84, 0.0), (.84, .98, 0.0), (.76, .90, h)]) {
      final r = Rect.fromLTRB(u0, balesRect.top, u1, balesRect.bottom);
      _box(c, iso, r, z0, z0 + h, w(0xFFF2D27E), w(0xFFE0B456), w(0xFFB4852F));
      final rnd = Random((u0 * 100).round());
      for (var i = 0; i < 6; i++) {
        final a = iso.p(u0 + rnd.nextDouble() * (u1 - u0), r.bottom, z0 + 2 + rnd.nextDouble() * (h - 4));
        c.drawLine(a, a + Offset(4 + rnd.nextDouble() * 3, 1.5), straw);
      }
      for (final s in [.3, .7]) {
        final u = u0 + s * (u1 - u0);
        c.drawLine(iso.p(u, r.bottom, z0), iso.p(u, r.bottom, z0 + h), twine);
        c.drawLine(iso.p(u, r.bottom, z0 + h), iso.p(u, r.top, z0 + h), twine);
      }
    }
  }

  @override
  bool shouldRepaint(IsoBales old) => old.weather != weather;
}

/// Bayangan elips lembut di bawah hewan. [spots]: pusat & ukuran tiap bayangan.
class SoftShadows extends CustomPainter {
  SoftShadows(this.spots);
  final List<Rect> spots;

  static final _paint = Paint()
    ..shader = const RadialGradient(colors: [Color(0x55142008), Color(0x00142008)])
        .createShader(Rect.fromCircle(center: Offset.zero, radius: 1));

  @override
  void paint(Canvas c, Size size) {
    for (final r in spots) {
      c.save();
      c.translate(r.center.dx, r.center.dy);
      c.scale(r.width / 2, r.height / 2);
      c.drawCircle(Offset.zero, 1, _paint);
      c.restore();
    }
  }

  @override
  bool shouldRepaint(SoftShadows old) => true;
}

/// Bentuk kolam ikan: bibir (elips) dan permukaan air yang lebih rendah [dz] px.
class PondShape {
  PondShape(this.size)
      : c = Iso.of('kolam', size).p(.5, .5),
        rx = size.width * .37,
        ry = size.height * .22,
        dz = size.height * .055;
  final Size size;
  final Offset c;
  final double rx, ry, dz;

  Rect get rim => Rect.fromCenter(center: c, width: rx * 2, height: ry * 2);
  Path get water => Path.combine(PathOperation.intersect, Path()..addOval(rim), Path()..addOval(rim.shift(Offset(0, dz))));
}

/// Permukaan air di atas ikan: lapisan warna tembus, riak bergerak, kilau, dan daun teratai.
class PondSurface extends CustomPainter {
  PondSurface(this.t, this.water);
  final double t;
  final Color water;

  static Size? _size;
  static Color? _water;
  static PondShape? _shape;
  static Path? _path;
  static Paint? _tint, _shine;
  static final _ripple = Paint()
    ..color = const Color(0x55FFFFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.6
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas c, Size size) {
    if (_size != size) {
      _size = size;
      _water = null;
      _shape = PondShape(size);
      _path = _shape!.water;
      final g = _shape!, glint = Rect.fromCenter(center: g.c + Offset(-g.rx * .35, g.dz - g.ry * .35), width: g.rx * .8, height: g.ry * .22);
      _shine = Paint()..shader = const RadialGradient(colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)]).createShader(glint);
    }
    final g = _shape!, path = _path!, area = g.rim.shift(Offset(0, g.dz));
    if (_water != water) {
      _water = water;
      _tint = _grad(area, [Color.lerp(water, Colors.white, .35)!.withValues(alpha: .5), water.withValues(alpha: .3)]);
    }
    c.save();
    c.clipPath(path);
    c.drawRect(area, _tint!);
    final r = Random(3);
    for (var i = 0; i < 11; i++) {
      final x = area.left + (r.nextDouble() * area.width + t * 6 * (i.isEven ? 1 : -1)) % area.width;
      final y = area.top + area.height * (.15 + r.nextDouble() * .8);
      final len = 14 + r.nextDouble() * 18, wob = sin(t * 1.5 + i) * 2;
      c.drawArc(Rect.fromCenter(center: Offset(x, y), width: len + wob, height: 5), pi * 1.1, pi * .8, false, _ripple);
    }
    c.drawOval(Rect.fromCenter(center: g.c + Offset(-g.rx * .35, g.dz - g.ry * .35), width: g.rx * .8, height: g.ry * .22), _shine!);
    c.restore();
    final pad = Paint()..color = const Color(0xFF4FA83A), vein = Paint()
      ..color = const Color(0xFF2E7020)
      ..strokeWidth = 1;
    for (final (dx, dy, rad) in [(.62, -.2, 13.0), (-.55, .45, 10.0), (.45, .55, 8.0)]) {
      final q = g.c + Offset(g.rx * dx, g.dz / 2 + g.ry * dy + sin(t * .8 + dx * 5) * .8);
      final rect = Rect.fromCenter(center: q, width: rad * 2, height: rad * .9);
      c.drawArc(rect, .35, pi * 2 - .7, true, pad);
      c.drawLine(q, q + Offset(-rad * .7, -rad * .1), vein);
    }
    c.drawCircle(g.c + Offset(g.rx * .62 - 2, g.dz / 2 - g.ry * .2 - 3), 3.5, Paint()..color = const Color(0xFFFF9BBE));
  }

  @override
  bool shouldRepaint(PondSurface old) => old.t != t || old.water != water;
}

/// Bibir batu kolam ikan dan rumpun gelagah; digambar di atas ikan.
class PondRim extends CustomPainter {
  const PondRim(this.weather);
  final String weather;

  @override
  void paint(Canvas c, Size size) {
    final g = PondShape(size), rnd = Random(21);
    const n = 30;
    final stones = <(double, Rect, Color)>[];
    for (var i = 0; i < n; i++) {
      final a = i / n * pi * 2 + rnd.nextDouble() * .05;
      final q = g.c + Offset(cos(a) * (g.rx + 4), sin(a) * (g.ry + 3));
      final k = .8 + .4 * (sin(a) + 1) / 2;
      stones.add((sin(a), Rect.fromCenter(center: q, width: (15 + rnd.nextDouble() * 6) * k, height: (8 + rnd.nextDouble() * 3) * k),
          _wx(Color.lerp(const Color(0xFF9E978A), const Color(0xFFCCC6B9), rnd.nextDouble())!, weather)));
    }
    stones.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, r, col) in stones) {
      c.drawOval(r.shift(const Offset(0, 1.5)), Paint()..color = const Color(0x55302818));
      c.drawOval(r, Paint()
        ..shader = RadialGradient(center: const Alignment(-.4, -.5), colors: [Color.lerp(col, Colors.white, .35)!, col, Color.lerp(col, Colors.black, .25)!],
            stops: const [0, .55, 1]).createShader(r));
    }
    final ground = IsoGround(weather, 'kolam');
    ground._reeds(c, g.c + Offset(-g.rx * .92, -g.ry * .55), 1.1);
    ground._reeds(c, g.c + Offset(g.rx * .88, -g.ry * .7), .9);
    ground._reeds(c, g.c + Offset(g.rx * 1.02, g.ry * .35), 1);
  }

  @override
  bool shouldRepaint(PondRim old) => old.weather != weather;
}

/// Tetes hujan miring.
class RainPainter extends CustomPainter {
  RainPainter(this.t);
  final double t;

  static final _paint = Paint()
    ..color = const Color(0x8CDCEBFF)
    ..strokeWidth = 1.2;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Random(7);
    for (var i = 0; i < 70; i++) {
      final x0 = r.nextDouble() * (size.width + 40);
      final speed = 260 + r.nextDouble() * 120;
      final y = (r.nextDouble() * size.height + t * speed) % (size.height + 20) - 10;
      final x = x0 - y * .25;
      canvas.drawLine(Offset(x, y), Offset(x - 3, y + 11), _paint);
    }
  }

  @override
  bool shouldRepaint(RainPainter old) => old.t != t;
}
