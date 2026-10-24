import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/art.dart';
import '../game/data.dart';
import '../game/state.dart';

/// Palet "Kebun Ceria": rumput, papan kayu, dan kartu krem berbingkai cokelat.
class C {
  static const grass = Color(0xFF78C241);
  static const wood = Color(0xFFC98A4B);
  static const woodDark = Color(0xFF6B3B12);
  static const woodDeep = Color(0xFF4A2708);
  static const cream = Color(0xFFFFF4D6);
  static const creamEdge = Color(0xFFB9783A);
  static const creamShadow = Color(0xFF8A5222);
  static const ink = Color(0xFF4A2708);
  static const muted = Color(0xFF7A4F24);
  static const lockBg = Color(0xFFEFE3C4);
  static const lockEdge = Color(0xFFB8A27A);
  static const lockShadow = Color(0xFF8F7A55);
  static const lockText = Color(0xFF6A5434);
  static const track = Color(0xFFE8D6AE);
  static const food = Color(0xFF6CC232);
  static const water = Color(0xFF2F9BE0);
  static const joy = Color(0xFFFF6F9A);
  static const harvest = Color(0xFFF5B315);
  static const low = Color(0xFFE8412E);
  static const okDark = Color(0xFF2F6B12);
}

TextStyle display(double size, {Color color = C.ink}) =>
    GoogleFonts.lilitaOne(fontSize: size, color: color, height: 1.1);

const muted = TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w800);

Widget svg(String code, {double? size}) => SizedBox(width: size, height: size, child: SvgPicture.string(code));
Widget icon(String key, {double size = 20}) => svg(icons[key]!, size: size);
Widget animal(String kind, {double? size}) => svg(animalArt[kind]!, size: size);

List<BoxShadow> drop(Color c, [double y = 5]) => [BoxShadow(color: c, offset: Offset(0, y))];

/// Teks putih bergaris tepi tebal, seperti judul di game kartun.
class OutlinedText extends StatelessWidget {
  const OutlinedText(this.text, {super.key, this.size = 24, this.stroke = C.woodDark, this.fill = Colors.white, this.width = 4});
  final String text;
  final double size, width;
  final Color stroke, fill;

  @override
  Widget build(BuildContext context) {
    final base = GoogleFonts.lilitaOne(fontSize: size, height: 1.1);
    return Stack(children: [
      Transform.translate(
        offset: Offset(0, width * .6),
        child: Text(text, style: base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeJoin = StrokeJoin.round
            ..color = stroke,
        )),
      ),
      Text(text, style: base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeJoin = StrokeJoin.round
          ..color = stroke,
      )),
      Text(text, style: base.copyWith(color: fill)),
    ]);
  }
}

/// Garis-garis papan kayu.
class _PlankPainter extends CustomPainter {
  _PlankPainter(this.gap);
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0x736B3B12)
      ..strokeWidth = 2;
    for (var y = gap; y < size.height; y += gap) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
    final grain = Paint()
      ..color = const Color(0x14FFF0D2)
      ..strokeWidth = 2;
    for (var x = 2.0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grain);
    }
  }

  @override
  bool shouldRepaint(_PlankPainter old) => old.gap != gap;
}

class WoodPanel extends StatelessWidget {
  const WoodPanel({super.key, required this.child, this.padding = const EdgeInsets.all(8), this.radius = 16, this.gap = 24, this.border = 3});
  final Widget child;
  final EdgeInsets padding;
  final double radius, gap, border;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: C.wood,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: C.woodDark, width: border),
        boxShadow: drop(C.woodDeep, 5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - border),
        child: CustomPaint(
          painter: _PlankPainter(gap),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Latar rumput dengan titik-titik halus.
class GrassBackground extends StatelessWidget {
  const GrassBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GrassPainter(), child: child);
}

