import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/art.dart';
import '../game/state.dart';
import 'iso.dart';

/// Posisi terakhir tiap ikan (dalam 0..1 di dalam elips kolam), supaya tidak melompat saat pindah layar.
final _positions = <String, Offset>{};
final _rand = Random();

/// Lebar sprite (px) dan kecepatan renang (persen lebar per detik).
const _look = {'lele': (58.0, 9.0), 'nila': (50.0, 7.0), 'gurame': (58.0, 5.0)};

/// Rasio tinggi/lebar gambar ikan, dibaca dari viewBox SVG.
final _aspect = <String, double>{};
double _aspectOf(String kind) => _aspect.putIfAbsent(kind, () {
      final m = RegExp(r'viewBox="\s*[-\d.]+[\s,]+[-\d.]+[\s,]+([\d.]+)[\s,]+([\d.]+)').firstMatch(fishArt[kind]!);
      return m == null ? .6 : double.parse(m[2]!) / double.parse(m[1]!);
    });

const _clear = Color(0xFF5CC0F5), _murky = Color(0xFF8FA65A);

/// Titik di dalam elips air (dengan batas supaya ikan tidak menembus bibir).
bool _inside(double x, double y) {
  final a = (2 * x - 1) / .92, b = (2 * y - 1) / .8;
  return a * a + b * b <= 1;
}

class _Swimmer {
  _Swimmer(this.fish, Offset p)
      : x = p.dx, y = p.dy, tx = p.dx, ty = p.dy,
        wait = _rand.nextDouble() * 2, left = _rand.nextBool(), phase = _rand.nextDouble() * 6,
        art = SvgPicture.string(fishArt[fish.kind]!);
  final Fish fish;
  double x, y, tx, ty, wait, phase;
  bool left;
  final Widget art;
}

class _Pop {
  _Pop(this.x, this.y, this.icon, this.text);
  final double x, y;
  final String icon, text;
  double age = 0;
}

/// Kolam ikan beranimasi. Ketuk ikan yang siap untuk memanennya.
class Pond extends StatefulWidget {
  const Pond({super.key, this.height = 200});
  final double height;

  @override
  State<Pond> createState() => _PondState();
}

