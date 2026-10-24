import 'dart:async';

import 'package:flutter/material.dart';

import '../game/data.dart';
import '../game/state.dart';
import '../widgets/common.dart';

class GudangScreen extends StatefulWidget {
  const GudangScreen({super.key});

  @override
  State<GudangScreen> createState() => _GudangScreenState();
}

class _GudangScreenState extends State<GudangScreen> {
  bool _armed = false;
  Timer? _disarm;

  @override
  void dispose() {
    _disarm?.cancel();
    super.dispose();
  }

  void _reset() {
    if (!_armed) {
      setState(() => _armed = true);
      _disarm?.cancel();
      _disarm = Timer(const Duration(milliseconds: 3500), () {
        if (mounted) setState(() => _armed = false);
      });
      return;
    }
    _disarm?.cancel();
    setState(() => _armed = false);
    farm.reset();
  }

  // Layar dibangun ulang setiap kali data peternakan berubah.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: farm, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final inv = [
      for (final p in products.keys) (p, products[p]!.label, farm.stock[p]!),
      for (final f in feeds.keys) (f, feeds[f]!.label, farm.feed[f]!),
      ('coin', 'Koin', farm.coins),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionTitle('Isi lumbung'),
      GridView.count(
        crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.05,
        children: [
          for (final (key, label, n) in inv)
            Box(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                icon(key, size: 30),
                Text(fmt(n), style: display(19)),
                Text(label, style: const TextStyle(fontSize: 11.5, color: C.muted, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
              ]),
            ),
        ],
      ),
      const SectionTitle('Perluas kandang', trailing: 'Bayar pakai koin'),
      for (final k in kindOrder) Padding(padding: const EdgeInsets.only(bottom: 10), child: _PenRow(k)),
      const Padding(padding: EdgeInsets.only(bottom: 10), child: _PondRow()),
      const SectionTitle('Peralatan'),
      for (final t in tools.keys) Padding(padding: const EdgeInsets.only(bottom: 10), child: _ToolRow(t)),
      const SectionTitle('Jalan level'),
      Box(
        child: Column(children: [
          for (final (lv, what) in _unlockPath())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(
                  width: 34, height: 24, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: farm.level >= lv ? const Color(0xFFC8F09A) : const Color(0xFFE8DCC0),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text('Lv $lv',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: farm.level >= lv ? C.okDark : C.muted)),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(what, style: const TextStyle(fontWeight: FontWeight.w700))),
                Icon(farm.level >= lv ? Icons.check_circle_rounded : Icons.lock_rounded,
                    size: 16, color: farm.level >= lv ? C.okDark : C.muted),
              ]),
            ),
        ]),
      ),
      const SectionTitle('Catatan peternakan'),
      Box(
        child: Column(children: [
          _Stat('Level', '${farm.level}  (${farm.xp}/${farm.xpNeed} XP)'),
          _Stat('Hari berjalan', '${farm.day}'),
          _Stat('Total hasil dipanen', fmt(farm.statHarvest)),
          _Stat('Total pendapatan', '${fmt(farm.statEarned)} koin'),
          _Stat('Jumlah ternak', '${farm.animals.length} ekor'),
          _Stat('Ikan di kolam', '${farm.fish.length} ekor'),
        ]),
      ),
      const SizedBox(height: 22),
      Center(
        child: TextButton(
          onPressed: _reset,
          style: TextButton.styleFrom(
            foregroundColor: C.low,
            backgroundColor: _armed ? const Color(0xFFFFA494) : C.cream,
            side: BorderSide(color: _armed ? const Color(0xFFB23A28) : C.creamEdge, width: 3),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(_armed ? 'Ketuk sekali lagi untuk menghapus semua kemajuan' : 'Mulai ulang peternakan',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
      ),
    ]);
  }

  List<(int, String)> _unlockPath() {
    final items = <(int, String)>[
      for (final k in kindOrder) (kinds[k]!.unlock, 'Boleh memelihara ${kinds[k]!.label}'),
      (pondUnlock, 'Kolam Ikan'),
      for (final k in fishOrder) (fishKinds[k]!.unlock, 'Boleh memelihara ikan ${fishKinds[k]!.label}'),
      for (final t in tools.values) (t.unlock, t.label),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    return items;
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(label, style: muted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
      );
}

class _PenRow extends StatelessWidget {
  const _PenRow(this.k);
  final String k;

  @override
  Widget build(BuildContext context) {
    final kind = kinds[k]!, open = farm.unlocked(k), cost = farm.capCost(k);
    return Box(
      child: Row(children: [
        Face(animal(k), w: 44, h: 44, pad: 5, locked: !open),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Kandang ${kind.label}', style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Kapasitas ${farm.cap(k)} ekor · +${kind.capStep} per perluasan', style: muted),
          ]),
        ),
        open
            ? Btn(
                label: '+${kind.capStep} · ${fmt(cost)}',
                lead: icon('coin'),
                expand: false,
                style: BtnStyle.primary,
                onTap: farm.coins >= cost ? () => farm.upgradePen(k) : null,
              )
            : LockNote(kind.unlock),
      ]),
    );
  }
}

class _PondRow extends StatelessWidget {
  const _PondRow();

  @override
  Widget build(BuildContext context) {
    final open = farm.pondOpen;
    return Box(
      child: Row(children: [
        Face(icon('kolam', size: 30), w: 44, h: 44, pad: 4, locked: !open),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Kolam Ikan', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('Kapasitas ${farm.pondCap} ekor · +$pondCapStep per perluasan', style: muted),
          ]),
        ),
        open
            ? Btn(
                label: '+$pondCapStep · ${fmt(penExpandCost)}',
                lead: icon('coin'),
                expand: false,
                style: BtnStyle.primary,
                onTap: farm.coins >= penExpandCost ? farm.upgradePond : null,
              )
            : const LockNote(pondUnlock),
      ]),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow(this.id);
  final String id;

  @override
  Widget build(BuildContext context) {
    final tl = tools[id]!, open = farm.toolUnlocked(id);
    return Box(
      child: Row(children: [
        Face(icon(tl.icon, size: 28), w: 44, h: 44, pad: 8, locked: !open),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tl.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text(tl.desc, style: muted),
          ]),
        ),
        const SizedBox(width: 8),
        if (farm.owned[id]!)
          const Tag('Terpasang', Tone.ok)
        else if (!open)
          LockNote(tl.unlock)
        else
          Btn(
            label: fmt(tl.price),
            lead: icon('coin'),
            expand: false,
            style: BtnStyle.primary,
            onTap: farm.coins >= tl.price ? () => farm.buyTool(id) : null,
          ),
      ]),
    );
  }
}
