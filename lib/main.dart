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
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as path;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tactics Animator',
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
        dividerColor: Colors.grey.shade800,
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
  Color? color2;
  Color textColor;
  double radius;
  Uint8List? imageData;
  Team team;

  Player({
    required this.name,
    required this.position,
    required this.color,
    this.color2,
    this.textColor = Colors.white,
    this.radius = 20.0,
    this.imageData,
    required this.team,
  }) : id = UniqueKey().toString();

  Player.clone(Player other)
      : id = other.id,
        name = other.name,
        position = other.position,
        color = other.color,
        color2 = other.color2,
        textColor = other.textColor,
        radius = other.radius,
        imageData = other.imageData,
        team = other.team;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dx': position.dx,
    'dy': position.dy,
    'color': {'a': color.alpha, 'r': color.red, 'g': color.green, 'b': color.blue},
    'color2': color2 != null ? {'a': color2!.alpha, 'r': color2!.red, 'g': color2!.green, 'b': color2!.blue} : null,
    'textColor': {'a': textColor.alpha, 'r': textColor.red, 'g': textColor.green, 'b': textColor.blue},
    'radius': radius,
    'imageData': imageData != null ? base64Encode(imageData!) : null,
    'team': team.index,
  };

  factory Player.fromJson(Map<String, dynamic> json) {
    var colorMap = json['color'] as Map<String, dynamic>;
    var color2Map = json['color2'] as Map<String, dynamic>?;
    var textColorMap = json['textColor'] as Map<String, dynamic>?;

    return Player(
      name: json['name'],
      position: Offset(json['dx'], json['dy']),
      color: Color.fromARGB(colorMap['a'], colorMap['r'], colorMap['g'], colorMap['b']),
      color2: color2Map != null ? Color.fromARGB(color2Map['a'], color2Map['r'], color2Map['g'], color2Map['b']) : null,
      textColor: textColorMap != null ? Color.fromARGB(textColorMap['a'], textColorMap['r'], textColorMap['g'], textColorMap['b']) : Colors.white,
      radius: json['radius'],
      imageData: json['imageData'] != null ? base64Decode(json['imageData']) : null,
      team: Team.values[json['team']],
    )..id = json['id'];
  }
}

class Ball {
  Offset position;
  Color color = Colors.yellow;
  double radius = 12.0;

  Ball({required this.position});

  Ball.clone(Ball other)
      : position = other.position,
        color = other.color,
        radius = other.radius;

  Map<String, dynamic> toJson() => {
    'dx': position.dx,
    'dy': position.dy,
    'color': {'a': color.alpha, 'r': color.red, 'g': color.green, 'b': color.blue},
    'radius': radius,
  };

  factory Ball.fromJson(Map<String, dynamic> json) {
    var colorMap = json['color'] as Map<String, dynamic>;
    return Ball(position: Offset(json['dx'], json['dy']))
      ..color = Color.fromARGB(colorMap['a'], colorMap['r'], colorMap['g'], colorMap['b'])
      ..radius = json['radius'];
  }
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
  BoardLayout boardLayout;

  BoardState({required this.players, this.ball, required this.arrows, required this.highlights, this.boardLayout = BoardLayout.full});

  BoardState.clone(BoardState other)
      : players = other.players.map((p) => Player.clone(p)).toList(),
        ball = other.ball != null ? Ball.clone(other.ball!) : null,
        arrows = List.from(other.arrows),
        highlights = List.from(other.highlights),
        boardLayout = other.boardLayout;

  Map<String, dynamic> toJson() => {
    'players': players.map((p) => p.toJson()).toList(),
    'ball': ball?.toJson(),
    'arrows': arrows.map((a) => a.toJson()).toList(),
    'highlights': highlights.map((h) => h.toJson()).toList(),
    'boardLayout': boardLayout.index,
  };

