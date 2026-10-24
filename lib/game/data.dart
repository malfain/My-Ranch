class AnimalKind {
  const AnimalKind({
    required this.id,
    required this.label,
    required this.price,
    required this.time,
    required this.product,
    required this.feed,
    required this.hunger,
    required this.thirst,
    required this.xp,
    required this.size,
    required this.aspect,
    required this.speed,
    required this.cap0,
    required this.capStep,
    required this.capCost,
    required this.names,
    required this.unlock,
    this.breedTime = 0,
    this.growTime = 0,
    this.sellPrice = 0,
  });

  final String id;
  final String label;
  final int price;

  /// Detik untuk menghasilkan satu produk.
  final int time;
  final String product;
  final String feed;
  /// Berkurangnya pakan dan air per detik. 65 / nilai ini = detik dari penuh sampai "Lapar".
  final double hunger;
  final double thirst;
  final int xp;

  /// Lebar sprite di padang (px) dan rasio tinggi/lebar gambarnya.
  final double size;
  final double aspect;

  /// Kecepatan jalan dalam persen lebar padang per detik.
  final double speed;
  final int cap0;
  final int capStep;
  final int capCost;
  final List<String> names;

  /// Level pemain yang dibutuhkan untuk memelihara hewan ini.
  final int unlock;

  /// Detik hamil sampai melahirkan; 0 = hewan ini tidak bisa beranak.
  final int breedTime;

  /// Detik anak tumbuh sampai dewasa.
  final int growTime;

  /// Harga jual hewan dewasa; 0 = tidak bisa dijual.
  final int sellPrice;

  bool get canBreed => breedTime > 0;
  bool get canSell => sellPrice > 0;
}

/// Ikan dibeli sebagai bibit, tumbuh di kolam, lalu dipanen utuh.
class FishKind {
  const FishKind({
    required this.id,
    required this.label,
    required this.price,
    required this.growTime,
    required this.product,
    required this.hunger,
    required this.xp,
    required this.unlock,
  });

  final String id;
  final String label;

  /// Harga satu bibit.
  final int price;

  /// Detik dari bibit sampai siap panen bila kenyang dan air jernih.
  final int growTime;
  final String product;
  /// Berkurangnya pakan per detik.
  final double hunger;
  final int xp;
  final int unlock;
}

class Product {
  const Product(this.label, this.base, this.unit);
  final String label;
  final int base;
  final String unit;
}

class Feed {
  const Feed(this.label, this.unit, this.price, this.pack, this.forWho);
  final String label;
  final String unit;
  final int price;
  final int pack;
  final String forWho;
}

class Tool {
  const Tool(this.label, this.desc, this.price, this.icon, this.unlock);
  final String label;
  final String desc;
  final int price;
  final String icon;
  final int unlock;
}

const kinds = <String, AnimalKind>{
  'sapi': AnimalKind(
    id: 'sapi', label: 'Sapi', price: 450, time: 120, product: 'susu', feed: 'rumput',
    hunger: .72, thirst: .72, xp: 40, size: 86, aspect: 84 / 110, speed: 3.2,
    cap0: 2, capStep: 2, capCost: penExpandCost,
    names: ['Mimi', 'Belang', 'Moli', 'Susi', 'Bunga', 'Coklat', 'Manis', 'Gendis', 'Pelangi', 'Kopi', 'Melati', 'Bintang'], unlock: 6,
    breedTime: 180, growTime: 240, sellPrice: 380,
  ),
  'ayam': AnimalKind(
    id: 'ayam', label: 'Ayam', price: 60, time: 60, product: 'telur', feed: 'biji',
    hunger: 1.08, thirst: 1.08, xp: 10, size: 42, aspect: 1, speed: 8,
    cap0: 4, capStep: 2, capCost: penExpandCost,
    names: ['Kukuk', 'Jago', 'Blorok', 'Ciki', 'Kriwil', 'Petok', 'Jambul', 'Tutul'], unlock: 1,
  ),
  'bebek': AnimalKind(
    id: 'bebek', label: 'Bebek', price: 90, time: 75, product: 'telurBebek', feed: 'biji',
    hunger: .93, thirst: 1.08, xp: 14, size: 48, aspect: 80 / 90, speed: 6,
    cap0: 4, capStep: 2, capCost: penExpandCost,
    names: ['Kwek', 'Wekwek', 'Pipit', 'Ijo', 'Ombak', 'Dodo', 'Cemplung', 'Lele'], unlock: 2,
  ),
  'kambing': AnimalKind(
    id: 'kambing', label: 'Kambing', price: 260, time: 90, product: 'susuKambing', feed: 'rumput',
    hunger: .81, thirst: .81, xp: 25, size: 68, aspect: 84 / 104, speed: 4.5,
    cap0: 3, capStep: 2, capCost: penExpandCost,
    names: ['Embek', 'Jenggot', 'Kiko', 'Gembul', 'Tanduk', 'Sule', 'Bimo', 'Lincah', 'Cimol', 'Dodol', 'Kancil', 'Poni'], unlock: 4,
    breedTime: 150, growTime: 180, sellPrice: 220,
  ),
};

