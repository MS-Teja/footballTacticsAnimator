import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'models.dart';

/// Central application state (a [ChangeNotifier]). Holds the editable document,
/// keyframe sequence, undo/redo history and the live playback engine. All
/// object positions are in pitch metres.
class TacticsController extends ChangeNotifier {
  TacticsController({required this.vsync}) {
    _anim = AnimationController(vsync: vsync);
    _anim.addListener(_onTick);
    _anim.addStatusListener(_onStatus);
    _pushHistory();
  }

  final TickerProvider vsync;
  late final AnimationController _anim;

  // --- Document ------------------------------------------------------------
  final List<Player> players = [];
  Ball? ball;
  final List<Arrow> arrows = [];
  final List<Highlight> highlights = [];

  // --- View settings (not animated) ----------------------------------------
  BoardLayout layout = BoardLayout.full;
  BoardOrientation orientation = BoardOrientation.horizontal;
  bool showNumbers = true;
  bool showTrails = false; // motion trails behind movers (off by default)

  int _homeCount = 0;
  int _awayCount = 0;

  // Team defaults.
  Color homeColor = const Color(0xFFE23B3B);
  Color homeColor2 = Colors.white;
  Color awayColor = const Color(0xFF2E6CF0);
  Color awayColor2 = Colors.white;
  double homeSize = 2.6;
  double awaySize = 2.6;

  // Default color for new movement arrows (bright amber reads well on grass).
  Color arrowColor = const Color(0xFFFFC24B);

  String projectName = 'Untitled play';

  void setProjectName(String name) {
    projectName = name.trim().isEmpty ? 'Untitled play' : name.trim();
    notifyListeners();
  }

  // --- Selection -----------------------------------------------------------
  String? selectedPlayerId;
  String? selectedArrowId;
  String? selectedHighlightId;
  bool ballSelected = false;
  Tool activeTool = Tool.none;

  // --- Keyframes -----------------------------------------------------------
  final List<Keyframe> keyframes = [];
  int? selectedKeyframeIndex;

  // --- Playback ------------------------------------------------------------
  bool isPlaying = false;
  bool loop = false;
  double playbackSpeed = 1.0;
  double _scrub = 0.0;
  BoardState? _preview;
  BoardState? _editSnapshot;

  bool get hasPreview => _preview != null;
  double get scrub => _scrub;

  /// Local progress (0..1, eased) within the segment currently being previewed
  /// — drives the animated arrow "draw-in". 1.0 when idle so arrows show fully.
  double _segProgress = 1.0;
  int _segIndex = 0;
  double get drawProgress => _segProgress;
  int get activeSegment => _segIndex;
  double get totalDuration {
    if (keyframes.length < 2) return 0;
    var t = 0.0;
    for (var i = 0; i < keyframes.length; i++) {
      t += keyframes[i].holdSeconds;
      if (i >= 1) t += keyframes[i].transitionSeconds;
    }
    return t;
  }

  // --- History -------------------------------------------------------------
  final List<BoardState> _undo = [];
  final List<BoardState> _redo = [];
  static const int _historyLimit = 60;

  bool get canUndo => _undo.length > 1;
  bool get canRedo => _redo.isNotEmpty;

  Player? get selectedPlayer => players.where((p) => p.id == selectedPlayerId).firstOrNull;
  Arrow? get selectedArrow => arrows.where((a) => a.id == selectedArrowId).firstOrNull;
  Highlight? get selectedHighlight => highlights.where((h) => h.id == selectedHighlightId).firstOrNull;

  BoardState get displayState =>
      _preview ??
      BoardState(players: players, ball: ball, arrows: arrows, highlights: highlights);

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // =========================================================================
  // History
  // =========================================================================
  BoardState _snapshot() => BoardState(
        players: players.map(Player.clone).toList(),
        ball: ball != null ? Ball.clone(ball!) : null,
        arrows: arrows.map(Arrow.clone).toList(),
        highlights: highlights.map(Highlight.clone).toList(),
      );

  void _pushHistory() {
    _undo.add(_snapshot());
    if (_undo.length > _historyLimit) _undo.removeAt(0);
    _redo.clear();
  }

  void commit() {
    _pushHistory();
    notifyListeners();
  }

