import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/localization_service.dart';

class GameItem {
  double x;
  double y;
  bool isGood;
  IconData icon;
  Color color;

  GameItem({
    required this.x,
    required this.y,
    required this.isGood,
    required this.icon,
    required this.color,
  });
}

class DinoGame extends StatefulWidget {
  const DinoGame({super.key});

  @override
  State<DinoGame> createState() => _DinoGameState();
}

class _DinoGameState extends State<DinoGame> {
  static const double playerWidth = 80.0;
  double playerX = 0;
  List<GameItem> items = [];
  int score = 0;
  bool isGameOver = false;
  Timer? gameTimer;
  final Random random = Random();

  final List<IconData> goodIcons = [Icons.restaurant, Icons.apple, Icons.egg, Icons.bakery_dining];
  final List<IconData> badIcons = [Icons.delete_outline, Icons.bug_report, Icons.block, Icons.warning_amber];

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    gameTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (!isGameOver) _update();
    });
  }

  void _update() {
    setState(() {
      if (random.nextInt(30) == 0) {
        bool isGood = random.nextDouble() > 0.3;
        items.add(GameItem(
          x: random.nextDouble() * 2 - 1,
          y: -1.1,
          isGood: isGood,
          icon: isGood ? goodIcons[random.nextInt(goodIcons.length)] : badIcons[random.nextInt(badIcons.length)],
          color: isGood ? Colors.teal : Colors.redAccent,
        ));
      }

      List<GameItem> nextItems = [];
      for (var item in items) {
        item.y += 0.05;
        if (item.y > 0.75 && item.y < 0.95 && (item.x - playerX).abs() < 0.3) {
          if (item.isGood) score += 10;
          else score = max(0, score - 5);
          continue; 
        }
        if (item.y < 1.1) nextItems.add(item);
      }
      items = nextItems;
    });
  }

  void _handlePointerEvent(PointerEvent details) {
    if (isGameOver) return;
    RenderBox? getBox = context.findRenderObject() as RenderBox?;
    if (getBox == null) return;
    var localPos = getBox.globalToLocal(details.position);
    var xPercent = (localPos.dx / getBox.size.width) * 2 - 1;
    setState(() {
      playerX = xPercent.clamp(-0.9, 0.9);
    });
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = Provider.of<LocalizationService>(context);
    final theme = Theme.of(context);

    return Listener(
      onPointerDown: _handlePointerEvent,
      onPointerMove: _handlePointerEvent,
      child: Container(
        height: 220,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.05,
                child: GridView.count(crossAxisCount: 10, children: List.generate(100, (i) => const Icon(Icons.grid_3x3))),
              ),
            ),
            ...items.map((item) => Align(
              alignment: Alignment(item.x, item.y),
              child: Icon(item.icon, size: 28, color: item.color),
            )),
            Align(
              alignment: Alignment(playerX, 0.9),
              child: Container(
                width: playerWidth,
                height: 45,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4))],
                ),
                child: const Icon(Icons.shopping_basket, color: Colors.white, size: 28),
              ),
            ),
            Positioned(
              top: 15,
              left: 15,
              child: Text(
                '${loc.translate('score')}: $score',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: theme.colorScheme.primary),
              ),
            ),
            const Align(
              alignment: Alignment(0, -0.8),
              child: Text('ПОЙМАЙ ПОСТАВЩИКА', style: TextStyle(fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
