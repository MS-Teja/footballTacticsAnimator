import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path; // Add to pubspec.yaml

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Football Tactics Animator',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      home: const TacticsBoardPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// MARK: - Data Models
class Player {
  String id;
  String name;
  Offset position;
  Color color;
  double radius = 20.0;
  Uint8List? imageData;
  Team team;

  Player({required this.name, required this.position, required this.color, this.imageData, required this.team}) : id = UniqueKey().toString();

  Player.clone(Player other)
      : id = other.id,
        name = other.name,
        position = other.position,
        color = other.color,
        radius = other.radius,
        imageData = other.imageData,
        team = other.team;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dx': position.dx,
    'dy': position.dy,
    'color': color.value,
    'radius': radius,
    'imageData': imageData != null ? base64Encode(imageData!) : null,
    'team': team.index,
  };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
    name: json['name'],
    position: Offset(json['dx'], json['dy']),
    color: Color(json['color']),
    imageData: json['imageData'] != null ? base64Decode(json['imageData']) : null,
    team: Team.values[json['team']],
  )..id = json['id']..radius = json['radius'];
}

class Ball {
  Offset position;
  Color color = Colors.white;
  double radius = 12.0;

  Ball({required this.position});

  Ball.clone(Ball other)
      : position = other.position,
        color = other.color,
        radius = other.radius;

  Map<String, dynamic> toJson() => {'dx': position.dx, 'dy': position.dy, 'color': color.value, 'radius': radius};
  factory Ball.fromJson(Map<String, dynamic> json) => Ball(position: Offset(json['dx'], json['dy']))..color = Color(json['color'])..radius = json['radius'];
}

class Arrow {
  Offset start;
  Offset end;
  Arrow({required this.start, required this.end});

  Map<String, dynamic> toJson() => {'startX': start.dx, 'startY': start.dy, 'endX': end.dx, 'endY': end.dy};
  factory Arrow.fromJson(Map<String, dynamic> json) => Arrow(start: Offset(json['startX'], json['startY']), end: Offset(json['endX'], json['endY']));
}

class Highlight {
  Rect rect;
  bool isOval;
  Highlight({required this.rect, this.isOval = false});

  Map<String, dynamic> toJson() => {'left': rect.left, 'top': rect.top, 'width': rect.width, 'height': rect.height, 'isOval': isOval};
  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(rect: Rect.fromLTWH(json['left'], json['top'], json['width'], json['height']), isOval: json['isOval']);
}

class BoardState {
  List<Player> players;
  Ball? ball;
  List<Arrow> arrows;
  List<Highlight> highlights;

  BoardState({required this.players, this.ball, required this.arrows, required this.highlights});

  BoardState.clone(BoardState other)
      : players = other.players.map((p) => Player.clone(p)).toList(),
        ball = other.ball != null ? Ball.clone(other.ball!) : null,
        arrows = List.from(other.arrows),
        highlights = List.from(other.highlights);

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'ball': ball?.toJson(),
    'arrows': arrows.map((a) => a.toJson()).toList(),
    'highlights': highlights.map((h) => h.toJson()).toList(),
  };

  factory BoardState.fromJson(Map<String, dynamic> json) => BoardState(
    players: (json['players'] as List).map((p) => Player.fromJson(p)).toList(),
    ball: json['ball'] != null ? Ball.fromJson(json['ball']) : null,
    arrows: (json['arrows'] as List).map((a) => Arrow.fromJson(a)).toList(),
    highlights: (json['highlights'] as List).map((h) => Highlight.fromJson(h)).toList(),
  );
}

class AnimationKeyframe {
  List<Player> players;
  Ball? ball;
  AnimationKeyframe({required this.players, this.ball});
}

enum Tool { none, arrow, highlightRect, highlightOval }
enum Team { home, away }

// MARK: - Main Page
class _TacticsBoardPageState extends State<TacticsBoardPage> with TickerProviderStateMixin {
  final GlobalKey _boardKey = GlobalKey();
  List<Player> players = [];
  Ball? ball;
  List<Arrow> arrows = [];
  List<Highlight> highlights = [];
  List<AnimationKeyframe> keyframes = [];

  Player? selectedPlayer;
  Tool activeTool = Tool.none;
  Offset? dragStart;
  Offset? currentDrag;

  int homePlayerCount = 0;
  int awayPlayerCount = 0;