  void refresh() => notifyListeners();

  void _restore(BoardState s) {
    players
      ..clear()
      ..addAll(s.players.map(Player.clone));
    ball = s.ball != null ? Ball.clone(s.ball!) : null;
    arrows
      ..clear()
      ..addAll(s.arrows.map(Arrow.clone));
    highlights
      ..clear()
      ..addAll(s.highlights.map(Highlight.clone));
  }

  void undo() {
    if (!canUndo) return;
    _redo.add(_undo.removeLast());
    _restore(_undo.last);
    _clearSelection();
    notifyListeners();
  }

  void redo() {
    if (!canRedo) return;
    final s = _redo.removeLast();
    _undo.add(s);
    _restore(s);
    _clearSelection();
    notifyListeners();
  }

  void _clearSelection() {
    selectedPlayerId = null;
    selectedArrowId = null;
    selectedHighlightId = null;
    ballSelected = false;
    selectedKeyframeIndex = null;
  }

  void clearSelection() {
    _clearSelection();
    notifyListeners();
  }

  // =========================================================================
  // Load
  // =========================================================================
  void loadDocument(BoardState s) {
    _restore(s);
    _undo.clear();
    _redo.clear();
    _clearSelection();
    _pushHistory();
    _homeCount = players.where((p) => p.team == Team.home).length;
    _awayCount = players.where((p) => p.team == Team.away).length;
    notifyListeners();
  }

  void loadKeyframes(List<Keyframe> ks) {
    keyframes
      ..clear()
      ..addAll(ks);
    selectedKeyframeIndex = null;
    notifyListeners();
  }

  // =========================================================================
  // View settings
  // =========================================================================
  void setTool(Tool t) {
    activeTool = (activeTool == t) ? Tool.none : t;
    notifyListeners();
  }

  void selectMode() {
    activeTool = Tool.none;
    notifyListeners();
  }

  void toggleLayout() {
    layout = layout == BoardLayout.full ? BoardLayout.half : BoardLayout.full;
    notifyListeners();
  }

  void toggleOrientation() {
    orientation = orientation == BoardOrientation.horizontal
        ? BoardOrientation.vertical
        : BoardOrientation.horizontal;
    notifyListeners();
  }

  void setShowNumbers(bool v) {
    showNumbers = v;
    notifyListeners();
  }

  void setShowTrails(bool v) {
    showTrails = v;
    notifyListeners();
  }

  // =========================================================================
  // Add / remove
  // =========================================================================
  Offset _clampPitch(Offset m) => Offset(
        m.dx.clamp(-3.0, kPitchLength + 3.0),
        m.dy.clamp(-3.0, kPitchWidth + 3.0),
      );

  void addPlayer(Team team) {
    final isHome = team == Team.home;
    final count = players.where((p) => p.team == team).length;
    final p = Player(
      name: isHome ? '${++_homeCount}' : '${++_awayCount}',
      position: Offset(
        kPitchLength * (isHome ? 0.32 : 0.68),
        kPitchWidth * 0.5 + (count % 6 - 2.5) * 6,
      ),
      color: isHome ? homeColor : awayColor,
      size: isHome ? homeSize : awaySize,
      team: team,
    );
    players.add(p);
    _clearSelection();
    selectedPlayerId = p.id;
    commit();
  }

  void applyFormation(Team team, Formation f) {
    players.removeWhere((p) => p.team == team);
    final isHome = team == Team.home;
    var n = 1;
    for (final s in f.spots) {
      final lx = (isHome ? s.dx : 1.0 - s.dx) * kPitchLength;
      players.add(Player(
        name: '${n++}',
        position: Offset(lx, s.dy * kPitchWidth),
        color: isHome ? homeColor : awayColor,
        size: isHome ? homeSize : awaySize,
        team: team,
      ));
    }
    if (isHome) {
      _homeCount = players.where((p) => p.team == Team.home).length;
    } else {
      _awayCount = players.where((p) => p.team == Team.away).length;
    }
    _clearSelection();
    commit();
  }

  void addBall() {
    if (ball != null) return;
    ball = Ball(position: const Offset(kPitchLength / 2, kPitchWidth / 2));
    selectBall();
    commit();
  }

