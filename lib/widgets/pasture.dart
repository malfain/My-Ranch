import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/art.dart';
import '../game/state.dart';
import 'iso.dart';

/// Posisi terakhir tiap hewan di bidang tanah (u, v dalam 0..1), supaya tidak melompat saat pindah layar.
final _positions = <String, Offset>{};
final _rand = Random();

class _Sprite {
  _Sprite(this.animal, Offset p)
      : u = p.dx, v = p.dy, tu = p.dx, tv = p.dy,
        wait = _rand.nextDouble() * 2.5, left = _rand.nextBool(),
        art = SvgPicture.string(animalArt[animal.kind]!);
  final Animal animal;
  double u, v, tu, tv, wait;
  bool left, walking = false;
  final Widget art;
}

class _Pop {
  _Pop(this.u, this.v, this.icon, this.text);
  final double u, v;
  final String icon, text;
  double age = 0;
}

class Pasture extends StatefulWidget {
  const Pasture({super.key, required this.kinds, this.title, this.height = 290});

  /// Kandang ayam & bebek memakai latar unggas (rumah ayam dan kolam);
  /// sapi & kambing memakai padang dengan lumbung.
  static const poultry = ['ayam', 'bebek'];
  static const livestock = ['kambing', 'sapi'];

  /// Null = semua hewan.
  final List<String> kinds;
  final String? title;
  bool get big => kinds.any(Pasture.livestock.contains);
  final double height;

  @override
  State<Pasture> createState() => _PastureState();
}