  bool isAnimating = false;
  late AnimationController _animationController;

  bool isRecording = false;
  Timer? _recordTimer;
  final List<Uint8List> _recordedFrames = [];

  final List<BoardState> _history = [];
  final List<BoardState> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this);
    _saveState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  void _saveState() {
    _history.add(BoardState(
      players: players.map((p) => Player.clone(p)).toList(),
      ball: ball != null ? Ball.clone(ball!) : null,
      arrows: List.from(arrows),
      highlights: List.from(highlights),
    ));
    _redoStack.clear();
  }

  void _undo() {
    if (_history.length > 1) {
      setState(() {
        final currentState = _history.removeLast();
        _redoStack.add(currentState);
        final prevState = _history.last;
        players = prevState.players.map((p) => Player.clone(p)).toList();
        ball = prevState.ball != null ? Ball.clone(prevState.ball!) : null;
        arrows = List.from(prevState.arrows);
        highlights = List.from(prevState.highlights);
        selectedPlayer = null;
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        final nextState = _redoStack.removeLast();
        _history.add(nextState);
        players = nextState.players.map((p) => Player.clone(p)).toList();
        ball = nextState.ball != null ? Ball.clone(nextState.ball!) : null;
        arrows = List.from(nextState.arrows);
        highlights = List.from(nextState.highlights);
        selectedPlayer = null;
      });
    }
  }

  void _saveToFile() async {
    final state = BoardState(players: players, ball: ball, arrows: arrows, highlights: highlights);
    final jsonString = jsonEncode(state.toJson());

    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Please select an output file:',
      fileName: 'tactics.json',
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsString(jsonString);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project Saved!')));
    }
  }

  void _loadFromFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final jsonString = await file.readAsString();
      final jsonMap = jsonDecode(jsonString);
      final state = BoardState.fromJson(jsonMap);
      setState(() {
        players = state.players;
        ball = state.ball;
        arrows = state.arrows;
        highlights = state.highlights;
        _history.clear();
        _redoStack.clear();
        _saveState();
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project Loaded!')));
    }
  }

  void _addPlayer(Team team) {
    setState(() {
      final newPlayer = Player(
        name: team == Team.home ? "${++homePlayerCount}" : "${++awayPlayerCount}",
        position: Offset(team == Team.home ? 200 : 800, 300 + (players.length * 10)),
        color: team == Team.home ? Colors.red.shade700 : Colors.blue.shade700,
        team: team,
      );
      players.add(newPlayer);
    });
    _saveState();
  }

  void _addBall() {
    if (ball == null) {
      setState(() {
        ball = Ball(position: const Offset(500, 350));
      });
      _saveState();
    }
  }

  void _addKeyframe() {
    final clonedPlayers = players.map((p) => Player.clone(p)).toList();
    final clonedBall = ball != null ? Ball.clone(ball!) : null;
    setState(() {
      keyframes.add(AnimationKeyframe(players: clonedPlayers, ball: clonedBall));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Keyframe ${keyframes.length} added!'), duration: const Duration(seconds: 1)),
    );
  }

  void _playAnimation() {
    if (keyframes.length < 2 || isAnimating) return;
    final originalState = BoardState.clone(BoardState(players: players, ball: ball, arrows: arrows, highlights: highlights));
    int currentKeyframeIndex = 0;
    _animationController.duration = const Duration(seconds: 2);
    _animationController.reset();

    void runAnimationSegment() {
      final startFrame = keyframes[currentKeyframeIndex];
      final endFrame = keyframes[currentKeyframeIndex + 1];
      final animation = Tween<double>(begin: 0.0, end: 1.0).animate(_animationController);

      animation.addListener(() {
        setState(() {
          for (var i = 0; i < players.length; i++) {
            final startPlayer = startFrame.players.firstWhere((p) => p.id == players[i].id, orElse: () => players[i]);
            final endPlayer = endFrame.players.firstWhere((p) => p.id == players[i].id, orElse: () => players[i]);
            players[i].position = Offset.lerp(startPlayer.position, endPlayer.position, animation.value)!;
          }
          if (ball != null && startFrame.ball != null && endFrame.ball != null) {
            ball!.position = Offset.lerp(startFrame.ball!.position, endFrame.ball!.position, animation.value)!;
          }
        });
      });

      animation.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          currentKeyframeIndex++;
          if (currentKeyframeIndex < keyframes.length - 1) {
            _animationController.reset(); runAnimationSegment();
          } else {
            setState(() {
              isAnimating = false;
              players = originalState.players; ball = originalState.ball;
            });
          }
        }
      });

      setState(() {
        isAnimating = true;
        players = startFrame.players.map((p) => Player.clone(p)).toList();
        ball = startFrame.ball != null ? Ball.clone(startFrame.ball!) : null;
      });
      _animationController.forward();
    }
    runAnimationSegment();
  }

  void _toggleRecording() {
    setState(() {
      isRecording = !isRecording;
      if (isRecording) {
        _recordedFrames.clear();
        _recordTimer = Timer.periodic(const Duration(milliseconds: 1000 ~/ 30), (timer) { _captureFrame(); });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording started...'), duration: Duration(seconds: 2)));
      } else {
        _recordTimer?.cancel();
        _showExportDialog();
      }
    });
  }

  Future<void> _showExportDialog() async {
    if (_recordedFrames.isEmpty || !mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recording Stopped'),
        content: Text('Captured ${_recordedFrames.length} frames. Would you like to export them as an image sequence?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Discard')),
          ElevatedButton(onPressed: () {
            Navigator.of(context).pop();
            _exportFrames();
          }, child: const Text('Export')),
        ],
      ),
    );
  }

  Future<void> _exportFrames() async {
    String? outputDirectory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Please select a directory to save frames:',
    );

    if (outputDirectory != null) {
      for (int i = 0; i < _recordedFrames.length; i++) {
        final frameNumber = (i + 1).toString().padLeft(4, '0');
        final file = File(path.join(outputDirectory, 'frame_$frameNumber.png'));
        await file.writeAsBytes(_recordedFrames[i]);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Exported ${_recordedFrames.length} frames!')));
    }
  }

  Future<void> _captureFrame() async {
    try {
      RenderRepaintBoundary boundary = _boardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) { _recordedFrames.add(byteData.buffer.asUint8List()); }
    } catch (e) {
      // Error capturing frame, can be ignored in a timer loop
    }
  }

  void _resetAll() {
    setState(() {
      players.clear(); ball = null; arrows.clear(); highlights.clear();
      keyframes.clear(); selectedPlayer = null; homePlayerCount = 0;
      awayPlayerCount = 0; activeTool = Tool.none;
    });
    _saveState();
  }

  void _clearDrawings() {
    setState(() {
      arrows.clear();
      highlights.clear();
    });
    _saveState();
  }

  void _updateTeamColor(Team team, Color color) {
    setState(() {
      for (var player in players) {
        if (player.team == team) {
          player.color = color;
        }
      }
    });
    _saveState();
  }

  void _onPlayerTap(Player player) => setState(() => selectedPlayer = player);
  void _onPlayerDragUpdate(Player player, DragUpdateDetails details) => setState(() => player.position += details.delta);
  void _onPlayerDragEnd() => _saveState();
  void _onBallDragUpdate(DragUpdateDetails details) => setState(() => ball?.position += details.delta);

  void _onBoardDragStart(DragStartDetails details) {
    if (activeTool != Tool.none) {
      setState(() {
        dragStart = details.localPosition;
        currentDrag = details.localPosition;
      });
    }
  }

  void _onBoardDragUpdate(DragUpdateDetails details) {
    if (activeTool != Tool.none) {
      setState(() { currentDrag = details.localPosition; });
    }
  }

  void _onBoardDragEnd(DragEndDetails details) {
    if (activeTool != Tool.none && dragStart != null && currentDrag != null) {
      setState(() {
        if (activeTool == Tool.arrow) {
          arrows.add(Arrow(start: dragStart!, end: currentDrag!));
        } else if (activeTool == Tool.highlightRect) {
          highlights.add(Highlight(rect: Rect.fromPoints(dragStart!, currentDrag!)));
        } else if (activeTool == Tool.highlightOval) {
          highlights.add(Highlight(rect: Rect.fromPoints(dragStart!, currentDrag!), isOval: true));
        }
        activeTool = Tool.none;
        dragStart = null;
        currentDrag = null;
      });
      _saveState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Football Tactics Animator'), elevation: 0),
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: RepaintBoundary(
                      key: _boardKey,
                      child: GestureDetector(
                        onPanStart: _onBoardDragStart,
                        onPanUpdate: _onBoardDragUpdate,
                        onPanEnd: _onBoardDragEnd,
                        child: TacticsBoard(
                          players: players, ball: ball, arrows: arrows, highlights: highlights,
                          dragStart: dragStart, currentDrag: currentDrag, activeTool: activeTool,
                          selectedPlayer: selectedPlayer,
                          onPlayerTap: _onPlayerTap, onPlayerDragUpdate: _onPlayerDragUpdate, onBallDragUpdate: _onBallDragUpdate,
                          onPlayerDragEnd: _onPlayerDragEnd, onBallDragEnd: _onPlayerDragEnd,
                        ),
                      ),
                    ),
                  ),
                ),
                ControlPanel(
                  onAddPlayer: _addPlayer, onAddBall: _addBall, onAddKeyframe: _addKeyframe,
                  onPlayAnimation: _playAnimation, onResetAll: _resetAll,
                  onToolSelected: (tool) => setState(() => activeTool = (activeTool == tool) ? Tool.none : tool),
                  activeTool: activeTool, isAnimating: isAnimating,
                  onToggleRecording: _toggleRecording, isRecording: isRecording,
                  onUndo: _undo, canUndo: _history.length > 1,
                  onRedo: _redo, canRedo: _redoStack.isNotEmpty,
                  onClearDrawings: _clearDrawings,
                  onSave: _saveToFile, onLoad: _loadFromFile,
                ),
              ],
            ),
          ),
          EditPanel(
            selectedPlayer: selectedPlayer,
            onPlayerUpdate: () { setState(() {}); _saveState(); },
            onPlayerRemove: () { setState(() {
              players.removeWhere((p) => p.id == selectedPlayer!.id);
              selectedPlayer = null;
            }); _saveState(); },
            onTeamColorUpdate: _updateTeamColor,
          ),
        ],
      ),
    );
  }
}