class _PondState extends State<Pond> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _swimmers = <String, _Swimmer>{};
  final _popList = <_Pop>[];
  StreamSubscription<PopEvent>? _sub;
  Duration _last = Duration.zero;
  double _clock = 0;
  PondShape? _shape;

  @override
  void initState() {
    super.initState();
    _sync();
    farm.addListener(_sync);
    // Ikan yang dipanen sudah keluar dari kolam, jadi pakai posisi terakhirnya.
    _sub = farm.pops.listen((e) {
      final p = _positions[e.animalId];
      if (p == null) return;
      _popList.add(_Pop(p.dx, p.dy, e.icon, e.text));
    });
    _ticker = createTicker(_frame)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    farm.removeListener(_sync);
    _sub?.cancel();
    super.dispose();
  }

  Offset _spawn() {
    for (var i = 0; i < 60; i++) {
      final x = _rand.nextDouble(), y = _rand.nextDouble();
      if (_inside(x, y)) return Offset(x, y);
    }
    return const Offset(.5, .5);
  }

  void _sync() {
    final want = farm.fish.take(24).toList();
    final ids = want.map((f) => f.id).toSet();
    _swimmers.removeWhere((id, _) => !ids.contains(id));
    for (final f in want) {
      _swimmers.putIfAbsent(f.id, () {
        final old = _positions[f.id];
        final p = old != null && _inside(old.dx, old.dy) ? old : _spawn();
        _positions[f.id] = p;
        return _Swimmer(f, p);
      });
    }
  }

  /// Posisi logis (x, y) ke titik layar di permukaan air.
  Offset _at(PondShape g, double x, double y) =>
      Offset(g.c.dx + (2 * x - 1) * g.rx * .86, g.c.dy + g.dz / 2 + (2 * y - 1) * (g.ry - g.dz / 2) * .9);

  void _frame(Duration now) {
    final dt = min(.1, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _clock += dt;
    final g = _shape;
    if (g != null) {
      for (final s in _swimmers.values) {
        if (s.wait > 0) {
          s.wait -= dt;
          continue;
        }
        final d = _at(g, s.tx, s.ty) - _at(g, s.x, s.y), dist = d.distance;
        if (dist < 1.5) {
          s.wait = .6 + _rand.nextDouble() * 2.4;
          for (var i = 0; i < 10; i++) {
            final x = s.x + (_rand.nextDouble() - .5) * .7, y = s.y + (_rand.nextDouble() - .5) * .5;
            if (_inside(x, y)) {
              s.tx = x;
              s.ty = y;
              break;
            }
          }
          continue;
        }
        // Ikan lapar berenang pelan.
        final v = _look[s.fish.kind]!.$2 * (s.fish.food < 15 ? .4 : 1) * g.size.width / 100 * dt, step = min(1.0, v / dist);
        s.x += (s.tx - s.x) * step;
        s.y += (s.ty - s.y) * step;
        if (d.dx.abs() > 1) s.left = d.dx < 0;
        _positions[s.fish.id] = Offset(s.x, s.y);
      }
    }
    // Pop ikan yang dipanen sudah dibuat sebelum frame ini, jadi posisinya boleh dibuang.
    _positions.removeWhere((id, _) => !_swimmers.containsKey(id));
    for (final p in _popList) {
      p.age += dt;
    }
    _popList.removeWhere((p) => p.age > 1.1);
    setState(() {});
  }

  Widget? _bubble(Fish f) {
    final key = f.ready ? f.k.product : f.food < 30 ? 'pelet' : null;
    if (key == null) return null;
    final big = f.ready;
    final d = big ? 34.0 : 28.0;
    // Siap panen: gelembung krem berbingkai emas. Lapar: gelembung oranye.
    final (bg, edge) = big ? (const Color(0xFFFFFAF0), const Color(0xFFA8650A)) : (const Color(0xFFFFC093), const Color(0xFFB2541A));
    return Transform.translate(
      offset: Offset(0, sin(_clock * 3) * 2),
      child: Container(
        width: d, height: d,
        decoration: BoxDecoration(
          color: bg, shape: BoxShape.circle,
          border: Border.all(color: edge, width: 3),
          boxShadow: [BoxShadow(color: edge, offset: const Offset(0, 3))],
        ),
        padding: const EdgeInsets.all(4),
        child: SvgPicture.string(icons[key]!),
      ),
    );
  }

  /// Kotak sprite ikan di layar: bibit kecil lalu membesar, sedikit mengecil di belakang kolam.
  Rect _rect(PondShape g, _Swimmer s) {
    final f = s.fish;
    final sw = _look[f.kind]!.$1 * (.55 + f.grow * .45) * (.86 + s.y * .24), sh = sw * _aspectOf(f.kind);
    final c = _at(g, s.x, s.y) + Offset(0, sin(_clock * 2.2 + s.phase) * 2);
    return Rect.fromCenter(center: c, width: sw, height: sh);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth - 10, widget.height - 10);
      if (_shape?.size != size) _shape = PondShape(size);
      final g = _shape!;
      final sorted = _swimmers.values.toList()..sort((a, b) => a.y.compareTo(b.y));
      // Air memudar kehijauan saat kejernihan turun (dibulatkan supaya latar jarang digambar ulang, lalu dipudarkan halus).
      final clean = (((farm.pondClean - 20) / 80).clamp(0, 1) * 20).round() / 20;
      final target = Color.lerp(_murky, _clear, clean)!;
      return TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: target),
        duration: const Duration(seconds: 1),
        builder: (context, col, _) => _frameBox(g, sorted, col ?? target),
      );
    });
  }

  Widget _frameBox(PondShape g, List<_Swimmer> sorted, Color water) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFF8A5222), width: 5),
        boxShadow: const [BoxShadow(color: Color(0xFF4A2708), offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: SizedBox(
          height: widget.height - 10,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: IsoGround(farm.weather, 'kolam', water: water)))),
            // Ikan di bawah permukaan: terpotong elips air dan tertutup lapisan air tembus.
            Positioned.fill(
              child: IgnorePointer(
                child: ClipPath(
                  clipper: _WaterClip(g),
                  child: Stack(children: [
                    for (final s in sorted)
                      Positioned.fromRect(
                        key: ValueKey(s.fish.id),
                        rect: _rect(g, s),
                        child: Transform.flip(flipX: s.left, child: s.art),
                      ),
                  ]),
                ),
              ),
            ),
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: PondSurface(_clock, water)))),
            Positioned.fill(child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: PondRim(farm.weather))))),
            for (final s in sorted) _swimmerWidget(s, g),
            if (farm.fish.isEmpty)
              Positioned.fromRect(
                rect: g.rim,
                child: Center(
                  child: Text('Kolam kosong. Beli bibit ikan di Pasar.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.lilitaOne(fontSize: 15, color: const Color(0xFFFFF4D6),
                          shadows: const [Shadow(color: Color(0x99000000), blurRadius: 3, offset: Offset(0, 1))])),
                ),
              ),
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(seconds: 2),
                  color: const Color(0xFF1B2550).withValues(alpha: farm.darkness * .8),
                ),
              ),
            ),
            if (farm.weather == 'hujan')
              Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: RainPainter(_clock)))),
            for (final p in _popList) _popWidget(p, g),
            Positioned(
              left: 12, top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4D6),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: const Color(0xFFB9783A), width: 3),
                  boxShadow: const [BoxShadow(color: Color(0xFF8A5222), offset: Offset(0, 3))],
                ),
                child: Text(
                  'Kolam Ikan · ${farm.fish.length} / ${farm.pondCap}',
                  style: GoogleFonts.lilitaOne(fontSize: 14, color: const Color(0xFF4A2708)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  /// Area ketuk + gelembung di atas permukaan air (ikannya sendiri digambar di bawah air).
  Widget _swimmerWidget(_Swimmer s, PondShape g) {
    final f = s.fish, r = _rect(g, s);
    final bubble = _bubble(f);
    return Positioned(
      key: ValueKey(f.id),
      left: r.left,
      top: r.top - 34,
      width: r.width,
      height: r.height + 34,
      // Hanya ikan siap panen (badan dan gelembungnya) yang menangkap ketukan.
      child: IgnorePointer(
        ignoring: !f.ready,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
          Positioned(
            left: 0, right: 0, bottom: 0, height: r.height,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => farm.harvestFish(one: f)),
          ),
          if (bubble != null)
            Positioned(bottom: r.height - 2, child: GestureDetector(onTap: () => farm.harvestFish(one: f), child: bubble)),
        ]),
      ),
    );
  }

  Widget _popWidget(_Pop p, PondShape g) {
    final t = p.age / 1.1, at = _at(g, p.x, p.y);
    final opacity = t < .15 ? t / .15 : 1 - (t - .15) / .85;
    return Positioned(
      left: at.dx - 30,
      top: at.dy - 60 - t * 46,
      width: 60,
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity.clamp(0, 1),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            SizedBox(width: 22, height: 22, child: SvgPicture.string(icons[p.icon]!)),
            if (p.text.isNotEmpty)
              Text(p.text,
                  style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16,
                    shadows: [Shadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 1))],
                  )),
          ]),
        ),
      ),
    );
  }
}

class _WaterClip extends CustomClipper<Path> {
  _WaterClip(this.g);
  final PondShape g;

  @override
  Path getClip(Size size) => g.water;

  @override
  bool shouldReclip(_WaterClip old) => old.g != g;
}