class _PastureState extends State<Pasture> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final _sprites = <String, _Sprite>{};
  final _popList = <_Pop>[];
  StreamSubscription<PopEvent>? _sub;
  Duration _last = Duration.zero;
  double _clock = 0;
  Iso? _iso;

  String get _scene => widget.big ? 'ternak' : 'unggas';

  @override
  void initState() {
    super.initState();
    _sync();
    farm.addListener(_sync);
    _sub = farm.pops.listen((e) {
      final s = _sprites[e.animalId];
      if (s == null) return;
      _popList.add(_Pop(s.u, s.v, e.icon, e.text));
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

  /// Titik boleh diinjak: di dalam lempeng, tidak terlalu di belakang/samping, di luar bangunan.
  bool _free(double u, double v) {
    if (u < .06 || v < .06 || u > .94 || v > .94 || u + v < .56 || (u - v).abs() > .74) return false;
    for (final r in blockedAreas(widget.big)) {
      if (r.inflate(.05).contains(Offset(u, v))) return false;
    }
    return true;
  }

  bool _clearPath(double u0, double v0, double u1, double v1) {
    for (var i = 1; i <= 6; i++) {
      if (!_free(u0 + (u1 - u0) * i / 6, v0 + (v1 - v0) * i / 6)) return false;
    }
    return true;
  }

  Offset _spawn() {
    for (var i = 0; i < 80; i++) {
      final u = _rand.nextDouble(), v = _rand.nextDouble();
      // Lebih banyak di tengah-depan supaya kawanan tersebar di seluruh lempeng.
      if (_free(u, v) && u + v > .95) return Offset(u, v);
    }
    return const Offset(.6, .6);
  }

  void _sync() {
    final want = farm.animals.where((a) => widget.kinds.contains(a.kind)).take(24).toList();
    final ids = want.map((a) => a.id).toSet();
    _sprites.removeWhere((id, _) => !ids.contains(id));
    for (final a in want) {
      _sprites.putIfAbsent(a.id, () {
        final p = _positions[a.id];
        return _Sprite(a, p != null && _free(p.dx, p.dy) ? p : _spawn());
      });
    }
  }

  void _frame(Duration now) {
    final dt = min(.1, (now - _last).inMicroseconds / 1e6);
    _last = now;
    _clock += dt;
    final iso = _iso;
    if (iso != null) {
      for (final s in _sprites.values) {
        if (s.wait > 0) {
          s.wait -= dt;
          s.walking = false;
          continue;
        }
        final a = s.animal, k = a.k;
        final tired = a.food < 15 || a.water < 15;
        final d = iso.delta(s.tu - s.u, s.tv - s.v), dist = d.distance;
        if (dist < 1.5) {
          s.wait = a.kind == 'ayam' ? .4 + _rand.nextDouble() * 1.6 : 1.5 + _rand.nextDouble() * 3;
          // Cari tujuan dekat yang jalurnya tidak menabrak bangunan; kalau tidak ada, diam dulu.
          s.tu = s.u;
          s.tv = s.v;
          for (var i = 0; i < 12; i++) {
            final u = s.u + (_rand.nextDouble() - .5) * .6, v = s.v + (_rand.nextDouble() - .5) * .6;
            // Tujuan di bagian belakang lebih sering ditolak: condong ke tengah-depan.
            if (u + v < 1.0 && _rand.nextDouble() < .6) continue;
            if (_free(u, v) && _clearPath(s.u, s.v, u, v)) {
              s.tu = u;
              s.tv = v;
              break;
            }
          }
          continue;
        }
        final sp = k.speed * (tired ? .4 : 1) * iso.size.width / 100 * dt, step = min(1.0, sp / dist);
        s.u += (s.tu - s.u) * step;
        s.v += (s.tv - s.v) * step;
        if (d.dx.abs() > 1) s.left = d.dx < 0;
        s.walking = true;
        _positions[a.id] = Offset(s.u, s.v);
      }
    }
    for (final p in _popList) {
      p.age += dt;
    }
    _popList.removeWhere((p) => p.age > 1.1);
    setState(() {});
  }

  Widget? _bubble(Animal a) {
    final key = a.ready ? a.k.product : a.food < 30 ? a.k.feed : a.water < 30 ? 'air' : null;
    if (key == null) return null;
    final big = a.ready;
    final d = big ? 36.0 : 30.0;
    final bob = sin(_clock * 3) * 2;
    // Siap panen: gelembung krem berbingkai emas. Butuh sesuatu: gelembung oranye.
    final (bg, edge) = big ? (const Color(0xFFFFFAF0), const Color(0xFFA8650A)) : (const Color(0xFFFFC093), const Color(0xFFB2541A));
    return Transform.translate(
      offset: Offset(0, bob),
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

  /// Lebar sprite: mengecil ke belakang, anak hewan lebih kecil.
  double _width(_Sprite s) => s.animal.k.size * (.8 + Iso.depth(s.u, s.v) * .4) * 1.15 * (s.animal.adult ? 1 : .62);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final iso = _iso = Iso.of(_scene, Size(c.maxWidth - 10, widget.height - 10));
      // Hewan dan jerami diurutkan menurut kedalaman supaya yang di depan menutupi yang di belakang.
      // Jerami digambar tepat setelah hewan terakhir yang berdiri di belakangnya (v < tepi depan jerami).
      var balesAt = -1.0;
      for (final s in _sprites.values) {
        if (s.v < balesRect.bottom && s.u < balesRect.right) balesAt = max(balesAt, Iso.depth(s.u, s.v) + 1e-6);
      }
      final layers = <(double, Widget)>[
        for (final s in _sprites.values) (Iso.depth(s.u, s.v), _spriteWidget(s, iso)),
        if (widget.big)
          (balesAt,
              Positioned.fill(key: const ValueKey('jerami'), child: IgnorePointer(child: RepaintBoundary(child: CustomPaint(painter: IsoBales(farm.weather)))))),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      final shadows = [
        for (final s in _sprites.values)
          Rect.fromCenter(center: iso.p(s.u, s.v) + const Offset(0, 1), width: _width(s) * .78, height: _width(s) * .2),
      ];
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
            Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: IsoGround(farm.weather, _scene)))),
            Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: IsoHouse(widget.big, farm.weather)))),
            Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: SoftShadows(shadows)))),
            for (final l in layers) l.$2,
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
            for (final p in _popList) _popWidget(p, iso),
            if (widget.title != null)
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
                    widget.title!,
                    style: GoogleFonts.lilitaOne(fontSize: 14, color: const Color(0xFF4A2708)),
                  ),
                ),
              ),
          ]),
        ),
      ),
      );
    });
  }

  Widget _spriteWidget(_Sprite s, Iso iso) {
    final k = s.animal.k, foot = iso.p(s.u, s.v);
    final sw = _width(s), sh = sw * k.aspect;
    final bob = s.walking ? sin(_clock * 17) * 1.6 - 1.6 : 0.0;
    final bubble = _bubble(s.animal);
    // Gelembung hewan paling belakang digeser turun supaya tidak terpotong bingkai atas.
    final lift = max(0.0, 6 - (foot.dy - sh - 34 + 38 - (s.animal.ready ? 36 : 30)));
    return Positioned(
      key: ValueKey(s.animal.id),
      left: foot.dx - sw / 2,
      top: foot.dy - sh - 34,
      width: sw,
      height: sh + 36,
      // Hanya badan hewan dan gelembungnya yang bisa diketuk; ruang kosong di atas tidak menghalangi hewan di belakang.
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: [
        Positioned(
          left: 0, right: 0, bottom: 0, height: sh,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => farm.tap(s.animal),
            child: Transform.translate(
              offset: Offset(0, bob),
              child: Transform.flip(flipX: s.left, child: s.art),
            ),
          ),
        ),
        if (bubble != null)
          Positioned(bottom: sh - 4 - lift, child: GestureDetector(onTap: () => farm.tap(s.animal), child: bubble)),
      ]),
    );
  }

  Widget _popWidget(_Pop p, Iso iso) {
    final t = p.age / 1.1, at = iso.p(p.u, p.v);
    final opacity = t < .15 ? t / .15 : 1 - (t - .15) / .85;
    return Positioned(
      left: at.dx - 30,
      top: at.dy - 80 - t * 46,
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
