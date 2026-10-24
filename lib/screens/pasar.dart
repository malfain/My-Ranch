import 'package:flutter/material.dart';

import '../game/art.dart';
import '../game/data.dart';
import '../game/state.dart';
import '../ui_state.dart';
import '../widgets/common.dart';

class PasarScreen extends StatelessWidget {
  const PasarScreen({super.key});

  // Layar dibangun ulang setiap kali data peternakan berubah.
  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: Listenable.merge([farm, ui]), builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionTitle('Beli hewan', trailing: 'Bayar pakai koin'),
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .68,
        children: [for (final k in kindOrder) _AnimalShop(k)],
      ),
      SectionTitle('Beli bibit ikan', trailing: 'Kolam ${farm.fish.length}/${farm.pondCap}'),
      for (final k in fishOrder) Padding(padding: const EdgeInsets.only(bottom: 10), child: _FishShop(k)),
      SectionTitle('Jual hasil ternak', trailing: 'Harga hari ke-${farm.day}'),
      for (final p in products.keys) Padding(padding: const EdgeInsets.only(bottom: 10), child: _SellRow(p)),
      const SectionTitle('Beli pakan'),
      for (final f in feeds.keys) Padding(padding: const EdgeInsets.only(bottom: 10), child: _FeedRow(f)),
    ]);
  }
}

class _AnimalShop extends StatelessWidget {
  const _AnimalShop(this.k);
  final String k;

  @override
  Widget build(BuildContext context) {
    final kind = kinds[k]!;
    final open = farm.unlocked(k);
    final full = farm.count(k) >= farm.cap(k);
    final canPay = farm.coins >= kind.price;
    return Box(
      locked: !open,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Face(Center(child: animal(k)), w: double.infinity, h: 70, pad: 8, locked: !open, tint: kindTint(k), edge: kindEdge(k)),
        const SizedBox(height: 8),
        Text(kind.label, style: display(19, color: open ? C.ink : C.lockText)),
        Text('${products[kind.product]!.label} tiap ±${kind.time} dtk', style: muted),
        Text('Makan ${feeds[kind.feed]!.label.toLowerCase()}', style: muted),
        if (kind.canBreed) Text('Bisa beranak · dewasa laku ${fmt(kind.sellPrice)}', style: muted.copyWith(color: C.okDark)),
        const Spacer(),
        if (!open)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(color: const Color(0xFFE8DCC0), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFA8916A), width: 2)),
            child: Column(children: [
              LockNote(kind.unlock),
              Text('Harga ${fmt(kind.price)} koin', style: const TextStyle(fontSize: 11, color: C.muted, fontWeight: FontWeight.w700)),
            ]),
          )
        else ...[
          Text(full ? 'Kandang penuh (${farm.count(k)}/${farm.cap(k)})' : 'Kandang ${farm.count(k)}/${farm.cap(k)}',
              style: muted.copyWith(color: full ? C.low : C.muted)),
          const SizedBox(height: 6),
          Row(children: [
            full
                ? Btn(
                    label: 'Perluas · ${fmt(farm.capCost(k))}',
                    lead: icon('coin'),
                    style: BtnStyle.gold,
                    onTap: farm.coins >= farm.capCost(k) ? () => farm.upgradePen(k) : null,
                  )
                : Btn(
                    label: 'Beli · ${fmt(kind.price)}',
                    lead: icon('coin'),
                    style: BtnStyle.primary,
                    onTap: canPay ? () => farm.buy(k) : null,
                  ),
          ]),
        ],
      ]),
    );
  }
}

class _FishShop extends StatelessWidget {
  const _FishShop(this.k);
  final String k;

  @override
  Widget build(BuildContext context) {
    final fk = fishKinds[k]!;
    final open = farm.fishUnlocked(k);
    final full = farm.fish.length >= farm.pondCap;
    return Box(
      locked: !open,
      child: Row(children: [
        Face(svg(fishArt[k]!), w: 54, h: 44, pad: 4, locked: !open, tint: const Color(0xFFB9E6FF), edge: const Color(0xFF2F8AC9)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ikan ${fk.label}', style: TextStyle(fontWeight: FontWeight.w800, color: open ? C.ink : C.lockText)),
            Text('Panen ±${fk.growTime} dtk · laku ${fmt(farm.price(fk.product))} koin', style: muted),
            if (open && full) Text('Kolam penuh. Perluas di Gudang.', style: muted.copyWith(color: C.low)),
          ]),
        ),
        const SizedBox(width: 8),
        if (!open)
          LockNote(fk.unlock)
        else
          Btn(
            label: 'Beli · ${fmt(fk.price)}',
            lead: icon('coin'),
            expand: false,
            style: BtnStyle.primary,
            onTap: !full && farm.coins >= fk.price ? () => farm.buyFish(k) : null,
          ),
      ]),
    );
  }
}

class _SellRow extends StatelessWidget {
  const _SellRow(this.p);
  final String p;

  @override
  Widget build(BuildContext context) {
    final pr = products[p]!, m = farm.market[p]!;
    final (trend, color) = m > 1.04 ? ('▲ naik', C.okDark) : m < .96 ? ('▼ turun', C.low) : ('• normal', C.muted);
    final has = farm.stock[p]! > 0;
    return Box(
      child: Row(children: [
        Face(icon(p, size: 28), w: 44, h: 44, pad: 8),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(pr.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text.rich(TextSpan(style: muted, children: [
              TextSpan(text: 'Stok ${fmt(farm.stock[p]!)} · ${fmt(farm.price(p))} koin/${pr.unit} '),
              TextSpan(text: trend, style: TextStyle(color: color)),
            ])),
          ]),
        ),
        Btn(label: 'Jual 1', expand: false, onTap: has ? () => farm.sell(p) : null),
        const SizedBox(width: 6),
        Btn(label: 'Semua', expand: false, style: BtnStyle.primary, onTap: has ? () => farm.sell(p, all: true) : null),
      ]),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow(this.f);
  final String f;

  @override
  Widget build(BuildContext context) {
    final fd = feeds[f]!, cost = fd.price * fd.pack;
    return Box(
      child: Row(children: [
        Face(icon(f, size: 28), w: 44, h: 44, pad: 8),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(fd.label, style: const TextStyle(fontWeight: FontWeight.w800)),
            Text('Untuk ${fd.forWho} · stok ${fmt(farm.feed[f]!)} ${fd.unit}', style: muted),
          ]),
        ),
        Btn(
          label: '+${fd.pack} · $cost',
          lead: icon('coin'),
          expand: false,
          style: BtnStyle.primary,
          onTap: farm.coins >= cost ? () => farm.buyFeed(f) : null,
        ),
      ]),
    );
  }
}