class TacticsBoardPage extends StatefulWidget {
  const TacticsBoardPage({super.key});
  @override
  State<TacticsBoardPage> createState() => _TacticsBoardPageState();
}


// MARK: - Tactics Board Widget
class TacticsBoard extends StatelessWidget {
  final List<Player> players;
  final Ball? ball;
  final List<Arrow> arrows;
  final List<Highlight> highlights;
  final Offset? dragStart;
  final Offset? currentDrag;
  final Tool activeTool;
  final Player? selectedPlayer;
  final Function(Player) onPlayerTap;
  final Function(Player, DragUpdateDetails) onPlayerDragUpdate;
  final VoidCallback onPlayerDragEnd;
  final Function(DragUpdateDetails) onBallDragUpdate;
  final VoidCallback onBallDragEnd;

  const TacticsBoard({
    super.key,
    required this.players, this.ball, required this.arrows, required this.highlights,
    this.dragStart, this.currentDrag, required this.activeTool, this.selectedPlayer,
    required this.onPlayerTap, required this.onPlayerDragUpdate, required this.onPlayerDragEnd,
    required this.onBallDragUpdate, required this.onBallDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/football_field.jpg', fit: BoxFit.fitHeight),
          CustomPaint(
            painter: BoardPainter(
              arrows: arrows, highlights: highlights, dragStart: dragStart,
              currentDrag: currentDrag, activeTool: activeTool,
            ),
            size: Size.infinite,
          ),
          ...players.map((player) => Positioned(
            left: player.position.dx - player.radius,
            top: player.position.dy - player.radius,
            child: GestureDetector(
              onTap: () => onPlayerTap(player),
              onPanUpdate: (details) => onPlayerDragUpdate(player, details),
              onPanEnd: (_) => onPlayerDragEnd(),
              child: PlayerWidget(player: player, isSelected: selectedPlayer?.id == player.id),
            ),
          )),
          if (ball != null)
            Positioned(
              left: ball!.position.dx - ball!.radius,
              top: ball!.position.dy - ball!.radius,
              child: GestureDetector(
                onPanUpdate: onBallDragUpdate,
                onPanEnd: (_) => onBallDragEnd(),
                child: BallWidget(ball: ball!),
              ),
            ),
        ],
      ),
    );
  }
}