  factory BoardState.fromJson(Map<String, dynamic> json) => BoardState(
    players: (json['players'] as List).map((p) => Player.fromJson(p)).toList(),
    ball: json['ball'] != null ? Ball.fromJson(json['ball']) : null,
    arrows: (json['arrows'] as List).map((a) => Arrow.fromJson(a)).toList(),
    highlights: (json['highlights'] as List).map((h) => Highlight.fromJson(h)).toList(),
    boardLayout: json['boardLayout'] != null ? BoardLayout.values[json['boardLayout']] : BoardLayout.full,
  );
}

class AnimationKeyframe {
  BoardState boardState;
  Uint8List? thumbnail; // To store a preview image

  AnimationKeyframe({required this.boardState, this.thumbnail});
}

enum Tool { none, arrow, highlightRect, highlightOval }
enum Team { home, away }
enum BoardLayout { full, half }

// MARK: - Main Page
// MARK: - Main Page
class _TacticsBoardPageState extends State<TacticsBoardPage> with TickerProviderStateMixin {
  final GlobalKey _boardKey = GlobalKey();
  List<Player> players = [];
  Ball? ball;
  List<Arrow> arrows = [];
  List<Highlight> highlights = [];
  List<AnimationKeyframe> keyframes = [];

  Player? selectedPlayer;
  int? selectedKeyframeIndex;
  Tool activeTool = Tool.none;
  Offset? dragStart;
  Offset? currentDrag;
  BoardLayout boardLayout = BoardLayout.full;

  int homePlayerCount = 0;
  int awayPlayerCount = 0;

  bool isAnimating = false;
  late AnimationController _animationController;

