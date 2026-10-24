import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_ranch/game/data.dart';
import 'package:my_ranch/game/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('fmt memakai titik sebagai pemisah ribuan', () {
    expect(fmt(1500), '1.500');
    expect(fmt(250), '250');
  });

  test('di awal hanya ayam yang terbuka', () {
    expect(kinds['ayam']!.unlock, 1);
    expect(kindOrder.where((k) => kinds[k]!.unlock <= 1), ['ayam']);
  });

  test('ayam bertelur dan mulai lapar sekitar 1 menit setelah dirawat penuh', () {
    final f = FarmState();
    final a = Animal(id: 'x', kind: 'ayam', name: 'Kukuk', food: 100, water: 100, joy: 70, prog: 0);
    f.animals = [a];
    f.weather = 'berawan';
    f.wxT = 9999;
    var readyAt = 0, hungryAt = 0;
    for (var s = 1; s <= 120; s++) {
      f.sim(1, live: false);
      if (readyAt == 0 && a.ready) readyAt = s;
      if (hungryAt == 0 && a.food < 35) hungryAt = s;
    }
    expect(readyAt, inInclusiveRange(55, 70));
    expect(hungryAt, inInclusiveRange(55, 65));
  });

  test('sapi hamil melahirkan anak, anaknya tumbuh dewasa', () {
    final f = FarmState();
    f.caps['sapi'] = 2;
    final ibu = Animal(id: 'ibu', kind: 'sapi', name: 'Mimi', food: 100, water: 100, joy: 90);
    f.animals = [ibu];
    f.weather = 'berawan';
    f.wxT = 99999;
    f.breed(ibu);
    expect(ibu.pregnant, isTrue);
    for (var s = 0; s < kinds['sapi']!.breedTime + 2; s++) {
      ibu.food = 100; ibu.water = 100;
      f.sim(1, live: false);
    }
    expect(f.animals.length, 2);
    final anak = f.animals.last;
    expect(anak.adult, isFalse);
    expect(f.sellBlock(anak), isNotNull);
    for (var s = 0; s < kinds['sapi']!.growTime + 2; s++) {
      anak.food = 100; anak.water = 100;
      f.sim(1, live: false);
    }
    expect(anak.adult, isTrue);
    final before = f.coins;
    f.sellAnimal(anak);
    expect(f.coins, before + kinds['sapi']!.sellPrice);
    expect(f.animals.length, 1);
  });

  test('memperluas kandang selalu 1.000 koin', () {
    final f = FarmState();
    f.coins = 2500;
    final cap0 = f.cap('ayam');
    f.upgradePen('ayam');
    f.upgradePen('ayam');
    expect(f.coins, 500);
    expect(f.cap('ayam'), cap0 + 2 * kinds['ayam']!.capStep);
    f.upgradePen('ayam');
    expect(f.coins, 500);
  });

  test('tugas cepat kambing & sapi tidak menyentuh ayam', () {
    final f = FarmState();
    final ayam = Animal(id: 'a', kind: 'ayam', name: 'Kukuk', water: 10);
    final sapi = Animal(id: 's', kind: 'sapi', name: 'Mimi', water: 10);
    f.animals = [ayam, sapi];
    f.waterAll(only: const ['kambing', 'sapi']);
    expect(sapi.water, 100);
    expect(ayam.water, 10);
  });

  /// Kolam dengan satu bibit lele dan kejernihan air [clean].
  (FarmState, Fish) kolam({double clean = 100}) {
    final f = FarmState()
      ..level = pondUnlock
      ..weather = 'berawan'
      ..wxT = 99999
      ..pondClean = clean;
    final ikan = Fish(id: 'i', kind: 'lele');
    f.fish = [ikan];
    return (f, ikan);
  }

  test('lele siap panen sekitar 120 dtk bila kenyang dan air jernih', () {
    final (f, ikan) = kolam();
    var readyAt = 0;
    for (var s = 1; s <= 150 && readyAt == 0; s++) {
      ikan.food = 100;
      f.sim(1, live: false);
      if (ikan.ready) readyAt = s;
    }
    expect(readyAt, inInclusiveRange(118, 122));
    expect(f.pondClean, lessThan(100));
  });

  test('lele tumbuh setengah kecepatan di air kotor dan berhenti saat kelaparan', () {
    final (kotor, a) = kolam(clean: 20);
    final (lapar, b) = kolam();
    for (var s = 0; s < 60; s++) {
      a.food = 100;
      b.food = 0;
      kotor.sim(1, live: false);
      lapar.sim(1, live: false);
    }
    expect(a.grow, closeTo(.25, .01));
    expect(b.grow, 0);
  });

  test('panen ikan menambah stok dan mengeluarkan ikan dari kolam', () {
    final (f, ikan) = kolam();
    ikan.grow = 1;
    f.harvestFish();
    expect(f.stock['ikanLele'], 1);
    expect(f.fish, isEmpty);
    expect(f.statHarvest, 1);
  });

  test('ikan yang diketuk dua kali hanya dipanen sekali', () {
    final (f, ikan) = kolam();
    ikan.grow = 1;
    f.harvestFish(one: ikan);
    f.harvestFish(one: ikan);
    expect(f.stock['ikanLele'], 1);
    expect(f.statHarvest, 1);
  });

  test('beli bibit ikan menghormati level, kapasitas, dan koin', () {
    final f = FarmState()..coins = 1000;
    f.buyFish('lele');
    expect(f.fish, isEmpty);
    f.level = pondUnlock;
    f.buyFish('gurame');
    expect(f.fish, isEmpty);
    for (var i = 0; i < pondCap0 + 1; i++) {
      f.buyFish('lele');
    }
    expect(f.fish.length, pondCap0);
    expect(f.coins, 1000 - pondCap0 * fishKinds['lele']!.price);
    f.coins = penExpandCost;
    f.upgradePond();
    expect(f.pondCap, pondCap0 + pondCapStep);
    f.coins = 10;
    f.buyFish('lele');
    expect(f.fish.length, pondCap0);
  });

  test('simpan & muat menyimpan ikan; save lama tanpa kolam tetap termuat', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final a = FarmState();
    await a.start();
    a.pause();
    a.level = 4;
    a.fish = [Fish(id: 'i', kind: 'nila', food: 50, grow: .4)];
    a.pondCaps = 1;
    a.pondClean = 60;
    await a.save();
    final b = FarmState();
    await b.start();
    b.pause();
    expect(b.level, 4);
    expect(b.fish.single.kind, 'nila');
    expect(b.fish.single.grow, closeTo(.4, 1e-9));
    expect(b.pondCaps, 1);
    expect(b.pondClean, 60);

    SharedPreferences.setMockInitialValues({
      'ranch-lembah-hijau-v1': jsonEncode({
        'coins': 777, 'xp': 5, 'level': 3, 'day': 9, 't': 10, 'weather': 'cerah', 'temp': 30, 'wxT': 50,
        'feed': {'rumput': 5, 'biji': 6}, 'stock': {'susu': 1, 'telur': 3, 'telurBebek': 0, 'susuKambing': 0},
        'market': {}, 'caps': {}, 'owned': {}, 'statHarvest': 2, 'statEarned': 40,
        'animals': [Animal(id: 'x', kind: 'ayam', name: 'Kukuk').toJson()],
      }),
    });
    final c = FarmState();
    await c.start();
    c.pause();
    expect(c.coins, 777);
    expect(c.animals.length, 1);
    expect(c.fish, isEmpty);
    expect(c.pondClean, 100);
    expect(c.feed['pelet'], 0);
    expect(c.stock['ikanGurame'], 0);
  });

  test('data ikan rusak di save tidak mengulang peternakan', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({
      'ranch-lembah-hijau-v1': jsonEncode({
        'coins': 555, 'xp': 0, 'level': 5, 'day': 3, 't': 10, 'weather': 'cerah', 'temp': 30, 'wxT': 50,
        'animals': [],
        'fish': [
          {'id': 'a', 'kind': 'lele', 'food': 150, 'grow': 2},
          {'id': 'b', 'kind': 'hiu', 'food': 50, 'grow': .5},
          {'id': 'c', 'kind': 'nila', 'grow': .2},
        ],
        'pondCaps': -3, 'pondClean': 400,
      }),
    });
    final f = FarmState();
    await f.start();
    f.pause();
    expect(f.coins, 555);
    expect(f.level, 5);
    expect(f.fish.length, inInclusiveRange(1, 2));
    expect(f.fish.any((x) => x.kind == 'hiu'), isFalse);
    expect(f.fish.first.food, 100);
    expect(f.fish.first.grow, 1);
    expect(f.pondCaps, 0);
    expect(f.pondClean, 100);
  });
}