  void duplicateSelectedPlayer() {
    final sel = selectedPlayer;
    if (sel == null) return;
    final copy = Player.clone(sel)
      ..id = UniqueKey().toString()
      ..position = Offset(
        (sel.position.dx + 4).clamp(0.0, kPitchLength),
        (sel.position.dy + 4).clamp(0.0, kPitchWidth),
      );
    players.add(copy);
    if (sel.team == Team.home) {
      _homeCount++;
    } else {
      _awayCount++;
    }
    _clearSelection();
    selectedPlayerId = copy.id;
    commit();
  }

  // =========================================================================
  // Nudge / duplicate / clipboard (operate on the current selection)
  // =========================================================================
  Object? _clipboard;

  bool get hasSelection =>
      selectedPlayerId != null || selectedArrowId != null || selectedHighlightId != null || ballSelected;

  /// Moves the current selection by [d] metres. Returns true if it moved.
  bool nudgeSelection(Offset d) {
    if (selectedPlayer != null) {
      selectedPlayer!.position = _clampPitch(selectedPlayer!.position + d);
    } else if (ballSelected && ball != null) {
      ball!.position = _clampPitch(ball!.position + d);
    } else if (selectedArrow != null) {
      _shiftArrow(selectedArrow!, d);
    } else if (selectedHighlight != null) {
      selectedHighlight!.rect = selectedHighlight!.rect.shift(d);
    } else {
      return false;
    }
    commit();
    return true;
  }

  void duplicateSelection() {
    if (selectedPlayer != null) {
      duplicateSelectedPlayer();
    } else if (selectedArrow != null) {
      final a = Arrow.clone(selectedArrow!)
        ..id = UniqueKey().toString();
      _shiftArrow(a, const Offset(3, 3));
      arrows.add(a);
      _clearSelection();
      selectedArrowId = a.id;
      commit();
    } else if (selectedHighlight != null) {
      final h = Highlight.clone(selectedHighlight!)
        ..id = UniqueKey().toString()
        ..rect = selectedHighlight!.rect.shift(const Offset(3, 3));
      highlights.add(h);
      _clearSelection();
      selectedHighlightId = h.id;
      commit();
    }
  }

  void copySelection() {
    if (selectedPlayer != null) {
      _clipboard = Player.clone(selectedPlayer!);
    } else if (selectedArrow != null) {
      _clipboard = Arrow.clone(selectedArrow!);
    } else if (selectedHighlight != null) {
      _clipboard = Highlight.clone(selectedHighlight!);
    }
  }

  void paste() {
    final clip = _clipboard;
    if (clip is Player) {
      final p = Player.clone(clip)
        ..id = UniqueKey().toString()
        ..position = _clampPitch(clip.position + const Offset(4, 4));
      players.add(p);
      p.team == Team.home ? _homeCount++ : _awayCount++;
      _clearSelection();
      selectedPlayerId = p.id;
      commit();
    } else if (clip is Arrow) {
      final a = Arrow.clone(clip)..id = UniqueKey().toString();
      _shiftArrow(a, const Offset(4, 4));
      arrows.add(a);
      _clearSelection();
      selectedArrowId = a.id;
      commit();
    } else if (clip is Highlight) {
      final h = Highlight.clone(clip)
        ..id = UniqueKey().toString()
        ..rect = clip.rect.shift(const Offset(4, 4));
      highlights.add(h);
      _clearSelection();
      selectedHighlightId = h.id;
      commit();
    }
  }

  void _shiftArrow(Arrow a, Offset d) {
    a.start += d;
    a.end += d;
    if (a.controlPoint != null) a.controlPoint = a.controlPoint! + d;
  }

  void removeSelected() {
    if (selectedPlayerId != null) {
      players.removeWhere((p) => p.id == selectedPlayerId);
    } else if (selectedArrowId != null) {
      arrows.removeWhere((a) => a.id == selectedArrowId);
    } else if (selectedHighlightId != null) {
      highlights.removeWhere((h) => h.id == selectedHighlightId);
    } else if (ballSelected) {
      ball = null;
    } else {
      return;
    }
    _clearSelection();
    commit();
  }

