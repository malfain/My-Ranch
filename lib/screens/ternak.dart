import 'dart:async';

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/state.dart';
import '../ui_state.dart';
import '../widgets/common.dart';
import '../widgets/pasture.dart';
import 'home.dart' show QuickTasks;

class TernakScreen extends StatelessWidget {
  const TernakScreen({super.key});

  // Layar dibangun ulang setiap kali data peternakan berubah.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([farm, ui]), builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final k = ui.kind, kind = kinds[k]!;
    final open = farm.unlocked(k);
    final list = farm.animals.where((a) => a.kind == k).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(
        height: 60,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.only(bottom: 8), children: [
          for (final x in kindOrder) _Chip(x),
        ]),
      ),
      const SizedBox(height: 6),
      Pasture(key: ValueKey(k), kinds: [k], title: 'Kandang ${kind.label} · ${farm.count(k)}/${farm.cap(k)} ekor', height: 250),
      Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 6, children: [
          Pill('Pakan: ${feeds[kind.feed]!.label} · ${fmt(farm.feed[kind.feed]!)} ${feeds[kind.feed]!.unit}'),
          Pill('${products[kind.product]!.label} ±${kind.time} dtk'),
        ]),
      ),
      const SizedBox(height: 14),
      if (open && list.isNotEmpty) ...[QuickTasks([k]), const SizedBox(height: 18)],
      if (open) ...[_ExpandPen(k), const SizedBox(height: 14)],
      if (!open)
        _Empty(k, 'Kandang ${kind.label.toLowerCase()} masih terkunci.\nNaikkan peternakan ke Level ${kind.unlock} untuk membukanya.', false)
      else if (list.isEmpty)
        _Empty(k, 'Belum ada ${kind.label.toLowerCase()} di kandang.', true)
      else
        for (final a in list) Padding(padding: const EdgeInsets.only(bottom: 14), child: _AnimalRow(a)),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.k);
  final String k;

  @override
  Widget build(BuildContext context) {
    final on = ui.kind == k, open = farm.unlocked(k);
    final (Gradient? grad, Color bg, Color edge, Color shadow, Color fg) = on
        ? (const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE680), Color(0xFFF5B315)]),
            const Color(0xFFF5B315), const Color(0xFFA8650A), const Color(0xFFA8650A), const Color(0xFF5A2D00))
        : open
            ? (null, C.cream, C.creamEdge, C.creamShadow, C.ink)
            : (null, const Color(0xFFE8DCC0), const Color(0xFFA8916A), C.lockShadow, const Color(0xFF5C4528));
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Pressable(
        onTap: () => ui.openKind(k),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: grad, color: grad == null ? bg : null,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: edge, width: 3),
            boxShadow: drop(shadow, 4),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(kinds[k]!.label, style: display(16, color: fg)),
            const SizedBox(width: 6),
            open
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(color: on ? const Color(0xFF5A2D00) : C.creamEdge, borderRadius: BorderRadius.circular(99)),
                    child: Text('${farm.count(k)}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: on ? const Color(0xFFFFE680) : Colors.white)),
                  )
                : Icon(Icons.lock_rounded, size: 14, color: fg),
          ]),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.k, this.text, this.canBuy);
  final String k, text;
  final bool canBuy;

  @override
  Widget build(BuildContext context) {
    return Box(
      locked: !canBuy,
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
      child: Column(children: [
        Face(animal(k), w: 110, h: 90, pad: 10, locked: !canBuy, tint: kindTint(k), edge: kindEdge(k)),
        const SizedBox(height: 12),
        Text(text, textAlign: TextAlign.center, style: const TextStyle(color: C.muted, fontWeight: FontWeight.w900)),
        if (canBuy) ...[
          const SizedBox(height: 12),
          Btn(label: 'Beli di Pasar', style: BtnStyle.primary, expand: false, onTap: () => ui.go(2)),
        ],
      ]),
    );
  }
}

class _AnimalRow extends StatefulWidget {
  const _AnimalRow(this.a);
  final Animal a;

  @override
  State<_AnimalRow> createState() => _AnimalRowState();
}