  bool isRecording = false;
  // FIX: Removed the Timer-based recording mechanism.
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
    isRecording = false; // This will stop the callback from capturing frames
    super.dispose();
  }

  // FIX: This is the new, more reliable callback for capturing frames.
  void _recordFrameCallback(Duration timeStamp) {
    if (!isRecording) {
      // The callback will continue to fire, but we simply do nothing if not recording.
      return;
    }
    _captureFrame();
  }

  void _saveState() {
    _history.add(BoardState(
      players: players.map((p) => Player.clone(p)).toList(),
      ball: ball != null ? Ball.clone(ball!) : null,
      arrows: List.from(arrows),
      highlights: List.from(highlights),
      boardLayout: boardLayout,
    ));
    _redoStack.clear();
  }

  void _undo() {
    if (_history.length > 1) {
      setState(() {
        final currentState = _history.removeLast();
        _redoStack.add(currentState);
        final prevState = _history.last;
        _applyBoardState(prevState);
        selectedPlayer = null;
      });
    }
  }

  void _redo() {
    if (_redoStack.isNotEmpty) {
      setState(() {
        final nextState = _redoStack.removeLast();
        _history.add(nextState);
        _applyBoardState(nextState);
        selectedPlayer = null;
      });
    }
  }

  void _applyBoardState(BoardState state) {
    players = state.players.map((p) => Player.clone(p)).toList();
    ball = state.ball != null ? Ball.clone(state.ball!) : null;
    arrows = List.from(state.arrows);
    highlights = List.from(state.highlights);
    boardLayout = state.boardLayout;
  }

  void _saveToFile() async {
    final state = BoardState(players: players, ball: ball, arrows: arrows, highlights: highlights, boardLayout: boardLayout);
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
        _applyBoardState(state);
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

  Future<void> _addKeyframe() async {
    final thumbnail = await _captureFrame(saveToList: false);
    setState(() {
      keyframes.add(AnimationKeyframe(
        boardState: BoardState.clone(BoardState(players: players, ball: ball, arrows: arrows, highlights: highlights, boardLayout: boardLayout)),
        thumbnail: thumbnail,
      ));
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Keyframe ${keyframes.length} added!'), duration: const Duration(seconds: 1)),
    );
  }

  void _updateKeyframe() {
    if (selectedKeyframeIndex != null) {
      setState(() {
        keyframes[selectedKeyframeIndex!].boardState = BoardState.clone(BoardState(players: players, ball: ball, arrows: arrows, highlights: highlights, boardLayout: boardLayout));
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final thumbnail = await _captureFrame(saveToList: false);
        setState(() {
          keyframes[selectedKeyframeIndex!].thumbnail = thumbnail;
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keyframe updated!'), duration: Duration(seconds: 1)),
      );
    }
  }

  void _deleteKeyframe() {
    if (selectedKeyframeIndex != null) {
      setState(() {
        keyframes.removeAt(selectedKeyframeIndex!);
        selectedKeyframeIndex = null;
      });
    }
  }

  void _playAnimation() {
    if (keyframes.length < 2 || isAnimating) return;
    final originalState = BoardState.clone(BoardState(players: players, ball: ball, arrows: arrows, highlights: highlights, boardLayout: boardLayout));
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
            final startPlayer = startFrame.boardState.players.firstWhere((p) => p.id == players[i].id, orElse: () => players[i]);
            final endPlayer = endFrame.boardState.players.firstWhere((p) => p.id == players[i].id, orElse: () => players[i]);
            players[i].position = Offset.lerp(startPlayer.position, endPlayer.position, animation.value)!;
          }
          if (ball != null && startFrame.boardState.ball != null && endFrame.boardState.ball != null) {
            ball!.position = Offset.lerp(startFrame.boardState.ball!.position, endFrame.boardState.ball!.position, animation.value)!;
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
              _applyBoardState(originalState);
            });
          }
        }
      });

      setState(() {
        isAnimating = true;
        _applyBoardState(startFrame.boardState);
      });
      _animationController.forward();
    }
    runAnimationSegment();
  }

  // FIX: Rewritten to use the new, more reliable frame callback method.
  void _toggleRecording() {
    setState(() {
      isRecording = !isRecording;
      if (isRecording) {
        _recordedFrames.clear();
        SchedulerBinding.instance.addPersistentFrameCallback(_recordFrameCallback);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording started...'), duration: Duration(seconds: 2)));
      } else {
        // The callback will remove itself automatically on the next frame.
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

  Future<Uint8List?> _captureFrame({bool saveToList = true}) async {
    try {
      RenderRepaintBoundary boundary = _boardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 1.5);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final frameData = byteData.buffer.asUint8List();
        if (saveToList) {
          _recordedFrames.add(frameData);
        }
        return frameData;
      }
    } catch (e) {
      // Error capturing frame
    }
    return null;
  }

  void _resetAll() {
    setState(() {
      players.clear(); ball = null; arrows.clear(); highlights.clear();
      keyframes.clear(); selectedPlayer = null; homePlayerCount = 0;
      awayPlayerCount = 0; activeTool = Tool.none; selectedKeyframeIndex = null;
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

  void _updateTeamColor(Team team, Color color, bool isPrimary) {
    setState(() {
      for (var player in players) {
        if (player.team == team) {
          if (isPrimary) {
            player.color = color;
          } else {
            player.color2 = color;
          }
        }
      }
    });
    _saveState();
  }

  void _updateTeamPlayerSize(Team team, double size) {
    setState(() {
      for (var player in players) {
        if (player.team == team) {
          player.radius = size;
        }
      }
    });
    _saveState();
  }

  void _toggleLayout() {
    setState(() {
      boardLayout = boardLayout == BoardLayout.full ? BoardLayout.half : BoardLayout.full;
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
    } else {
      setState(() {
        selectedPlayer = null;
        selectedKeyframeIndex = null;
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
      appBar: AppBar(title: const Text('Tactics Animator'), elevation: 0),
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
                          layout: boardLayout,
                          onPlayerTap: _onPlayerTap, onPlayerDragUpdate: _onPlayerDragUpdate, onBallDragUpdate: _onBallDragUpdate,
                          onPlayerDragEnd: _onPlayerDragEnd, onBallDragEnd: _onPlayerDragEnd,
                        ),
                      ),
                    ),
                  ),
                ),
                KeyframeTimeline(
                  keyframes: keyframes,
                  selectedIndex: selectedKeyframeIndex,
                  onKeyframeSelected: (index) {
                    setState(() {
                      selectedKeyframeIndex = index;
                      _applyBoardState(keyframes[index].boardState);
                    });
                  },
                  onUpdate: _updateKeyframe,
                  onDelete: _deleteKeyframe,
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
                  onToggleLayout: _toggleLayout,
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
            onTeamSizeUpdate: _updateTeamPlayerSize,
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
  final BoardLayout layout;
  final Function(Player) onPlayerTap;
  final Function(Player, DragUpdateDetails) onPlayerDragUpdate;
  final VoidCallback onPlayerDragEnd;
  final Function(DragUpdateDetails) onBallDragUpdate;
  final VoidCallback onBallDragEnd;

  const TacticsBoard({
    super.key,
    required this.players, this.ball, required this.arrows, required this.highlights,
    this.dragStart, this.currentDrag, required this.activeTool, this.selectedPlayer,
    required this.layout,
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
          Image.asset(
            layout == BoardLayout.full ? 'assets/football_field.jpg' : 'assets/football_half_field.jpg',
            fit: BoxFit.fitHeight
          ),
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
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // Layer 1: The colored circle with its own shadow
        Container(
          width: player.radius * 2,
          height: player.radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected ? Colors.yellow : Colors.black,
              width: isSelected ? 3 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipOval(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(color: player.color),
                if (player.color2 != null)
                  ClipPath(
                    clipper: HalfCircleClipper(),
                    child: Container(color: player.color2),
                  ),
                if (player.imageData == null)
                  Text(player.name, style: TextStyle(color: player.textColor, fontWeight: FontWeight.bold, fontSize: player.radius * 0.8)),
              ],
            ),
          ),
        ),

        // Layer 2: The player image, now with a soft edge
        if (player.imageData != null)
          Positioned(
            top: -player.radius * 0.3,
            child: SizedBox(
              width: player.radius * 3,
              height: player.radius * 3,
              child: ShaderMask( // FIX: Wrap the image in a ShaderMask for the fade effect
                shaderCallback: (rect) {
                  // This gradient goes from fully visible (white) to fully transparent.
                  return LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // The stops control where the fade happens.
                    // It's fully visible for the top 38% and fades out over the next 10%.
                    stops: const [0.0, 0.38, 0.65],
                    colors: [Colors.white, Colors.white, Colors.white.withOpacity(0.0)],
                  ).createShader(rect);
                },
                blendMode: BlendMode.dstIn, // This applies the gradient's transparency to the image
                child: ClipPath( // We still clip the shape, but now it has a soft edge from the mask
                  clipper: PlayerImageClipper(playerRadius: player.radius),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // The "shadow" layer
                      Transform.translate(
                        offset: const Offset(2, 4),
                        child: ImageFiltered(
                          imageFilter: ui.ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                          child: Image.memory(
                            player.imageData!,
                            color: Colors.black.withOpacity(0.6),
                            colorBlendMode: BlendMode.srcIn,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      // The actual image
                      Image.memory(
                        player.imageData!,
                        fit: BoxFit.contain,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class PlayerImageClipper extends CustomClipper<Path> {
  final double playerRadius;

  PlayerImageClipper({required this.playerRadius});

  @override
  Path getClip(Size size) {
    final circleCenter = Offset(size.width / 2, playerRadius * 1.8);
    final circlePath = Path()
      ..addOval(Rect.fromCenter(
        center: circleCenter,
        width: playerRadius * 2,
        height: playerRadius * 2,
      ));
    final rectPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, circleCenter.dy));
    return Path.combine(PathOperation.union, circlePath, rectPath);
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}

class HalfCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.addRect(Rect.fromLTWH(0, 0, size.width / 2, size.height));
    return path;
  }
  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}


class BallWidget extends StatelessWidget {
  final Ball ball;
  const BallWidget({super.key, required this.ball});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: ball.radius * 2,
      height: ball.radius * 2,
      child: CustomPaint(
        painter: SoccerBallPainter(ball: ball),
      ),
    );
  }
}

class SoccerBallPainter extends CustomPainter {
  final Ball ball;

  SoccerBallPainter({required this.ball});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(radius, radius);

    // Create circular clip path
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.clipPath(clipPath);

    // Draw checkerboard pattern
    final paint = Paint();
    final squareSize = size.width / 3; // Adjust for desired pattern density

    for (int i = -1; i <= size.width / squareSize; i++) {
      for (int j = -1; j <= size.height / squareSize; j++) {
        paint.color = (i + j) % 2 == 0 ? Colors.black : Colors.white;
        canvas.drawRect(
            Rect.fromLTWH(i * squareSize, j * squareSize, squareSize, squareSize),
            paint
        );
      }
    }

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius - 0.5, borderPaint);
  }

  @override
  bool shouldRepaint(covariant SoccerBallPainter oldDelegate) =>
      ball.radius != oldDelegate.ball.radius || ball.color != oldDelegate.ball.color;
}

// MARK: - Control Panel
class ControlPanel extends StatelessWidget {
  final Function(Team) onAddPlayer;
  final VoidCallback onAddBall, onAddKeyframe, onPlayAnimation, onResetAll, onToggleRecording;
  final VoidCallback onUndo, onRedo, onClearDrawings, onSave, onLoad, onToggleLayout;
  final Function(Tool) onToolSelected;
  final Tool activeTool;
  final bool isAnimating, isRecording, canUndo, canRedo;

  const ControlPanel({
    super.key,
    required this.onAddPlayer, required this.onAddBall, required this.onAddKeyframe,
    required this.onPlayAnimation, required this.onResetAll, required this.onToolSelected,
    required this.activeTool, required this.isAnimating, required this.onToggleRecording, required this.isRecording,
    required this.onUndo, required this.canUndo, required this.onRedo, required this.canRedo,
    required this.onClearDrawings, required this.onSave, required this.onLoad, required this.onToggleLayout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildIconButton(context, tip: 'Save Project', icon: Icons.save, onPressed: onSave),
          _buildIconButton(context, tip: 'Load Project', icon: Icons.folder_open, onPressed: onLoad),
          const VerticalDivider(),
          _buildIconButton(context, tip: 'Undo', icon: Icons.undo, onPressed: canUndo ? onUndo : null),
          _buildIconButton(context, tip: 'Redo', icon: Icons.redo, onPressed: canRedo ? onRedo : null),
          const VerticalDivider(),
          _buildIconButton(context, tip: 'Add Home Player', icon: Icons.person_add, color: Colors.red, onPressed: () => onAddPlayer(Team.home)),
          _buildIconButton(context, tip: 'Add Away Player', icon: Icons.person_add, color: Colors.blue, onPressed: () => onAddPlayer(Team.away)),
          _buildIconButton(context, tip: 'Add Ball', icon: Icons.sports_soccer, color: Colors.yellow, onPressed: onAddBall),
          const VerticalDivider(),
          _buildIconButton(context, tip: 'Add Keyframe', icon: Icons.add_to_photos, onPressed: onAddKeyframe),
          _buildIconButton(context, tip: 'Play Animation', icon: Icons.play_arrow, onPressed: isAnimating ? null : onPlayAnimation),
          const VerticalDivider(),
          _buildIconButton(context, tip: 'Draw Arrow', icon: Icons.arrow_forward, onPressed: () => onToolSelected(Tool.arrow), isActive: activeTool == Tool.arrow),
          _buildIconButton(context, tip: 'Highlight Rectangle', icon: Icons.crop_square, onPressed: () => onToolSelected(Tool.highlightRect), isActive: activeTool == Tool.highlightRect),
          _buildIconButton(context, tip: 'Highlight Oval', icon: Icons.circle_outlined, onPressed: () => onToolSelected(Tool.highlightOval), isActive: activeTool == Tool.highlightOval),
          const VerticalDivider(),
          _buildIconButton(context, tip: 'Switch Layout', icon: Icons.crop_landscape, onPressed: onToggleLayout),
          _buildIconButton(context, tip: isRecording ? 'Stop Recording' : 'Record Animation', icon: isRecording ? Icons.stop : Icons.videocam, color: isRecording ? Colors.red : Colors.cyan, onPressed: onToggleRecording),
          _buildIconButton(context, tip: 'Clear Drawings', icon: Icons.layers_clear, onPressed: onClearDrawings),
          _buildIconButton(context, tip: 'Reset Board', icon: Icons.refresh, onPressed: onResetAll),
        ],
      ),
    );
  }

  Widget _buildIconButton(BuildContext context, {required String tip, required IconData icon, required VoidCallback? onPressed, Color? color, bool isActive = false}) {
    return Tooltip(
      message: tip,
      child: IconButton(
        icon: Icon(icon),
        color: isActive ? Colors.amber : color ?? Colors.white,
        onPressed: onPressed,
        iconSize: 28,
        splashRadius: 24,
      ),
    );
  }
}

// MARK: - Edit Panel
class EditPanel extends StatefulWidget {
  final Player? selectedPlayer;
  final VoidCallback onPlayerUpdate;
  final VoidCallback onPlayerRemove;
  final Function(Team, Color, bool) onTeamColorUpdate;
  final Function(Team, double) onTeamSizeUpdate;

  const EditPanel({super.key, this.selectedPlayer, required this.onPlayerUpdate, required this.onPlayerRemove, required this.onTeamColorUpdate, required this.onTeamSizeUpdate});
  @override
  State<EditPanel> createState() => _EditPanelState();
}

class _EditPanelState extends State<EditPanel> {
  late TextEditingController _nameController;
  final ImagePicker _picker = ImagePicker();

  double _homePlayerSize = 20.0;
  double _awayPlayerSize = 20.0;

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

  void _pickColor(BuildContext context, {Player? player, Team? team, bool isPrimary = true, bool isTextColor = false}) {
    Color initialColor = Colors.white;
    if (isTextColor) {
      initialColor = player?.textColor ?? Colors.white;
    } else if (isPrimary) {
      initialColor = player?.color ?? (team == Team.home ? Colors.red : Colors.blue);
    } else {
      initialColor = player?.color2 ?? (team == Team.home ? Colors.white : Colors.white);
    }

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
                  if (isTextColor) {
                    player.textColor = color;
                  } else if (isPrimary) {
                    player.color = color;
                  } else {
                    player.color2 = color;
                  }
                  widget.onPlayerUpdate();
                } else if (team != null) {
                  widget.onTeamColorUpdate(team, color, isPrimary);
                }
              });
            },
            displayThumbColor: true,
            enableAlpha: false,
            pickerAreaHeightPercent: 0.8,
            colorPickerWidth: 300,
            hexInputBar: true,
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
            Text('Edit Player', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name/Number'),
              onChanged: (value) { widget.selectedPlayer!.name = value; widget.onPlayerUpdate(); },
            ),
            const SizedBox(height: 16),
            Text('Player Size: ${widget.selectedPlayer!.radius.toStringAsFixed(0)}'),
            Slider(
              value: widget.selectedPlayer!.radius, min: 10, max: 60,
              onChanged: (value) { setState(() => widget.selectedPlayer!.radius = value); widget.onPlayerUpdate(); },
            ),
            const SizedBox(height: 16),
            _buildColorPickerRow('Primary Color', () => _pickColor(context, player: widget.selectedPlayer!), widget.selectedPlayer!.color),
            const SizedBox(height: 16),
            _buildColorPickerRow('Secondary Color', () => _pickColor(context, player: widget.selectedPlayer!, isPrimary: false), widget.selectedPlayer!.color2),
            const SizedBox(height: 16),
            _buildColorPickerRow('Text Color', () => _pickColor(context, player: widget.selectedPlayer!, isTextColor: true), widget.selectedPlayer!.textColor),
            const SizedBox(height: 24),
            ElevatedButton.icon(icon: const Icon(Icons.image), onPressed: _pickImage, label: const Text('Choose Picture')),
            if (widget.selectedPlayer!.imageData != null)
              Padding(padding: const EdgeInsets.only(top: 16.0), child: Image.memory(widget.selectedPlayer!.imageData!, height: 100)),
            const Spacer(),
            ElevatedButton.icon(
              icon: const Icon(Icons.delete_forever),
              onPressed: widget.onPlayerRemove,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
              label: const Text('Remove Player'),
            ),
          ] else ...[
            Text('Team Settings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Text('Home Player Size: ${_homePlayerSize.toStringAsFixed(0)}'),
            Slider(
              value: _homePlayerSize, min: 10, max: 60,
              onChanged: (value) {
                setState(() => _homePlayerSize = value);
                widget.onTeamSizeUpdate(Team.home, value);
              },
            ),
            _buildColorPickerRow('Home Primary', () => _pickColor(context, team: Team.home), Colors.red.shade700),
            const SizedBox(height: 16),
            _buildColorPickerRow('Home Secondary', () => _pickColor(context, team: Team.home, isPrimary: false), Colors.white),
            const Divider(height: 32),
            Text('Away Player Size: ${_awayPlayerSize.toStringAsFixed(0)}'),
            Slider(
              value: _awayPlayerSize, min: 10, max: 60,
              onChanged: (value) {
                setState(() => _awayPlayerSize = value);
                widget.onTeamSizeUpdate(Team.away, value);
              },
            ),
            _buildColorPickerRow('Away Primary', () => _pickColor(context, team: Team.away), Colors.blue.shade700),
            const SizedBox(height: 16),
            _buildColorPickerRow('Away Secondary', () => _pickColor(context, team: Team.away, isPrimary: false), Colors.white),
          ]
        ],
      ),
    );
  }

  Widget _buildColorPickerRow(String label, VoidCallback onTap, Color? color) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color ?? Colors.transparent, shape: BoxShape.circle, border: Border.all(color: Colors.white54)),
            child: color == null ? const Icon(Icons.add, size: 20) : null,
          ),
        )
      ],
    );
  }
}

// MARK: - Keyframe Timeline
class KeyframeTimeline extends StatelessWidget {
  final List<AnimationKeyframe> keyframes;
  final int? selectedIndex;
  final Function(int) onKeyframeSelected;
  final VoidCallback onUpdate;
  final VoidCallback onDelete;

  const KeyframeTimeline({
    super.key,
    required this.keyframes,
    this.selectedIndex,
    required this.onKeyframeSelected,
    required this.onUpdate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      color: Theme.of(context).cardColor,
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          if (selectedIndex != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(icon: const Icon(Icons.update), label: const Text("Update Keyframe"), onPressed: onUpdate),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(icon: const Icon(Icons.delete), label: const Text("Delete Keyframe"), onPressed: onDelete, style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900)),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: keyframes.length,
              itemBuilder: (context, index) {
                final keyframe = keyframes[index];
                return GestureDetector(
                  onTap: () => onKeyframeSelected(index),
                  child: Container(
                    width: 120,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: selectedIndex == index ? Colors.amber : Colors.grey.shade700,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: keyframe.thumbnail != null
                        ? Image.memory(keyframe.thumbnail!, fit: BoxFit.cover)
                        : const Center(child: Text('No Preview')),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
