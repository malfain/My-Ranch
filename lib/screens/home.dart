import 'package:flutter/material.dart';

import '../game/art.dart';
import '../game/data.dart';
import '../game/state.dart';
import '../ui_state.dart';
import '../widgets/common.dart';
import '../widgets/pasture.dart';
import '../widgets/pond.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Layar dibangun ulang setiap kali data peternakan berubah.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([farm, ui]), builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final h = farm.farmHealth;
    final careN = farm.animals.where(farm.needsCare).length;
    final ringColor = h >= 60 ? const Color(0xFF5CB82A) : h >= 35 ? const Color(0xFFF08A1C) : C.low;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Pasture(kinds: Pasture.poultry, title: 'Kandang Unggas · Ayam & Bebek', height: 240),
      const SizedBox(height: 14),
      const QuickTasks(Pasture.poultry),
      const SizedBox(height: 22),
      if (farm.pondOpen) ...[
        const Pond(),
        const SizedBox(height: 12),
        Box(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            Expanded(child: Meter('Jernih', farm.pondClean, C.water)),
            const SizedBox(width: 12),
            Text('Isi ${farm.fish.length} / ${farm.pondCap}', style: display(16, color: C.muted)),
          ]),
        ),
        const SizedBox(height: 14),
        const _PondTasks(),
      ] else
        const _LockedPond(),
      const SizedBox(height: 22),
      if (farm.unlocked('kambing')) ...[
        const Pasture(kinds: Pasture.livestock, title: 'Padang Ternak · Kambing & Sapi', height: 240),
        const SizedBox(height: 14),
        const QuickTasks(Pasture.livestock),
      ] else
        const _LockedField(),
      const SizedBox(height: 16),
      IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Box(
              child: Row(children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: C.okDark, width: 3)),
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(value: h / 100, strokeWidth: 8, color: ringColor, backgroundColor: C.track),
                    ),
                    Text('$h%', style: display(14, color: C.okDark)),
                  ]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('Kesehatan ternak', style: muted),
                    Text(farm.animals.isEmpty ? 'Kosong' : h >= 70 ? 'Sehat' : h >= 45 ? 'Cukup' : 'Perlu dirawat',
                        style: display(20, color: h >= 45 ? C.okDark : C.low)),
                    Text(careN > 0 ? '$careN ekor butuh perhatian' : 'Semua baik', style: muted),
                  ]),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Box(
              child: Row(children: [
                svg(icons[farm.weather]!, size: 50),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('${farm.temp}°C', style: display(23)),
                    Text(weatherLabels[farm.weather]!, style: muted),
                    Text('Hari ${farm.day} · ${farm.clock}', style: muted),
                  ]),
                ),
              ]),
            ),
          ),
        ]),
      ),
      const SectionTitle('Kandang', trailing: 'Ketuk untuk membuka'),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 14, crossAxisSpacing: 12, childAspectRatio: 1.55,
        children: [for (final k in kindOrder) _PenCard(k)],
      ),
      const SizedBox(height: 20),
      Center(
        child: WoodPanel(
          gap: 16,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          child: const OutlinedText('Ketuk hewan di padang untuk mengelus atau memanen.', size: 13, width: 2.4, stroke: C.woodDeep),
        ),
      ),
    ]);
  }
}

class _PenCard extends StatelessWidget {
  const _PenCard(this.k);
  final String k;

  @override
  Widget build(BuildContext context) {
    final kind = kinds[k]!;
    final open = farm.unlocked(k);
    final list = farm.animals.where((a) => a.kind == k).toList();
    final r = list.where((a) => a.ready).length, bad = list.where(farm.needsCare).length;
    final ink = open ? C.ink : C.lockText;
    final Widget tag = !open
        ? LockNote(kind.unlock)
        : list.isEmpty
            ? const Tag('Kosong', Tone.plain)
            : r > 0
                ? Tag('$r siap panen', Tone.gold)
                : bad > 0
                    ? Tag('$bad butuh dirawat', Tone.warn)
                    : const Tag('Sehat', Tone.ok);
    return Box(
      locked: !open,
      padding: const EdgeInsets.all(10),
      onTap: () => ui.openKind(k),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(children: [
          Face(animal(k), locked: !open, tint: kindTint(k), edge: kindEdge(k)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kind.label, style: display(19, color: ink)),
              Text('${list.length} / ${farm.cap(k)}', style: display(16, color: open ? C.muted : C.lockText)),
            ]),
          ),
        ]),
        tag,
      ]),
    );
  }
}

/// Tiga tombol besar (pakan, minum, panen) untuk sekelompok jenis hewan.
class QuickTasks extends StatelessWidget {
  const QuickTasks(this.only, {super.key});
  final List<String> only;

