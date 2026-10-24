import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data.dart';

final _r = Random();
double rnd(double a, double b) => a + _r.nextDouble() * (b - a);

class Animal {
  Animal({
    required this.id,
    required this.kind,
    required this.name,
    this.food = 85,
    this.water = 85,
    this.joy = 70,
    this.prog = 0,
    this.ready = false,
    this.adult = true,
    this.grow = 1,
    this.preg = -1,
  });

  final String id;
  final String kind;
  final String name;
  double food, water, joy, prog;
  bool ready;

  /// Anak belum menghasilkan apa-apa dan belum bisa dijual. [grow] 0..1 menuju dewasa.
  bool adult;
  double grow;

  /// Kemajuan hamil 0..1; -1 = tidak hamil.
  double preg;
  bool get pregnant => preg >= 0;

  AnimalKind get k => kinds[kind]!;

  Map<String, dynamic> toJson() => {
        'id': id, 'kind': kind, 'name': name, 'food': food,
        'water': water, 'joy': joy, 'prog': prog, 'ready': ready,
        'adult': adult, 'grow': grow, 'preg': preg,
      };

  factory Animal.fromJson(Map<String, dynamic> j) => Animal(
        id: j['id'], kind: j['kind'], name: j['name'],
        food: (j['food'] as num).toDouble(), water: (j['water'] as num).toDouble(),
        joy: (j['joy'] as num).toDouble(), prog: (j['prog'] as num).toDouble(),
        ready: j['ready'] == true,
        adult: j['adult'] != false,
        grow: (j['grow'] as num?)?.toDouble() ?? 1,
        preg: (j['preg'] as num?)?.toDouble() ?? -1,
      );
}

/// Ikan di kolam. [grow] 0..1 dari bibit sampai siap panen.
class Fish {
  Fish({required this.id, required this.kind, this.food = 85, this.grow = 0});

  final String id;
  final String kind;
  double food, grow;
  bool get ready => grow >= 1;

  FishKind get k => fishKinds[kind]!;

  Map<String, dynamic> toJson() => {'id': id, 'kind': kind, 'food': food, 'grow': grow};