class _GrassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = C.grass);
    final stripe = Paint()..color = const Color(0x12FFFFFF);
    for (var d = -size.height; d < size.width; d += 52) {
      final path = Path()
        ..moveTo(d, 0)
        ..lineTo(d + 26, 0)
        ..lineTo(d + 26 + size.height, size.height)
        ..lineTo(d + size.height, size.height)
        ..close();
      canvas.drawPath(path, stripe);
    }
    final light = Paint()..color = const Color(0x29FFFFFF);
    final dark = Paint()..color = const Color(0x381E5A0A);
    for (var y = 0.0; y < size.height; y += 30) {
      for (var x = 0.0; x < size.width; x += 34) {
        canvas.drawCircle(Offset(x + 8.5, y + 9), 3, light);
      }
    }
    for (var y = 0.0; y < size.height; y += 38) {
      for (var x = 0.0; x < size.width; x += 44) {
        canvas.drawCircle(Offset(x + 33, y + 26.6), 4, dark);
      }
    }
  }

  @override
  bool shouldRepaint(_GrassPainter old) => false;
}

/// Kartu krem berbingkai cokelat dengan bayangan padat.
class Box extends StatelessWidget {
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(12), this.onTap, this.locked = false, this.radius = 20});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool locked;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      decoration: BoxDecoration(
        color: locked ? C.lockBg : C.cream,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: locked ? C.lockEdge : C.creamEdge, width: 3),
        boxShadow: drop(locked ? C.lockShadow : C.creamShadow),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius - 3),
          border: Border(bottom: BorderSide(color: locked ? Colors.transparent : const Color(0xFFF1DCAE), width: 4)),
        ),
        padding: padding,
        child: child,
      ),
    );
    return onTap == null ? card : Pressable(onTap: onTap!, child: card);
  }
}

/// Turun sedikit saat ditekan, seperti tombol fisik.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 70),
          offset: Offset(0, _down ? .03 : 0),
          child: widget.child,
        ),
      ),
    );
  }
}

Color kindTint(String k) => switch (k) {
      'ayam' => const Color(0xFFC4EE8F),
      'bebek' => const Color(0xFFB9E6FF),
      'kambing' => const Color(0xFFFFE2A8),
      _ => const Color(0xFFFFD6E0),
    };
Color kindEdge(String k) => switch (k) {
      'ayam' => const Color(0xFF5C9A2A),
      'bebek' => const Color(0xFF2F8AC9),
      'kambing' => const Color(0xFFC98A14),
      _ => const Color(0xFFD4527A),
    };

class Face extends StatelessWidget {
  const Face(this.child, {super.key, this.w = 54, this.h = 54, this.pad = 5, this.locked = false, this.tint, this.edge});
  final Widget child;
  final double w, h, pad;
  final bool locked;
  final Color? tint, edge;

  @override
  Widget build(BuildContext context) {
    final img = locked
        ? Opacity(
            opacity: .6,
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix([
                .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, .33, .33, .33, 0, 0, 0, 0, 0, 1, 0,
              ]),
              child: child,
            ),
          )
        : child;
    return Container(
      width: w, height: h, padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: locked ? const Color(0xFFE0D4B4) : (tint ?? const Color(0xFFC4EE8F)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: locked ? const Color(0xFFA8916A) : (edge ?? const Color(0xFF5C9A2A)), width: 3),
      ),
      child: img,
    );
  }
}

class Tag extends StatelessWidget {
  const Tag(this.text, this.tone, {super.key, this.lock = false});
  final String text;
  final Tone tone;
  final bool lock;

  @override
  Widget build(BuildContext context) {
    final (bg, edge, fg) = switch (tone) {
      Tone.ok => (const Color(0xFFC8F09A), const Color(0xFF3F8A1C), const Color(0xFF24520D)),
      Tone.warn => (const Color(0xFFFFC093), const Color(0xFFB2541A), const Color(0xFF6B2600)),
      Tone.bad => (const Color(0xFFFFA494), const Color(0xFFB23A28), const Color(0xFF5E1206)),
      Tone.gold => (const Color(0xFFFFD84D), const Color(0xFFA8650A), const Color(0xFF5A2D00)),
      Tone.plain => (const Color(0xFFE8DCC0), const Color(0xFFA8916A), const Color(0xFF5C4528)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(99), border: Border.all(color: edge, width: 2)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (lock) ...[Icon(Icons.lock_rounded, size: 12, color: fg), const SizedBox(width: 3)],
        Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: fg)),
      ]),
    );
  }
}