  void clearDrawings() {
    if (arrows.isEmpty && highlights.isEmpty) return;
    arrows.clear();
    highlights.clear();
    selectedArrowId = null;
    selectedHighlightId = null;
    commit();
  }

  void resetAll() {
    players.clear();
    ball = null;
    arrows.clear();
    highlights.clear();
    keyframes.clear();
    _homeCount = 0;
    _awayCount = 0;
    _clearSelection();
    commit();
  }

  // =========================================================================
  // Selection
  // =========================================================================
  void selectPlayer(String id) {
    _clearSelection();
    selectedPlayerId = id;
    notifyListeners();
  }

  void selectArrow(String id) {
    _clearSelection();
    selectedArrowId = id;
    notifyListeners();
  }

  void selectHighlight(String id) {
    _clearSelection();
    selectedHighlightId = id;
    notifyListeners();
  }

  void selectBall() {
    _clearSelection();
    ballSelected = true;
    notifyListeners();
  }

  // =========================================================================
  // Dragging (commit on end)
  // =========================================================================
  void movePlayerTo(Player p, Offset metres) {
    p.position = _clampPitch(metres);
    notifyListeners();
  }

  void moveBallTo(Offset metres) {
    ball?.position = _clampPitch(metres);
    notifyListeners();
  }

  void endDrag() => commit();

  // =========================================================================
  // Drawing creation (points already in metres)
  // =========================================================================
  void addArrow(Offset start, Offset end) {
    arrows.add(Arrow(start: start, end: end, color: arrowColor));
    activeTool = Tool.none;
    commit();
  }

  // Side new curved arrows bend toward (+1 / -1). Flipping one in the inspector
  // updates this so subsequent curved arrows follow suit.
  double curveSign = 1.0;

  void addCurvedArrow(Offset start, Offset end) {
    arrows.add(Arrow(
      start: start,
      end: end,
      controlPoint: computeControlPoint(start, end, curveSign),
      isCurved: true,
      color: arrowColor,
    ));
    activeTool = Tool.none;
    commit();
  }

  /// Perpendicular control point for a curved arrow; [sign] chooses the side.
  static Offset computeControlPoint(Offset start, Offset end, double sign) {
    final mid = (start + end) / 2;
    final d = end - start;
    final len = d.distance;
    if (len == 0) return mid;
    final curv = len * 0.28;
    return Offset(mid.dx - d.dy / len * curv * sign, mid.dy + d.dx / len * curv * sign);
  }

  /// Which side an existing curved arrow bends toward (+1 / -1).
  static double curveSideOf(Arrow a) {
    if (a.controlPoint == null) return 1.0;
    final mid = (a.start + a.end) / 2;
    final d = a.end - a.start;
    final v = a.controlPoint! - mid;
    // Sign of the 2D cross product of the line direction and mid->control.
    return (d.dx * v.dy - d.dy * v.dx) >= 0 ? 1.0 : -1.0;
  }

  /// Flips a curved arrow to bend the other way (and remembers the choice).
  void flipArrowCurve(Arrow a) {
    if (!a.isCurved || a.controlPoint == null) return;
    final mid = (a.start + a.end) / 2;
    a.controlPoint = mid * 2 - a.controlPoint!; // reflect across the chord
    curveSign = curveSideOf(a);
    commit();
  }

  void setArrowAnim(Arrow a, ArrowAnim anim) {
    a.anim = anim;
    commit();
  }

  void addHighlight(Rect rect, {bool oval = true}) {
    highlights.add(Highlight(rect: rect, isOval: oval));
    activeTool = Tool.none;
    commit();
  }

  // =========================================================================
  // Team / player edits
  // =========================================================================
  void setTeamColor(Team team, Color color, {required bool primary}) {
    if (team == Team.home) {
      if (primary) {
        homeColor = color;
      } else {
        homeColor2 = color;
      }
    } else {
      if (primary) {
        awayColor = color;
      } else {
        awayColor2 = color;
      }
    }
    for (final p in players.where((p) => p.team == team)) {
      if (primary) {
        p.color = color;
      } else {
        p.color2 = color;
      }
    }
    commit();
  }

  void setTeamSize(Team team, double size) {
    if (team == Team.home) {
      homeSize = size;
    } else {
      awaySize = size;
    }
    for (final p in players.where((p) => p.team == team)) {
      p.size = size;
    }
    notifyListeners();
  }