  @override
  Widget build(BuildContext context) {
    final list = farm.pick(only).toList();
    final hungry = list.where((a) => a.food < 60).length;
    final thirsty = list.where((a) => a.water < 60).length;
    final ready = list.where((a) => a.ready).length;
    return Row(children: [
      _Quick(kinds[only.first]!.feed, BtnStyle.primary, 'Beri pakan', list.isEmpty ? 'Kosong' : hungry > 0 ? '$hungry lapar' : 'Kenyang',
          list.any((a) => a.food < 92) ? () => farm.feedAll(only: only) : null),
      const SizedBox(width: 10),
      _Quick('air', BtnStyle.blue, 'Beri minum', list.isEmpty ? 'Kosong' : thirsty > 0 ? '$thirsty haus' : 'Segar',
          list.any((a) => a.water < 95) ? () => farm.waterAll(only: only) : null),
      const SizedBox(width: 10),
      _Quick('panen', BtnStyle.gold, 'Panen semua', ready > 0 ? '$ready siap' : 'Belum ada',
          ready > 0 ? () => farm.harvestAll(only: only) : null),
    ]);
  }
}

class _Quick extends StatelessWidget {
  const _Quick(this.ico, this.style, this.label, this.sub, this.onTap);
  final String ico, label, sub;
  final BtnStyle style;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final (top, bottom, edge) = !enabled
        ? (const Color(0xFFE8DCC0), const Color(0xFFE8DCC0), const Color(0xFFA8916A))
        : switch (style) {
            BtnStyle.primary => (const Color(0xFF9EE35A), const Color(0xFF4FA524), C.okDark),
            BtnStyle.blue => (const Color(0xFF8FD8FF), const Color(0xFF2F9BE0), const Color(0xFF1B5F96)),
            _ => (const Color(0xFFFFE680), const Color(0xFFF5B315), const Color(0xFFA8650A)),
          };
    final gold = style == BtnStyle.gold;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [top, bottom]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: edge, width: 3),
        boxShadow: drop(edge, 6),
      ),
      child: Column(children: [
        Container(
          width: 50, height: 50, padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: C.cream, shape: BoxShape.circle, border: Border.all(color: edge, width: 3)),
          child: Opacity(opacity: enabled ? 1 : .5, child: icon(ico, size: 28)),
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: !enabled
              ? Text(label, style: display(17, color: C.lockText))
              : gold
                  ? Text(label, style: display(17, color: const Color(0xFF5A2D00)))
                  : OutlinedText(label, size: 17, stroke: edge, width: 3.2),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 1),
          decoration: BoxDecoration(
            color: enabled ? edge.withValues(alpha: .7) : const Color(0x33000000),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Text(sub, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white)),
        ),
      ]),
    );
    return Expanded(child: enabled ? Pressable(onTap: onTap!, child: card) : card);
  }
}

/// Tiga tombol besar (pelet, bersihkan, panen) untuk kolam ikan.
class _PondTasks extends StatelessWidget {
  const _PondTasks();

  @override
  Widget build(BuildContext context) {
    final list = farm.fish;
    final hungry = list.where((f) => f.food < 60).length;
    final ready = list.where((f) => f.ready).length;
    return Row(children: [
      _Quick('pelet', BtnStyle.primary, 'Beri pelet', list.isEmpty ? 'Kosong' : hungry > 0 ? '$hungry lapar' : 'Kenyang',
          list.any((f) => f.food < 92) ? farm.feedFish : null),
      const SizedBox(width: 10),
      _Quick('air', BtnStyle.blue, 'Bersihkan', '${farm.pondClean.round()}%', farm.pondClean < 95 ? farm.cleanPond : null),
      const SizedBox(width: 10),
      _Quick('panen', BtnStyle.gold, 'Panen ikan', ready > 0 ? '$ready siap' : 'Belum ada',
          ready > 0 ? () => farm.harvestFish() : null),
    ]);
  }
}

/// Kolam ikan sebelum terbuka.
class _LockedPond extends StatelessWidget {
  const _LockedPond();

  @override
  Widget build(BuildContext context) {
    return Box(
      locked: true,
      radius: 26,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: Row(children: [
        Face(icon('kolam', size: 44), w: 64, h: 56, locked: true),
        const SizedBox(width: 6),
        Face(svg(fishArt['lele']!), w: 64, h: 56, locked: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kolam Ikan', style: display(19, color: C.lockText)),
            const SizedBox(height: 2),
            Text('Tempat lele, nila & gurame. Terbuka di Level $pondUnlock.', style: muted.copyWith(color: C.lockText)),
          ]),
        ),
      ]),
    );
  }
}

/// Padang sapi & kambing sebelum terbuka.
class _LockedField extends StatelessWidget {
  const _LockedField();

  @override
  Widget build(BuildContext context) {
    return Box(
      locked: true,
      radius: 26,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      child: Row(children: [
        Face(animal('kambing'), w: 64, h: 56, locked: true),
        const SizedBox(width: 6),
        Face(animal('sapi'), w: 64, h: 56, locked: true),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Padang Ternak', style: display(19, color: C.lockText)),
            const SizedBox(height: 2),
            Text('Tempat kambing & sapi. Terbuka di Level ${kinds['kambing']!.unlock}.', style: muted.copyWith(color: C.lockText)),
          ]),
        ),
      ]),
    );
  }
}