class Meter extends StatelessWidget {
  const Meter(this.label, this.value, this.color, {super.key, this.warnLow = true});
  final String label;
  final double value;
  final Color color;
  final bool warnLow;

  @override
  Widget build(BuildContext context) {
    final low = warnLow && value < 25;
    return Row(children: [
      SizedBox(width: 50, child: Text(label, maxLines: 1, softWrap: false, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: C.muted))),
      Expanded(
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: C.track,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: C.creamShadow, width: 2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: (value / 100).clamp(0, 1),
                heightFactor: 1,
                child: Container(color: low ? C.low : color),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

enum BtnStyle { cream, primary, blue, gold }

/// Tombol timbul 3D: gradasi, bingkai tebal, dan bayangan padat di bawah.
class Btn extends StatelessWidget {
  const Btn({
    super.key,
    required this.label,
    this.onTap,
    this.lead,
    this.style = BtnStyle.cream,
    this.expand = true,
    this.size = 16,
  });
  final String label;
  final VoidCallback? onTap;
  final Widget? lead;
  final BtnStyle style;
  final bool expand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final (top, bottom, edge, outline) = !enabled
        ? (const Color(0xFFE8DCC0), const Color(0xFFE8DCC0), const Color(0xFFA8916A), null)
        : switch (style) {
            BtnStyle.primary => (const Color(0xFF9EE35A), const Color(0xFF4FA524), C.okDark, C.okDark),
            BtnStyle.blue => (const Color(0xFF8FD8FF), const Color(0xFF2F9BE0), const Color(0xFF1B5F96), const Color(0xFF1B5F96)),
            BtnStyle.gold => (const Color(0xFFFFE680), const Color(0xFFF5B315), const Color(0xFFA8650A), null),
            BtnStyle.cream => (const Color(0xFFFFFAF0), const Color(0xFFF1DCAE), C.creamEdge, null),
          };
    final textColor = !enabled
        ? C.lockText
        : style == BtnStyle.gold
            ? const Color(0xFF5A2D00)
            : C.ink;
    final text = outline != null
        ? OutlinedText(label, size: size, stroke: outline, width: 3.2)
        : Text(label, style: GoogleFonts.lilitaOne(fontSize: size, color: textColor, height: 1.1));
    final b = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: edge, width: 3),
        boxShadow: drop(edge, 4),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
        if (lead != null) ...[SizedBox(width: 20, height: 20, child: lead), const SizedBox(width: 6)],
        Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: text)),
      ]),
    );
    final w = enabled ? Pressable(onTap: onTap!, child: b) : b;
    return expand ? Expanded(child: w) : w;
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 12),
      child: Row(children: [
        Expanded(child: Align(alignment: Alignment.centerLeft, child: OutlinedText(text, size: 24))),
        if (trailing != null) Pill(trailing!),
      ]),
    );
  }
}

/// Label kecil berbingkai krem.
class Pill extends StatelessWidget {
  const Pill(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.creamEdge, width: 2)),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: C.ink)),
      );
}

class CoinText extends StatelessWidget {
  const CoinText(this.amount, {super.key, this.style});
  final int amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        icon('coin', size: 16),
        const SizedBox(width: 4),
        Text(fmt(amount), style: style ?? const TextStyle(fontWeight: FontWeight.w900)),
      ]);
}

class LockNote extends StatelessWidget {
  const LockNote(this.level, {super.key});
  final int level;

  @override
  Widget build(BuildContext context) => Tag('Level $level', Tone.plain, lock: true);
}