// MARK: - Custom Painter
class BoardPainter extends CustomPainter {
  final List<Arrow> arrows;
  final List<Highlight> highlights;
  final Offset? dragStart;
  final Offset? currentDrag;
  final Tool activeTool;

  BoardPainter({
    required this.arrows,
    required this.highlights,
    this.dragStart,
    this.currentDrag,
    required this.activeTool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final arrowPaint = Paint()..color = Colors.yellow..strokeWidth = 3..style = PaintingStyle.stroke;
    final highlightPaint = Paint()..color = const Color(0x4DFFFF00);

    for (var arrow in arrows) {
      _drawArrow(canvas, arrow.start, arrow.end, arrowPaint);
    }

    for (var highlight in highlights) {
      if (highlight.isOval) {
        canvas.drawOval(highlight.rect, highlightPaint);
      } else {
        canvas.drawRect(highlight.rect, highlightPaint);
      }
    }

    if (dragStart != null && currentDrag != null) {
      if (activeTool == Tool.arrow) {
        arrowPaint.color = const Color(0xCCFFFF00);
        _drawArrow(canvas, dragStart!, currentDrag!, arrowPaint);
      } else if (activeTool == Tool.highlightRect) {
        highlightPaint.color = const Color(0x80FFFF00);
        canvas.drawRect(Rect.fromPoints(dragStart!, currentDrag!), highlightPaint);
      } else if (activeTool == Tool.highlightOval) {
        highlightPaint.color = const Color(0x80FFFF00);
        canvas.drawOval(Rect.fromPoints(dragStart!, currentDrag!), highlightPaint);
      }
    }
  }

  void _drawArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
    canvas.drawLine(start, end, paint);
    final path = Path();
    final delta = end - start;
    if (delta.distance < 5) return;
    final angle = delta.direction;
    const arrowSize = 15.0;
    const arrowAngle = math.pi / 6;
    path.moveTo(end.dx - arrowSize * math.cos(angle - arrowAngle), end.dy - arrowSize * math.sin(angle - arrowAngle));
    path.lineTo(end.dx, end.dy);
    path.lineTo(end.dx - arrowSize * math.cos(angle + arrowAngle), end.dy - arrowSize * math.sin(angle + arrowAngle));
    canvas.drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// MARK: - Player and Ball Widgets
class PlayerWidget extends StatelessWidget {
  final Player player;
  final bool isSelected;
  const PlayerWidget({super.key, required this.player, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: player.radius * 2,
      height: player.radius * 2,
      decoration: BoxDecoration(
        color: player.color,
        shape: BoxShape.circle,
        border: isSelected ? Border.all(color: Colors.yellow, width: 3) : null,
        image: player.imageData != null
            ? DecorationImage(image: MemoryImage(player.imageData!), fit: BoxFit.cover)
            : null,
      ),
      child: player.imageData == null
          ? Center(child: Text(player.name, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: player.radius * 0.8)))
          : null,
    );
  }
}

class BallWidget extends StatelessWidget {
  final Ball ball;
  const BallWidget({super.key, required this.ball});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ball.radius * 2,
      height: ball.radius * 2,
      decoration: BoxDecoration(color: ball.color, shape: BoxShape.circle),
    );
  }
}