  // =========================================================================
  // Keyframes
  // =========================================================================
  void addKeyframe(Uint8List? thumb) {
    keyframes.add(Keyframe(
      boardState: _snapshot(),
      thumbnail: thumb,
      transitionSeconds: keyframes.isEmpty ? 0 : 1.5,
    ));
    notifyListeners();
  }

  void updateKeyframe(int index, Uint8List? thumb) {
    if (index < 0 || index >= keyframes.length) return;
    keyframes[index].boardState = _snapshot();
    if (thumb != null) keyframes[index].thumbnail = thumb;
    notifyListeners();
  }

  void deleteKeyframe(int index) {
    if (index < 0 || index >= keyframes.length) return;
    keyframes.removeAt(index);
    if (selectedKeyframeIndex == index) selectedKeyframeIndex = null;
    notifyListeners();
  }

  void reorderKeyframe(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1;
    keyframes.insert(newIndex, keyframes.removeAt(oldIndex));
    selectedKeyframeIndex = null;
    notifyListeners();
  }

  void selectKeyframe(int index) {
    // Loading a keyframe replaces the live board — snapshot first so ⌘Z can
    // bring the previous board back.
    if (_preview != null) stopAndReturnToEdit();
    selectedKeyframeIndex = index;
    _restore(keyframes[index].boardState);
    selectedPlayerId = null;
    selectedArrowId = null;
    selectedHighlightId = null;
    ballSelected = false;
    _pushHistory();
    notifyListeners();
  }

  /// Clears the keyframe highlight without changing the board (the user keeps
  /// editing the loaded state). Lets a selected keyframe be un-selected.
  void deselectKeyframe() {
    if (selectedKeyframeIndex == null) return;
    selectedKeyframeIndex = null;
    notifyListeners();
  }

  void setKeyframeDuration(int index, double seconds) {
    keyframes[index].transitionSeconds = seconds.clamp(0.1, 30.0);
    notifyListeners();
  }

  void setKeyframeEase(int index, EaseType e) {
    keyframes[index].ease = e;
    notifyListeners();
  }

  void setKeyframeHold(int index, double seconds) {
    keyframes[index].holdSeconds = seconds.clamp(0.0, 30.0);
    notifyListeners();
  }

  // =========================================================================
  // Interpolation
  // =========================================================================
  BoardState interpolatedStateAt(double t) => sampleAt(t).state;

  /// Samples the animation at [t] (0..1), returning the interpolated board plus
  /// the eased local progress of the active segment (for animated drawings).
  AnimationSample sampleAt(double t) {
    if (keyframes.isEmpty) return AnimationSample(_snapshot(), 1.0, 0);
    if (keyframes.length == 1) {
      return AnimationSample(BoardState.clone(keyframes.first.boardState), 1.0, 0);
    }

    final globalTime = t.clamp(0.0, 1.0) * totalDuration;
    final last = keyframes.length - 1;
    var acc = 0.0;
    for (var i = 0; i < keyframes.length; i++) {
      // Hold (pause) on this keyframe.
      final hold = keyframes[i].holdSeconds;
      if (hold > 0 && globalTime <= acc + hold) {
        return AnimationSample(BoardState.clone(keyframes[i].boardState), 1.0, i.clamp(0, last - 1));
      }
      acc += hold;
      // Transition from this keyframe to the next.
      if (i < last) {
        final dur = keyframes[i + 1].transitionSeconds;
        if (globalTime <= acc + dur || i == last - 1) {
          final localRaw = dur == 0 ? 1.0 : ((globalTime - acc) / dur).clamp(0.0, 1.0);
          final eased = keyframes[i + 1].ease.curve.transform(localRaw);
          return AnimationSample(_lerpSegment(i, eased), eased, i);
        }
        acc += dur;
      }
    }
    return AnimationSample(BoardState.clone(keyframes.last.boardState), 1.0, last - 1);
  }

