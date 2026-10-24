import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'game/art.dart';
import 'game/data.dart';
import 'game/state.dart';
import 'screens/gudang.dart';
import 'screens/home.dart';
import 'screens/pasar.dart';
import 'screens/ternak.dart';
import 'ui_state.dart';
import 'widgets/common.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  farm.start();
  runApp(const RanchApp());
}

class RanchApp extends StatelessWidget {
  const RanchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peternakan Lembah Hijau',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: C.okDark, surface: C.grass),
        scaffoldBackgroundColor: C.grass,
        fontFamily: GoogleFonts.nunito(fontWeight: FontWeight.w800).fontFamily,
        textTheme: const TextTheme().apply(bodyColor: C.ink, displayColor: C.ink),
      ),
      home: const Shell(),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  StreamSubscription<String>? _toastSub;
  late final AppLifecycleListener _life;
  final _scroll = ScrollController();
  int _lastTab = 0;

  @override
  void initState() {
    super.initState();
    // Waktu game berhenti saat aplikasi atau tab tidak terlihat, dan lanjut saat dibuka lagi.
    _life = AppLifecycleListener(onHide: farm.pause, onShow: farm.resume);
    _toastSub = farm.toasts.listen((msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: WoodPanel(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14,
                  shadows: [Shadow(color: C.woodDeep, offset: Offset(0, 2)), Shadow(color: C.woodDeep, blurRadius: 2)],
                )),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          duration: const Duration(milliseconds: 2200),
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 110),
        ));
    });
    ui.addListener(() {
      if (ui.tab != _lastTab && _scroll.hasClients) _scroll.jumpTo(0);
      _lastTab = ui.tab;
    });
  }

  @override
  void dispose() {
    _toastSub?.cancel();
    _life.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: GrassBackground(
        child: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: ListenableBuilder(
                listenable: ui,
                builder: (context, _) => Column(children: [
                  const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 8), child: _Header()),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 130),
                      child: switch (ui.tab) {
                        0 => const HomeScreen(),
                        1 => const TernakScreen(),
                        2 => const PasarScreen(),
                        _ => const GudangScreen(),
                      },
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const _TabBar(),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: farm, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    return Row(children: [
      Container(
        width: 56, height: 56, padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE2A8), shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFFFFAF0), width: 4),
          boxShadow: const [
            BoxShadow(color: C.woodDark, spreadRadius: 3),
            BoxShadow(color: C.woodDeep, spreadRadius: 3, offset: Offset(0, 6)),
          ],
        ),
        child: svg(icons['farmer']!),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: WoodPanel(
          padding: const EdgeInsets.fromLTRB(12, 5, 12, 7),
          gap: 23,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedText(farm.greeting, size: 12, width: 2.4, stroke: C.woodDeep),
            const SizedBox(height: 2),
            const OutlinedText('Lembah Hijau', size: 21, width: 4),
          ]),
        ),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Container(
          padding: const EdgeInsets.fromLTRB(2, 2, 12, 2),
          decoration: BoxDecoration(
            color: C.woodDeep,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0xFF2E1704), width: 3),
          ),
          child: Row(children: [
            icon('coin', size: 26),
            const SizedBox(width: 6),
            Text(fmt(farm.coins), style: GoogleFonts.lilitaOne(fontSize: 17, color: Colors.white)),
          ]),
        ),
        const SizedBox(height: 6),
        Row(children: [
          SizedBox(
            width: 28, height: 28,
            child: Stack(alignment: Alignment.center, children: [
              icon('star', size: 28),
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text('${farm.level}', style: GoogleFonts.lilitaOne(fontSize: 10, color: C.woodDark)),
              ),
            ]),
          ),
          const SizedBox(width: 4),
          Container(
            width: 66, height: 14,
            decoration: BoxDecoration(
              color: C.woodDeep,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: const Color(0xFF2E1704), width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: (farm.xp / farm.xpNeed).clamp(0, 1),
                  heightFactor: 1,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF8FDC4A),
                      border: Border(top: BorderSide(color: Color(0x66FFFFFF), width: 3)),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ]),
      ]),
    ]);
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar();

  static const _tabs = [
    ('navHome', 'Beranda'),
    ('navPaw', 'Ternak'),
    ('navShop', 'Pasar'),
    ('navBox', 'Gudang'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ui,
      builder: (context, _) => SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 456),
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 16),
            child: WoodPanel(
              radius: 26,
              border: 4,
              gap: 28,
              padding: const EdgeInsets.all(8),
              child: Row(children: [
                for (var i = 0; i < _tabs.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(child: _TabItem(_tabs[i].$1, _tabs[i].$2, ui.tab == i, () => ui.go(i))),
                ],
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem(this.ico, this.label, this.on, this.onTap);
  final String ico, label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: on,
      label: label,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.fromLTRB(2, 6, 2, 7),
          decoration: BoxDecoration(
            gradient: on ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFFE680), Color(0xFFF5B315)]) : null,
            color: on ? null : const Color(0x473C1E05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? const Color(0xFFA8650A) : Colors.transparent, width: 3),
            boxShadow: on ? const [BoxShadow(color: Color(0xFFA8650A), offset: Offset(0, 4))] : null,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            icon(ico, size: 30),
            const SizedBox(height: 2),
            on
                ? Text(label, style: GoogleFonts.lilitaOne(fontSize: 14, color: const Color(0xFF5A2D00)))
                : OutlinedText(label, size: 14, width: 2.6, stroke: C.woodDeep),
          ]),
        ),
      ),
    );
  }
}