// MARK: - Control Panel
class ControlPanel extends StatelessWidget {
  final Function(Team) onAddPlayer;
  final VoidCallback onAddBall, onAddKeyframe, onPlayAnimation, onResetAll, onToggleRecording;
  final VoidCallback onUndo, onRedo, onClearDrawings, onSave, onLoad;
  final Function(Tool) onToolSelected;
  final Tool activeTool;
  final bool isAnimating, isRecording, canUndo, canRedo;

  const ControlPanel({
    super.key,
    required this.onAddPlayer, required this.onAddBall, required this.onAddKeyframe,
    required this.onPlayAnimation, required this.onResetAll, required this.onToolSelected,
    required this.activeTool, required this.isAnimating, required this.onToggleRecording, required this.isRecording,
    required this.onUndo, required this.canUndo, required this.onRedo, required this.canRedo,
    required this.onClearDrawings, required this.onSave, required this.onLoad,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Wrap(
        spacing: 8.0, runSpacing: 8.0, alignment: WrapAlignment.center,
        children: [
          ElevatedButton(onPressed: onSave, child: const Text('Save')),
          ElevatedButton(onPressed: onLoad, child: const Text('Load')),
          const VerticalDivider(),
          ElevatedButton(onPressed: canUndo ? onUndo : null, child: const Text('Undo')),
          ElevatedButton(onPressed: canRedo ? onRedo : null, child: const Text('Redo')),
          const VerticalDivider(),
          ElevatedButton(onPressed: () => onAddPlayer(Team.home), child: const Text('Add Home')),
          ElevatedButton(onPressed: () => onAddPlayer(Team.away), child: const Text('Add Away')),
          ElevatedButton(onPressed: onAddBall, child: const Text('Add Ball')),
          const VerticalDivider(),
          ElevatedButton(onPressed: onAddKeyframe, child: const Text('Add Keyframe')),
          ElevatedButton(onPressed: isAnimating ? null : onPlayAnimation, child: const Text('Play')),
          const VerticalDivider(),
          ElevatedButton(onPressed: () => onToolSelected(Tool.arrow), style: ElevatedButton.styleFrom(backgroundColor: activeTool == Tool.arrow ? Colors.amber : null), child: const Text('Draw Arrow')),
          ElevatedButton(onPressed: () => onToolSelected(Tool.highlightRect), style: ElevatedButton.styleFrom(backgroundColor: activeTool == Tool.highlightRect ? Colors.amber : null), child: const Text('Highlight Rect')),
          ElevatedButton(onPressed: () => onToolSelected(Tool.highlightOval), style: ElevatedButton.styleFrom(backgroundColor: activeTool == Tool.highlightOval ? Colors.amber : null), child: const Text('Highlight Oval')),
          const VerticalDivider(),
          ElevatedButton(onPressed: onToggleRecording, style: ElevatedButton.styleFrom(backgroundColor: isRecording ? Colors.red : Colors.cyan), child: Text(isRecording ? 'Stop' : 'Record')),
          ElevatedButton(onPressed: onClearDrawings, child: const Text('Clear Drawings')),
          ElevatedButton(onPressed: onResetAll, style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade700), child: const Text('Reset All')),
        ],
      ),
    );
  }
}