  BoardState _lerpSegment(int seg, double u) {
    final a = keyframes[seg].boardState;
    final b = keyframes[seg + 1].boardState;
    final endById = {for (final p in b.players) p.id: p};
    final startIds = {for (final p in a.players) p.id};

    final players = <Player>[];
    for (final sp in a.players) {
      final ep = endById[sp.id];
      final np = Player.clone(sp);
      if (ep != null) {
        np.position = Offset.lerp(sp.position, ep.position, u)!;
        np.size = _lerp(sp.size, ep.size, u);
        if ((ep.position - sp.position).distance > 0.5) np.trailFrom = sp.position;
      } else {
        np.opacity = (1 - u).clamp(0.0, 1.0); // present at start only -> fade out
      }
      players.add(np);
    }
    for (final ep in b.players) {
      if (!startIds.contains(ep.id)) {
        players.add(Player.clone(ep)..opacity = u.clamp(0.0, 1.0)); // appears -> fade in
      }
    }

    Ball? ball;
    if (a.ball != null && b.ball != null) {
      ball = Ball.clone(a.ball!)
        ..position = Offset.lerp(a.ball!.position, b.ball!.position, u)!
        ..size = _lerp(a.ball!.size, b.ball!.size, u);
      if ((b.ball!.position - a.ball!.position).distance > 0.5) ball.trailFrom = a.ball!.position;
    } else {
      ball = a.ball != null ? Ball.clone(a.ball!) : (b.ball != null ? Ball.clone(b.ball!) : null);
    }

    // Drawings come from the DESTINATION keyframe so an arrow drawn while
    // building a frame animates during the move that arrives at it (this is the
    // natural workflow, and it lets arrows on the final frame animate + export).
    return BoardState(
      players: players,
      ball: ball,
      arrows: b.arrows.map(Arrow.clone).toList(),
      highlights: b.highlights.map(Highlight.clone).toList(),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  // =========================================================================
  // Playback transport
  // =========================================================================
  void play() {
    if (keyframes.length < 2 || isPlaying) return;
    final total = totalDuration;
    if (total <= 0) return;
    _editSnapshot ??= _snapshot();
    isPlaying = true;
    final from = _scrub >= 1.0 ? 0.0 : _scrub;
    _anim.duration = Duration(milliseconds: (total * 1000 / playbackSpeed).round());
    _applySample(from);
    _anim.forward(from: from);
    notifyListeners();
  }

  void _applySample(double t) {
    final s = sampleAt(t);
    _preview = s.state;
    _segProgress = s.progress;
    _segIndex = s.segment;
  }

  void pause() {
    if (!isPlaying) return;
    _anim.stop();
    isPlaying = false;
    notifyListeners();
  }

  void stopAndReturnToEdit() {
    _anim.stop();
    isPlaying = false;
    _scrub = 0.0;
    _segProgress = 1.0;
    if (_editSnapshot != null) {
      _restore(_editSnapshot!);
      _editSnapshot = null;
    }
    _preview = null;
    notifyListeners();
  }

  void seek(double t) {
    if (isPlaying) pause();
    _editSnapshot ??= _snapshot();
    _scrub = t.clamp(0.0, 1.0);
    _applySample(_scrub);
    notifyListeners();
  }

  void setSpeed(double s) {
    playbackSpeed = s;
    if (isPlaying) {
      _anim.duration = Duration(milliseconds: (totalDuration * 1000 / playbackSpeed).round());
      _anim.forward(from: _anim.value);
    }
    notifyListeners();
  }

  void toggleLoop() {
    loop = !loop;
    notifyListeners();
  }

  void _onTick() {
    _scrub = _anim.value;
    _applySample(_scrub);
    notifyListeners();
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      if (loop) {
        _anim.forward(from: 0.0);
        return;
      }
      // Playback finished: return to the editable board so it never gets
      // stuck in a non-interactive preview state.
      isPlaying = false;
      _scrub = 1.0;
      _segProgress = 1.0;
      if (_editSnapshot != null) {
        _restore(_editSnapshot!);
        _editSnapshot = null;
      }
      _preview = null;
      notifyListeners();
    }
  }
}

/// A sampled animation frame: the interpolated board plus the eased local
/// progress (0..1) of the active segment, used to drive animated drawings.
class AnimationSample {
  final BoardState state;
  final double progress;
  final int segment;
  const AnimationSample(this.state, this.progress, this.segment);
}