  factory Fish.fromJson(Map<String, dynamic> j) => Fish(
        id: j['id'], kind: j['kind'],
        food: ((j['food'] as num?)?.toDouble() ?? 85).clamp(0, 100),
        grow: ((j['grow'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      );
}

/// Isi awal pakan dan stok; kunci lain mulai dari 0.
const _feed0 = {'rumput': 20, 'biji': 30};
const _stock0 = {'telur': 2};

enum Tone { ok, warn, bad, gold, plain }

/// Efek melayang di atas hewan (ikon + teks), misalnya "+1 susu".
class PopEvent {
  PopEvent(this.animalId, this.icon, [this.text = '']);
  final String animalId;
  final String icon;
  final String text;
}

class FarmState extends ChangeNotifier {
  static const _saveKey = 'ranch-lembah-hijau-v1';

  int coins = 150, xp = 0, level = 1, day = 1, temp = 30;
  double t = dayLength * .05, wxT = 70;
  String weather = 'cerah';
  Map<String, int> feed = {for (final f in feeds.keys) f: _feed0[f] ?? 0};
  Map<String, int> stock = {for (final p in products.keys) p: _stock0[p] ?? 0};
  Map<String, double> market = {for (final p in products.keys) p: 1.0};
  Map<String, int> caps = {for (final k in kinds.keys) k: 0};
  Map<String, bool> owned = {for (final t in tools.keys) t: false};
  int statHarvest = 0, statEarned = 0;
  List<Animal> animals = [];
  List<Fish> fish = [];
  int pondCaps = 0;

  /// Kejernihan air kolam 0..100. Di bawah 35 ikan tumbuh setengah kecepatan.
  double pondClean = 100;

  final _pops = StreamController<PopEvent>.broadcast();
  final _toasts = StreamController<String>.broadcast();
  Stream<PopEvent> get pops => _pops.stream;
  Stream<String> get toasts => _toasts.stream;

  Timer? _timer;
  SharedPreferences? _prefs;
  int _ticks = 0;

  // ---------- turunan ----------
  int cap(String k) => kinds[k]!.cap0 + caps[k]! * kinds[k]!.capStep;
  int capCost(String k) => kinds[k]!.capCost;
  int count(String k) => animals.where((a) => a.kind == k).length;
  int price(String p) => (products[p]!.base * market[p]!).round();
  int get xpNeed => 30 + level * 20;
  bool unlocked(String k) => level >= kinds[k]!.unlock;
  bool toolUnlocked(String id) => level >= tools[id]!.unlock;
  int get pondCap => pondCap0 + pondCaps * pondCapStep;
  bool get pondOpen => level >= pondUnlock;
  bool fishUnlocked(String k) => pondOpen && level >= fishKinds[k]!.unlock;
  Animal? byId(String id) {
    for (final a in animals) {
      if (a.id == id) return a;
    }
    return null;
  }

  double get hour => (6 + t / dayLength * 24) % 24;
  String get clock {
    final h = hour, hh = h.floor(), mm = ((h - hh) * 6).floor() * 10;
    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  double get darkness {
    final h = hour;
    if (h >= 19 || h < 4.5) return .42;
    if (h >= 17) return (h - 17) / 2 * .42;
    if (h < 6) return (6 - h) / 1.5 * .42;
    return 0;
  }

  String get greeting {
    final h = hour;
    final p = h < 4 ? 'malam' : h < 11 ? 'pagi' : h < 15 ? 'siang' : h < 18 ? 'sore' : 'malam';
    return 'Selamat $p, Peternak';
  }

  int health(Animal a) => ((a.food + a.water + a.joy) / 3).round();
  int get farmHealth => animals.isEmpty
      ? 0
      : (animals.fold<int>(0, (s, a) => s + health(a)) / animals.length).round();

  (String, Tone) mood(Animal a) {
    if (a.ready) return ('Siap panen', Tone.gold);
    if (a.food < 15) return ('Kelaparan', Tone.bad);
    if (a.water < 15) return ('Kehausan', Tone.bad);
    if (a.food < 35) return ('Lapar', Tone.warn);
    if (a.water < 35) return ('Haus', Tone.warn);
    if (a.joy < 30) return ('Bosan', Tone.warn);
    return ('Sehat', Tone.ok);
  }

  /// Lapar, haus, atau bosan, termasuk hewan yang hasilnya sudah siap dipanen.
  bool needsCare(Animal a) => a.food < 35 || a.water < 35 || a.joy < 30;

  // ---------- simulasi ----------
  Animal _newAnimal(String kind) {
    final used = animals.map((a) => a.name).toList();
    final names = kinds[kind]!.names;
    var name = names.firstWhere((n) => !used.contains(n), orElse: () => '');
    if (name.isEmpty) name = '${names[_r.nextInt(names.length)]} ${used.length + 1}';
    return Animal(
      id: 'a${_r.nextInt(1 << 31).toRadixString(36)}',
      kind: kind, name: name, prog: _r.nextDouble() * .4,
    );
  }

  void _fresh() {
    coins = 150; xp = 0; level = 1; day = 1; t = dayLength * .05;
    weather = 'cerah'; temp = 30; wxT = 70;
    feed = {for (final f in feeds.keys) f: _feed0[f] ?? 0};
    stock = {for (final p in products.keys) p: _stock0[p] ?? 0};
    market = {for (final p in products.keys) p: 1.0};
    caps = {for (final k in kinds.keys) k: 0};
    owned = {for (final t in tools.keys) t: false};
    statHarvest = 0; statEarned = 0;
    animals = [];
    fish = []; pondCaps = 0; pondClean = 100;
    for (final k in ['ayam', 'ayam']) {
      animals.add(_newAnimal(k));
    }
  }

  bool _rollWeather() {
    final prev = weather, r = _r.nextDouble();
    weather = r < .5 ? 'cerah' : r < .78 ? 'berawan' : 'hujan';
    final tr = weatherTemps[weather]!;
    temp = rnd(tr[0].toDouble(), tr[1].toDouble()).round();
    wxT = rnd(50, 95);
    return prev != weather;
  }

  void sim(double dt, {bool live = true}) {
    t += dt;
    if (t >= dayLength) {
      t -= dayLength;
      day++;
      market.updateAll((_, m) => (m * rnd(.86, 1.16)).clamp(.7, 1.45));
      if (live) _toasts.add('Hari ke-$day dimulai. Harga pasar berubah.');
    }
    wxT -= dt;
    if (wxT <= 0 && _rollWeather() && live && weather == 'hujan') {
      _toasts.add('Hujan turun. Ternak minum air hujan.');
    }
    final rain = weather == 'hujan', hot = weather == 'cerah' && temp >= 31;
    for (final a in [...animals]) {
      final k = a.k;
      a.food = max(0, a.food - k.hunger * dt);
      a.water = rain
          ? min(100, a.water + 6 * dt)
          : max(0, a.water - k.thirst * dt * (hot ? 1.25 : 1));
      if (owned['pompa']! && a.water < 70) a.water = 100;
      if (owned['lumbung']! && a.food < 35 && feed[k.feed]! > 0) {
        feed[k.feed] = feed[k.feed]! - 1;
        a.food = min(100, a.food + feedGain);
      }
      final starving = a.food < 15 || a.water < 15;
      a.joy = max(0, a.joy - (starving ? .8 : .22) * dt);
      if (!a.adult) {
        if (!starving) a.grow += dt / k.growTime;
        if (a.grow >= 1) {
          a.adult = true;
          a.grow = 1;
          if (live) _toasts.add('Anak ${k.label.toLowerCase()} ${a.name} sudah dewasa.');
        }
        continue;
      }
      if (a.pregnant && !starving && a.preg < 1) a.preg = min(1, a.preg + dt / k.breedTime);
      if (a.preg >= 1) _giveBirth(a, live);
      if (!a.ready && !starving) {
        // Hewan yang cukup senang (±70) memanen tepat sesuai waktunya.
        a.prog += dt / k.time * (.825 + a.joy / 400);
        if (a.prog >= 1) {
          a.prog = 1;
          a.ready = true;
        }
      }
      if (a.ready && owned['keranjang']!) collect(a, quiet: !live);
    }
    // Air kolam makin keruh selama ada ikan; hujan menyegarkannya.
    if (fish.isNotEmpty) pondClean = max(0, pondClean - .2 * dt);
    if (rain) pondClean = min(100, pondClean + .5 * dt);
    var auto = false;
    for (final f in [...fish]) {
      final k = f.k;
      f.food = max(0, f.food - k.hunger * dt);
      if (owned['lumbung']! && f.food < 35 && feed['pelet']! > 0) {
        feed['pelet'] = feed['pelet']! - 1;
        f.food = feedGain;
      }
      // Ikan kelaparan berhenti tumbuh, tapi tidak mati.
      if (!f.ready && f.food >= 15) f.grow = min(1, f.grow + dt / k.growTime * (pondClean >= 35 ? 1 : .5));
      if (f.ready && owned['keranjang']! && _takeFish(f, pop: live)) auto = true;
    }
    if (auto) _changed(save: true);
  }

  void _addXp(int n) {
    xp += n;
    while (xp >= xpNeed) {
      xp -= xpNeed;
      level++;
      final bonus = level * 40;
      coins += bonus;
      final opened = [
        for (final k in kindOrder)
          if (kinds[k]!.unlock == level) kinds[k]!.label,
        if (pondUnlock == level) 'Kolam Ikan',
        for (final k in fishOrder)
          if (fishKinds[k]!.unlock == level) 'Ikan ${fishKinds[k]!.label}',
        for (final t in tools.values)
          if (t.unlock == level) t.label,
      ];
      _toasts.add('Naik ke Level $level. Bonus ${fmt(bonus)} koin.'
          '${opened.isNotEmpty ? ' Terbuka: ${opened.join(', ')}.' : ''}');
    }
  }

  final _waitingRoom = <String>{};

  void _giveBirth(Animal mother, bool live) {
    final k = mother.k;
    if (count(k.id) >= cap(k.id)) {
      // Menunggu sampai kandang diperluas; beri tahu sekali saja.
      if (live && _waitingRoom.add(mother.id)) {
        _toasts.add('${mother.name} siap melahirkan, tapi kandang ${k.label.toLowerCase()} penuh. Perluas di Gudang.');
      }
      return;
    }
    _waitingRoom.remove(mother.id);
    mother.preg = -1;
    final baby = _newAnimal(k.id)
      ..adult = false
      ..grow = 0
      ..prog = 0
      ..food = 90
      ..water = 90
      ..joy = 80;
    animals.add(baby);
    _addXp(k.xp);
    if (live) {
      _toasts.add('${mother.name} melahirkan anak ${k.label.toLowerCase()} bernama ${baby.name}.');
      _pops.add(PopEvent(mother.id, 'hati'));
    }
    _changed(save: true);
  }

  /// Alasan hewan belum bisa dikawinkan, atau null kalau bisa.
  String? breedBlock(Animal a) {
    if (!a.k.canBreed) return 'Hewan ini tidak bisa beranak.';
    if (!a.adult) return '${a.name} masih anak-anak.';
    if (a.pregnant) return '${a.name} sedang hamil.';
    if (a.food < 35 || a.water < 35) return 'Beri ${a.name} makan dan minum dulu.';
    if (a.joy < 50) return '${a.name} kurang senang. Elus dulu.';
    if (count(a.kind) >= cap(a.kind)) return 'Kandang ${a.k.label.toLowerCase()} penuh. Perluas di Gudang.';
    return null;
  }

  void breed(Animal a) {
    final why = breedBlock(a);
    if (why != null) {
      _toasts.add(why);
      return;
    }
    a.preg = 0;
    _pops.add(PopEvent(a.id, 'hati'));
    _toasts.add('${a.name} sedang hamil. Anaknya lahir sekitar ${(a.k.breedTime / 60).round()} menit lagi.');
    _changed(save: true);
  }

  /// Alasan hewan belum bisa dijual, atau null kalau bisa.
  String? sellBlock(Animal a) {
    if (!a.k.canSell) return '${a.k.label} tidak bisa dijual.';
    if (!a.adult) return '${a.name} masih anak-anak.';
    if (a.pregnant) return 'Tunggu ${a.name} melahirkan dulu.';
    return null;
  }

  void sellAnimal(Animal a) {
    final why = sellBlock(a);
    if (why != null) {
      _toasts.add(why);
      return;
    }
    // Hasil yang sudah siap ikut dipanen dulu supaya tidak hilang.
    if (a.ready) collect(a, quiet: true);
    animals.remove(a);
    coins += a.k.sellPrice;
    statEarned += a.k.sellPrice;
    _toasts.add('${a.name} terjual: +${fmt(a.k.sellPrice)} koin.');
    _changed(save: true);
  }

  // ---------- aksi pemain ----------
  int collect(Animal a, {bool quiet = false}) {
    if (!a.ready) return 0;
    final k = a.k;
    final n = (a.joy > 80 && _r.nextDouble() < .25) ? 2 : 1;
    stock[k.product] = stock[k.product]! + n;
    statHarvest += n;
    a.ready = false;
    a.prog = 0;
    _addXp(k.xp * n);
    if (!quiet) _pops.add(PopEvent(a.id, k.product, '+$n'));
    _changed();
    return n;
  }

  bool feedOne(Animal a, {bool quiet = false}) {
    final k = a.k;
    if (a.food >= 92) {
      if (!quiet) _toasts.add('${a.name} masih kenyang.');
      return false;
    }
    if (feed[k.feed]! < 1) {
      if (!quiet) _toasts.add('${feeds[k.feed]!.label} habis. Beli di Pasar.');
      return false;
    }
    feed[k.feed] = feed[k.feed]! - 1;
    a.food = min(100, a.food + feedGain);
    a.joy = min(100, a.joy + 3);
    _pops.add(PopEvent(a.id, k.feed));
    _changed();
    return true;
  }

  bool waterOne(Animal a, {bool quiet = false}) {
    if (a.water >= 95) {
      if (!quiet) _toasts.add('${a.name} tidak haus.');
      return false;
    }
    a.water = 100;
    _pops.add(PopEvent(a.id, 'air'));
    _changed();
    return true;
  }

  void pet(Animal a) {
    a.joy = min(100, a.joy + 12);
    _pops.add(PopEvent(a.id, 'hati'));
    _changed();
  }

  void tap(Animal a) => a.ready ? collect(a) : pet(a);

  /// Hewan yang dikenai tugas cepat; [only] membatasi ke jenis tertentu.
  Iterable<Animal> pick(List<String>? only) => only == null ? animals : animals.where((a) => only.contains(a.kind));

  void feedAll({List<String>? only}) {
    var n = 0;
    final short = <String>{};
    for (final a in pick(only)) {
      if (a.food >= 92) continue;
      if (feed[a.k.feed]! < 1) {
        short.add(feeds[a.k.feed]!.label);
      } else if (feedOne(a, quiet: true)) {
        n++;
      }
    }
    final s = short.join(' & ');
    _toasts.add(n > 0
        ? '$n ekor sudah diberi pakan.${short.isNotEmpty ? ' $s habis.' : ''}'
        : short.isNotEmpty
            ? '$s habis. Beli di Pasar.'
            : 'Semua ternak sudah kenyang.');
  }

  void waterAll({List<String>? only}) {
    var n = 0;
    for (final a in pick(only)) {
      if (waterOne(a, quiet: true)) n++;
    }
    _toasts.add(n > 0 ? '$n ekor sudah minum.' : 'Semua ternak tidak haus.');
  }

  void harvestAll({List<String>? only}) {
    final got = <String, int>{};
    for (final a in pick(only)) {
      if (a.ready) got.update(a.k.product, (v) => v + collect(a), ifAbsent: () => collect(a));
    }
    _toasts.add(got.isEmpty
        ? 'Belum ada yang siap dipanen.'
        : 'Dipanen: ${got.entries.map((e) => '${e.value} ${products[e.key]!.label.toLowerCase()}').join(', ')}.');
  }

  void buy(String kind) {
    final k = kinds[kind]!;
    if (!unlocked(kind)) {
      _toasts.add('${k.label} terbuka di Level ${k.unlock}.');
      return;
    }
    if (count(kind) >= cap(kind)) {
      _toasts.add('Kandang ${k.label.toLowerCase()} penuh. Perluas di Gudang.');
      return;
    }
    if (coins < k.price) {
      _toasts.add('Koin belum cukup.');
      return;
    }
    coins -= k.price;
    final a = _newAnimal(kind);
    animals.add(a);
    _toasts.add('${k.label} baru bernama ${a.name} masuk kandang.');
    _changed(save: true);
  }

  // ---------- kolam ikan ----------
  /// Ikan siap keluar dari kolam dan masuk stok. False kalau ikan sudah tidak di kolam.
  bool _takeFish(Fish f, {bool pop = true}) {
    if (!fish.remove(f)) return false;
    final k = f.k;
    stock[k.product] = stock[k.product]! + 1;
    statHarvest++;
    _addXp(k.xp);
    if (pop) _pops.add(PopEvent(f.id, k.product, '+1'));
    return true;
  }

  /// Panen semua ikan yang siap, atau hanya [one].
  void harvestFish({Fish? one}) {
    final got = <String, int>{};
    for (final f in one == null ? [...fish] : [one]) {
      // Ikan yang sudah dipanen (misalnya diketuk dua kali) dilewati.
      if (!f.ready || !_takeFish(f)) continue;
      got.update(f.k.product, (v) => v + 1, ifAbsent: () => 1);
    }
    if (got.isNotEmpty) _changed(save: true);
    _toasts.add(got.isEmpty
        ? 'Belum ada ikan yang siap dipanen.'
        : 'Dipanen: ${got.entries.map((e) => '${e.value} ${products[e.key]!.label.toLowerCase()}').join(', ')}.');
  }

  void buyFish(String kind) {
    final k = fishKinds[kind]!;
    if (!pondOpen) {
      _toasts.add('Kolam ikan terbuka di Level $pondUnlock.');
      return;
    }
    if (!fishUnlocked(kind)) {
      _toasts.add('Ikan ${k.label} terbuka di Level ${k.unlock}.');
      return;
    }
    if (fish.length >= pondCap) {
      _toasts.add('Kolam penuh. Perluas di Gudang.');
      return;
    }
    if (coins < k.price) {
      _toasts.add('Koin belum cukup.');
      return;
    }
    coins -= k.price;
    fish.add(Fish(id: 'f${_r.nextInt(1 << 31).toRadixString(36)}', kind: kind));
    _toasts.add('Bibit ${k.label.toLowerCase()} masuk kolam. Siap panen sekitar ${(k.growTime / 60).round()} menit lagi.');
    _changed(save: true);
  }

  void feedFish() {
    var n = 0, short = false;
    for (final f in fish) {
      if (f.food >= 92) continue;
      if (feed['pelet']! < 1) {
        short = true;
        break;
      }
      feed['pelet'] = feed['pelet']! - 1;
      f.food = feedGain;
      _pops.add(PopEvent(f.id, 'pelet'));
      n++;
    }
    _toasts.add(n > 0
        ? '$n ekor ikan sudah diberi pelet.${short ? ' Pelet habis.' : ''}'
        : short
            ? 'Pelet habis. Beli di Pasar.'
            : 'Semua ikan kenyang.');
    _changed();
  }

  void cleanPond() {
    if (pondClean >= 95) {
      _toasts.add('Air kolam masih jernih.');
      return;
    }
    pondClean = 100;
    _toasts.add('Kolam sudah dibersihkan. Airnya jernih lagi.');
    _changed(save: true);
  }

  void upgradePond() {
    const c = penExpandCost;
    if (coins < c) {
      _toasts.add('Butuh ${fmt(c)} koin untuk memperluas kolam. Koinmu ${fmt(coins)}.');
      return;
    }
    coins -= c;
    pondCaps++;
    _toasts.add('Kolam ikan kini muat $pondCap ekor.');
    _changed(save: true);
  }

  void buyFeed(String f) {
    final fd = feeds[f]!, cost = fd.price * fd.pack;
    if (coins < cost) {
      _toasts.add('Koin belum cukup.');
      return;
    }
    coins -= cost;
    feed[f] = feed[f]! + fd.pack;
    _toasts.add('+${fd.pack} ${fd.unit} ${fd.label.toLowerCase()}.');
    _changed();
  }

  void sell(String p, {bool all = false}) {
    final n = all ? stock[p]! : min(1, stock[p]!);
    if (n < 1) return;
    final got = n * price(p);
    stock[p] = stock[p]! - n;
    coins += got;
    statEarned += got;
    final pr = products[p]!;
    _toasts.add('Terjual $n ${pr.unit} ${pr.label.toLowerCase()}: +${fmt(got)} koin.');
    _changed();
  }

  void upgradePen(String k) {
    final c = capCost(k);
    if (coins < c) {
      _toasts.add('Butuh ${fmt(c)} koin untuk memperluas kandang. Koinmu ${fmt(coins)}.');
      return;
    }
    coins -= c;
    caps[k] = caps[k]! + 1;
    _toasts.add('Kandang ${kinds[k]!.label.toLowerCase()} kini muat ${cap(k)} ekor.');
    _changed(save: true);
  }

  void buyTool(String id) {
    final tl = tools[id]!;
    if (owned[id]!) return;
    if (!toolUnlocked(id)) {
      _toasts.add('${tl.label} terbuka di Level ${tl.unlock}.');
      return;
    }
    if (coins < tl.price) {
      _toasts.add('Koin belum cukup.');
      return;
    }
    coins -= tl.price;
    owned[id] = true;
    _toasts.add('${tl.label} terpasang.');
    _changed(save: true);
  }

  void reset() {
    _fresh();
    _toasts.add('Peternakan dimulai dari awal.');
    _changed(save: true);
  }

  void _changed({bool save = false}) {
    notifyListeners();
    if (save) this.save();
  }

  // ---------- simpan & muat ----------
  Map<String, dynamic> _toJson() => {
        'coins': coins, 'xp': xp, 'level': level, 'day': day, 't': t,
        'weather': weather, 'temp': temp, 'wxT': wxT, 'feed': feed,
        'stock': stock, 'market': market, 'caps': caps, 'owned': owned,
        'statHarvest': statHarvest, 'statEarned': statEarned,
        'animals': animals.map((a) => a.toJson()).toList(),
        'fish': fish.map((f) => f.toJson()).toList(), 'pondCaps': pondCaps, 'pondClean': pondClean,
        'saved': DateTime.now().millisecondsSinceEpoch,
      };

  Future<void> save() async {
    try {
      await _prefs?.setString(_saveKey, jsonEncode(_toJson()));
    } catch (_) {}
  }

  void _load() {
    try {
      final raw = _prefs?.getString(_saveKey);
      if (raw == null) return;
      final j = jsonDecode(raw) as Map<String, dynamic>;
      Map<String, V> merge<V>(Map<String, V> base, dynamic m, V Function(dynamic) cv) =>
          {...base, if (m is Map) for (final e in m.entries) e.key as String: cv(e.value)};
      coins = j['coins']; xp = j['xp']; level = j['level']; day = j['day'];
      t = (j['t'] as num).toDouble(); weather = j['weather']; temp = j['temp'];
      wxT = (j['wxT'] as num).toDouble();
      feed = merge(feed, j['feed'], (v) => (v as num).toInt());
      stock = merge(stock, j['stock'], (v) => (v as num).toInt());
      market = merge(market, j['market'], (v) => (v as num).toDouble());
      caps = merge(caps, j['caps'], (v) => (v as num).toInt());
      owned = merge(owned, j['owned'], (v) => v == true);
      statHarvest = j['statHarvest'] ?? 0;
      statEarned = j['statEarned'] ?? 0;
      animals = (j['animals'] as List).map((e) => Animal.fromJson(Map<String, dynamic>.from(e))).toList();
      // Save lama belum punya kolam.
      // Satu ikan rusak atau jenisnya tidak dikenal cukup dilewati, jangan sampai mengulang peternakan.
      fish = [];
      for (final e in (j['fish'] is List ? j['fish'] as List : const [])) {
        try {
          final f = Fish.fromJson(Map<String, dynamic>.from(e));
          if (fishKinds.containsKey(f.kind)) fish.add(f);
        } catch (_) {}
      }
      pondCaps = max(0, (j['pondCaps'] as num?)?.toInt() ?? 0);
      pondClean = ((j['pondClean'] as num?)?.toDouble() ?? 100).clamp(0, 100);
    } catch (_) {
      _fresh();
    }
  }

  Future<void> start() async {
    _fresh();
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (_) {}
    // Waktu tidak berjalan selama aplikasi ditutup: lanjut persis dari saat terakhir disimpan.
    _load();
    notifyListeners();
    resume();
  }

  bool get running => _timer != null;

  /// Waktu game berhenti, misalnya saat aplikasi ditutup atau tab disembunyikan.
  void pause() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    save();
  }

  void resume() {
    if (_timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      sim(1);
      notifyListeners();
      if (++_ticks % 5 == 0) save();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pops.close();
    _toasts.close();
    super.dispose();
  }
}

final farm = FarmState();