const products = <String, Product>{
  'susu': Product('Susu Sapi', 110, 'liter'),
  'telur': Product('Telur Ayam', 15, 'butir'),
  'telurBebek': Product('Telur Bebek', 22, 'butir'),
  'susuKambing': Product('Susu Kambing', 60, 'liter'),
  'ikanLele': Product('Ikan Lele', 70, 'ekor'),
  'ikanNila': Product('Ikan Nila', 125, 'ekor'),
  'ikanGurame': Product('Ikan Gurame', 240, 'ekor'),
};

const feeds = <String, Feed>{
  'rumput': Feed('Rumput', 'ikat', 4, 10, 'Sapi & Kambing'),
  'biji': Feed('Biji-bijian', 'takar', 2, 10, 'Ayam & Bebek'),
  'pelet': Feed('Pelet Ikan', 'genggam', 3, 10, 'Ikan'),
};

const fishKinds = <String, FishKind>{
  'lele': FishKind(id: 'lele', label: 'Lele', price: 30, growTime: 120, product: 'ikanLele', hunger: 1.0, xp: 12, unlock: 3),
  'nila': FishKind(id: 'nila', label: 'Nila', price: 55, growTime: 180, product: 'ikanNila', hunger: .85, xp: 20, unlock: 5),
  'gurame': FishKind(id: 'gurame', label: 'Gurame', price: 110, growTime: 300, product: 'ikanGurame', hunger: .7, xp: 35, unlock: 7),
};

/// Urutan tampil ikan, dari yang paling awal terbuka.
const fishOrder = ['lele', 'nila', 'gurame'];

/// Kolam ikan terbuka di level ini; muat [pondCap0] ekor, +[pondCapStep] tiap perluasan ([penExpandCost]).
const pondUnlock = 3;
const pondCap0 = 4;
const pondCapStep = 2;

const tools = <String, Tool>{
  'pompa': Tool('Pompa Air Otomatis', 'Tempat minum ternak selalu terisi.', 500, 'air', 3),
  'lumbung': Tool('Pengumpan Otomatis', 'Memberi pakan dari stok saat ternak lapar.', 900, 'biji', 5),
  'keranjang': Tool('Keranjang Panen', 'Hasil ternak terkumpul sendiri saat siap.', 1500, 'panen', 7),
};

const weatherLabels = {'cerah': 'Cerah', 'berawan': 'Berawan', 'hujan': 'Hujan'};
const weatherTemps = {
  'cerah': [29, 32],
  'berawan': [25, 28],
  'hujan': [22, 24],
};

/// Harga setiap kali memperluas kandang, sama untuk semua hewan.
const penExpandCost = 1000;

/// Detik nyata untuk satu hari di game.
const dayLength = 240.0;
/// Sekali beri pakan langsung mengisi penuh.
const feedGain = 100.0;

String fmt(num n) {
  final s = n.floor().abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return (n < 0 ? '-' : '') + b.toString();
}

/// Urutan tampil hewan, dari yang paling awal terbuka.
const kindOrder = ['ayam', 'bebek', 'kambing', 'sapi'];