// MARK: - Edit Panel
class EditPanel extends StatefulWidget {
  final Player? selectedPlayer;
  final VoidCallback onPlayerUpdate;
  final VoidCallback onPlayerRemove;
  final Function(Team, Color) onTeamColorUpdate;

  const EditPanel({super.key, this.selectedPlayer, required this.onPlayerUpdate, required this.onPlayerRemove, required this.onTeamColorUpdate});
  @override
  State<EditPanel> createState() => _EditPanelState();
}

class _EditPanelState extends State<EditPanel> {
  late TextEditingController _nameController;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.selectedPlayer?.name);
  }

  @override
  void didUpdateWidget(covariant EditPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedPlayer?.name != _nameController.text) {
      _nameController.text = widget.selectedPlayer?.name ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (widget.selectedPlayer == null) return;
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() => widget.selectedPlayer!.imageData = bytes);
      widget.onPlayerUpdate();
    }
  }

  void _pickColor(BuildContext context, {Player? player, Team? team}) {
    Color initialColor = player?.color ?? (team == Team.home ? Colors.red : Colors.blue);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: initialColor,
            onColorChanged: (color) {
              setState(() {
                if (player != null) {
                  player.color = color;
                  widget.onPlayerUpdate();
                } else if (team != null) {
                  widget.onTeamColorUpdate(team, color);
                }
              });
            },
          ),
        ),
        actions: <Widget>[
          ElevatedButton(child: const Text('Done'), onPressed: () => Navigator.of(context).pop()),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.selectedPlayer != null) ...[
            Text('Edit Player', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name/Number'),
              onChanged: (value) {
                widget.selectedPlayer!.name = value;
                widget.onPlayerUpdate();
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Player Color'),
                const Spacer(),
                GestureDetector(
                  onTap: () => _pickColor(context, player: widget.selectedPlayer!),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: widget.selectedPlayer!.color, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _pickImage, child: const Text('Choose Picture')),
            if (widget.selectedPlayer!.imageData != null)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Image.memory(widget.selectedPlayer!.imageData!, height: 100),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: widget.onPlayerRemove,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
              child: const Text('Remove Player'),
            ),
          ] else ...[
            Text('Team Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Home Team Color'),
                const Spacer(),
                GestureDetector(
                  onTap: () => _pickColor(context, team: Team.home),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.red.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
                  ),
                )
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Text('Away Team Color'),
                const Spacer(),
                GestureDetector(
                  onTap: () => _pickColor(context, team: Team.away),
                  child: Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: Colors.blue.shade700, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
                  ),
                )
              ],
            ),
          ]
        ],
      ),
    );
  }
}