class _AnimalRowState extends State<_AnimalRow> {
  bool _confirmSell = false;
  Timer? _disarm;

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  void _sell() {
    final a = widget.a;
    final why = farm.sellBlock(a);
    if (why != null) {
      farm.sellAnimal(a); // menampilkan alasannya
      return;
    }
    if (!_confirmSell) {
      setState(() => _confirmSell = true);
      _disarm?.cancel();
      _disarm = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _confirmSell = false);
      });
      return;
    }
    _disarm?.cancel();
    farm.sellAnimal(a);
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.a, k = a.k;
    final (mt, tone) = farm.mood(a);
    final needy = tone == Tone.warn || tone == Tone.bad;
    return Box(
      padding: const EdgeInsets.all(12),
      radius: 22,
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Pressable(
            onTap: () => farm.pet(a),
            child: Face(
              a.adult ? animal(a.kind) : Padding(padding: const EdgeInsets.all(8), child: animal(a.kind)),
              w: 64, h: 64, pad: 6,
              tint: needy ? const Color(0xFFFFD9B8) : kindTint(a.kind),
              edge: needy ? const Color(0xFFB2541A) : kindEdge(a.kind),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(a.name, style: display(20)),
                if (!a.adult) const Tag('Anak', Tone.plain),
                if (a.pregnant) const Tag('Hamil', Tone.ok),
                Tag(mt, tone),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Meter('Pakan', a.food, C.food)),
                const SizedBox(width: 10),
                Expanded(child: Meter('Air', a.water, C.water)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Meter('Senang', a.joy, C.joy)),
                const SizedBox(width: 10),
                Expanded(
                  child: a.adult
                      ? Meter('Hasil', a.prog * 100, C.harvest, warnLow: false)
                      : Meter('Tumbuh', a.grow * 100, const Color(0xFF9B6BE0), warnLow: false),
                ),
              ]),
              if (a.pregnant) ...[
                const SizedBox(height: 6),
                Meter('Hamil', a.preg * 100, const Color(0xFFFF8FB1), warnLow: false),
              ],
            ]),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Btn(label: 'Pakan', style: BtnStyle.primary, size: 17, onTap: () => farm.feedOne(a)),
          const SizedBox(width: 8),
          Btn(label: 'Minum', style: BtnStyle.blue, size: 17, onTap: () => farm.waterOne(a)),
          const SizedBox(width: 8),
          Btn(label: 'Panen', style: BtnStyle.gold, size: 17, onTap: a.ready ? () => farm.collect(a) : null),
        ]),
        if (a.adult && (k.canBreed || k.canSell)) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (k.canBreed)
              Btn(
                label: a.pregnant ? 'Sedang hamil' : 'Kawinkan',
                lead: icon('hati'),
                size: 16,
                onTap: a.pregnant ? null : () => farm.breed(a),
              ),
            if (k.canBreed && k.canSell) const SizedBox(width: 8),
            if (k.canSell)
              Btn(
                label: _confirmSell ? 'Yakin jual?' : 'Jual · ${fmt(k.sellPrice)}',
                lead: icon('coin'),
                size: 16,
                style: _confirmSell ? BtnStyle.gold : BtnStyle.cream,
                onTap: a.pregnant ? null : _sell,
              ),
          ]),
        ],
      ]),
    );
  }
}

/// Kapasitas kandang dan tombol untuk memperluasnya.
class _ExpandPen extends StatelessWidget {
  const _ExpandPen(this.k);
  final String k;

  @override
  Widget build(BuildContext context) {
    final kind = kinds[k]!, cost = farm.capCost(k);
    final n = farm.count(k), cap = farm.cap(k), full = n >= cap;
    return Box(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kandang ${kind.label}', style: display(17)),
            Text(full ? 'Penuh · $n/$cap ekor' : 'Terisi $n/$cap ekor',
                style: muted.copyWith(color: full ? C.low : C.muted)),
            Text('+${kind.capStep} tempat setiap perluasan', style: muted),
          ]),
        ),
        Btn(
          label: 'Perluas · ${fmt(cost)}',
          lead: icon('coin'),
          expand: false,
          style: full ? BtnStyle.gold : BtnStyle.cream,
          onTap: farm.coins >= cost ? () => farm.upgradePen(k) : null,
        ),
      ]),
    );
  }
}
