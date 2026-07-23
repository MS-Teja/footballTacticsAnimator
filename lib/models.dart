import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

/// Canvas size the board is authored/exported at (16:9). The pitch is drawn
/// inside this, preserving its real aspect ratio.
const double kBoardWidth = 1920.0;
const double kBoardHeight = 1080.0;

/// Real pitch dimensions in metres. All object positions are stored in this
/// space (l = along the length goal-to-goal 0..105, w = across 0..68), which
/// makes horizontal/vertical/half toggles and any export resolution trivial.
const double kPitchLength = 105.0;
const double kPitchWidth = 68.0;

/// Board interaction tools: a straight movement arrow (draws itself), a curved
/// movement arrow (marching dashes), a zone highlight, and select/move ([none]).
enum Tool { none, arrow, arrowCurved, zone }

/// Seconds per flowing-dash cycle for arrows. Shared by the live board and the
/// video exporter so the on-screen motion and the exported motion match.
const double kArrowFlowPeriod = 1.1;

/// Fraction of a keyframe transition over which a "draw along" arrow completes
/// its draw-in. Keeping this well under 1.0 means the arrow traces itself out on
/// its own quicker clock and reaches the destination ahead of the mover, instead
/// of the head staying glued to the player for the whole segment.
const double kArrowDrawFraction = 0.45;

/// How an arrow animates during a keyframe transition.
/// [draw] traces itself out from tail to head (leading the movement); [fade]
/// keeps its full shape and fades/scales into the frame.
enum ArrowAnim { draw, fade }

extension ArrowAnimX on ArrowAnim {
  String get label => switch (this) {
        ArrowAnim.draw => 'Draw along',
        ArrowAnim.fade => 'Fade in',
      };
}

/// Where a player's name label sits relative to the disc.
enum LabelPos { below, above, left, right }

extension LabelPosX on LabelPos {
  String get label => switch (this) {
        LabelPos.below => 'Below',
        LabelPos.above => 'Above',
        LabelPos.left => 'Left',
        LabelPos.right => 'Right',
      };
}

/// Font weight choices for the name label (kept as a small enum so it
/// serializes cleanly and drives a segmented control).
enum LabelWeight { normal, medium, bold }

extension LabelWeightX on LabelWeight {
  FontWeight get fontWeight => switch (this) {
        LabelWeight.normal => FontWeight.w500,
        LabelWeight.medium => FontWeight.w700,
        LabelWeight.bold => FontWeight.w900,
      };

  String get label => switch (this) {
        LabelWeight.normal => 'Normal',
        LabelWeight.medium => 'Medium',
        LabelWeight.bold => 'Bold',
      };
}

/// Full styling for a player's name label (the nameplate under/around the
/// disc). [size] is in pitch metres so it scales with the board and export.
/// A null [bgColor] means no filled plate (text only).
class NameStyle {
  double size; // text height in metres
  LabelWeight weight;
  Color textColor;
  Color? bgColor;
  LabelPos pos;
  bool shadow;

  NameStyle({
    this.size = 1.8,
    this.weight = LabelWeight.medium,
    this.textColor = Colors.white,
    this.bgColor = const Color(0xE6141A20),
    this.pos = LabelPos.below,
    this.shadow = true,
  });

  NameStyle.clone(NameStyle o)
      : size = o.size,
        weight = o.weight,
        textColor = o.textColor,
        bgColor = o.bgColor,
        pos = o.pos,
        shadow = o.shadow;

  Map<String, dynamic> toJson() => {
        'size': size,
        'weight': weight.index,
        'textColor': _colorToJson(textColor),
        'bgColor': bgColor != null ? _colorToJson(bgColor!) : null,
        'pos': pos.index,
        'shadow': shadow,
      };

  factory NameStyle.fromJson(Map<String, dynamic> json) => NameStyle(
        size: (json['size'] as num?)?.toDouble() ?? 1.8,
        weight: json['weight'] != null ? LabelWeight.values[json['weight']] : LabelWeight.medium,
        textColor: json['textColor'] != null ? _colorFromJson(json['textColor']) : Colors.white,
        bgColor: json['bgColor'] != null ? _colorFromJson(json['bgColor']) : null,
        pos: json['pos'] != null ? LabelPos.values[json['pos']] : LabelPos.below,
        shadow: json['shadow'] ?? true,
      );
}

enum Team { home, away }

enum BoardLayout { full, half }

enum BoardOrientation { horizontal, vertical }

enum EaseType { linear, easeIn, easeOut, easeInOut }

extension EaseTypeX on EaseType {
  Curve get curve => switch (this) {
        EaseType.linear => Curves.linear,
        EaseType.easeIn => Curves.easeInCubic,
        EaseType.easeOut => Curves.easeOutCubic,
        EaseType.easeInOut => Curves.easeInOutCubic,
      };

  String get label => switch (this) {
        EaseType.linear => 'Linear',
        EaseType.easeIn => 'Ease In',
        EaseType.easeOut => 'Ease Out',
        EaseType.easeInOut => 'Ease In-Out',
      };
}

// ---------------------------------------------------------------------------
// Color (de)serialization
// ---------------------------------------------------------------------------
Map<String, dynamic> _colorToJson(Color c) => {
      'a': (c.a * 255.0).round() & 0xff,
      'r': (c.r * 255.0).round() & 0xff,
      'g': (c.g * 255.0).round() & 0xff,
      'b': (c.b * 255.0).round() & 0xff,
    };

Color _colorFromJson(Map<String, dynamic> m) =>
    Color.fromARGB(m['a'], m['r'], m['g'], m['b']);

double _d(dynamic v) => (v as num).toDouble();

// ---------------------------------------------------------------------------
// Player  (position & size in metres)
// ---------------------------------------------------------------------------
class Player {
  String id;
  String name;
  String label; // display name shown on the nameplate (separate from the disc number)
  Offset position; // (l, w) in metres
  Color color;
  Color? color2;
  Color textColor;
  double size; // token radius in metres
  Uint8List? imageData;
  Team team;
  NameStyle nameStyle;

  /// Transient render opacity (0..1), only set during interpolation so players
  /// fade in/out when they appear/disappear between keyframes. Not serialized.
  double opacity;

  /// Transient opacity (0..1) for the name label alone, set during interpolation
  /// so a label added/removed between keyframes fades in/out independently of
  /// the disc. Not serialized.
  double labelOpacity;

  /// Transient segment-start position, set during interpolation to draw a
  /// motion trail behind a moving player. Null when idle. Not serialized.
  Offset? trailFrom;

  Player({
    required this.name,
    this.label = '',
    required this.position,
    required this.color,
    this.color2,
    this.textColor = Colors.white,
    this.size = 2.6,
    this.imageData,
    required this.team,
    this.opacity = 1.0,
    this.labelOpacity = 1.0,
    NameStyle? nameStyle,
    String? id,
  })  : nameStyle = nameStyle ?? NameStyle(),
        id = id ?? UniqueKey().toString();

  Player.clone(Player o)
      : id = o.id,
        name = o.name,
        label = o.label,
        position = o.position,
        color = o.color,
        color2 = o.color2,
        textColor = o.textColor,
        size = o.size,
        imageData = o.imageData,
        team = o.team,
        nameStyle = NameStyle.clone(o.nameStyle),
        opacity = o.opacity,
        labelOpacity = o.labelOpacity;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'label': label,
        'l': position.dx,
        'w': position.dy,
        'color': _colorToJson(color),
        'color2': color2 != null ? _colorToJson(color2!) : null,
        'textColor': _colorToJson(textColor),
        'size': size,
        'imageData': imageData != null ? base64Encode(imageData!) : null,
        'team': team.index,
        'nameStyle': nameStyle.toJson(),
      };

  factory Player.fromJson(Map<String, dynamic> json) => Player(
        id: json['id'],
        name: json['name'],
        label: json['label'] ?? '',
        position: Offset(_d(json['l']), _d(json['w'])),
        color: _colorFromJson(json['color']),
        color2: json['color2'] != null ? _colorFromJson(json['color2']) : null,
        textColor: json['textColor'] != null ? _colorFromJson(json['textColor']) : Colors.white,
        size: _d(json['size']),
        imageData: json['imageData'] != null ? base64Decode(json['imageData']) : null,
        team: Team.values[json['team']],
        nameStyle: json['nameStyle'] != null ? NameStyle.fromJson(json['nameStyle']) : null,
      );
}

// ---------------------------------------------------------------------------
// Ball
// ---------------------------------------------------------------------------
class Ball {
  Offset position; // (l, w) in metres
  double size; // radius in metres

  /// Transient segment-start position for the motion trail. Not serialized.
  Offset? trailFrom;

  Ball({required this.position, this.size = 1.4});

  Ball.clone(Ball o)
      : position = o.position,
        size = o.size,
        trailFrom = o.trailFrom;

  Map<String, dynamic> toJson() => {'l': position.dx, 'w': position.dy, 'size': size};

  factory Ball.fromJson(Map<String, dynamic> json) => Ball(
        position: Offset(_d(json['l']), _d(json['w'])),
        size: (json['size'] as num?)?.toDouble() ?? 1.4,
      );
}

// ---------------------------------------------------------------------------
// Arrow  (points in metres)
// ---------------------------------------------------------------------------
class Arrow {
  String id;
  Offset start;
  Offset end;
  Offset? controlPoint;
  bool isCurved;
  bool isDashed;
  Color color;
  ArrowAnim anim;

  Arrow({
    required this.start,
    required this.end,
    this.controlPoint,
    this.isCurved = false,
    this.isDashed = false,
    this.color = Colors.white,
    this.anim = ArrowAnim.draw,
    String? id,
  }) : id = id ?? UniqueKey().toString();

  Arrow.clone(Arrow o)
      : id = o.id,
        start = o.start,
        end = o.end,
        controlPoint = o.controlPoint,
        isCurved = o.isCurved,
        isDashed = o.isDashed,
        color = o.color,
        anim = o.anim;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sl': start.dx,
        'sw': start.dy,
        'el': end.dx,
        'ew': end.dy,
        'isCurved': isCurved,
        'isDashed': isDashed,
        'cl': controlPoint?.dx,
        'cw': controlPoint?.dy,
        'color': _colorToJson(color),
        'anim': anim.index,
      };

  factory Arrow.fromJson(Map<String, dynamic> json) {
    Offset? cp;
    if (json['cl'] != null && json['cw'] != null) {
      cp = Offset(_d(json['cl']), _d(json['cw']));
    }
    return Arrow(
      id: json['id'],
      start: Offset(_d(json['sl']), _d(json['sw'])),
      end: Offset(_d(json['el']), _d(json['ew'])),
      controlPoint: cp,
      isCurved: json['isCurved'] ?? false,
      isDashed: json['isDashed'] ?? false,
      color: json['color'] != null ? _colorFromJson(json['color']) : Colors.white,
      anim: json['anim'] != null ? ArrowAnim.values[json['anim']] : ArrowAnim.draw,
    );
  }
}

// ---------------------------------------------------------------------------
// Highlight  (rect in metres)
// ---------------------------------------------------------------------------
class Highlight {
  String id;
  Rect rect;
  bool isOval;
  Color color;

  Highlight({required this.rect, this.isOval = false, this.color = const Color(0x66FFEB3B), String? id})
      : id = id ?? UniqueKey().toString();

  Highlight.clone(Highlight o)
      : id = o.id,
        rect = o.rect,
        isOval = o.isOval,
        color = o.color;

  Map<String, dynamic> toJson() => {
        'id': id,
        'l': rect.left,
        'w': rect.top,
        'lw': rect.width,
        'ww': rect.height,
        'isOval': isOval,
        'color': _colorToJson(color),
      };

  factory Highlight.fromJson(Map<String, dynamic> json) => Highlight(
        id: json['id'],
        rect: Rect.fromLTWH(_d(json['l']), _d(json['w']), _d(json['lw']), _d(json['ww'])),
        isOval: json['isOval'] ?? false,
        color: json['color'] != null ? _colorFromJson(json['color']) : const Color(0x66FFEB3B),
      );
}

// ---------------------------------------------------------------------------
// BoardState — snapshot of movable/drawable objects (view settings live on the
// controller, not here, so they are not animated).
// ---------------------------------------------------------------------------
class BoardState {
  List<Player> players;
  Ball? ball;
  List<Arrow> arrows;
  List<Highlight> highlights;

  BoardState({required this.players, this.ball, required this.arrows, required this.highlights});

  BoardState.clone(BoardState o)
      : players = o.players.map(Player.clone).toList(),
        ball = o.ball != null ? Ball.clone(o.ball!) : null,
        arrows = o.arrows.map(Arrow.clone).toList(),
        highlights = o.highlights.map(Highlight.clone).toList();

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

// ---------------------------------------------------------------------------
// Keyframe
// ---------------------------------------------------------------------------
class Keyframe {
  BoardState boardState;
  Uint8List? thumbnail;
  double transitionSeconds; // seconds to animate from the previous keyframe
  double holdSeconds; // seconds to pause on this keyframe before the next move
  EaseType ease;

  Keyframe({
    required this.boardState,
    this.thumbnail,
    this.transitionSeconds = 1.5,
    this.holdSeconds = 0.0,
    this.ease = EaseType.easeInOut,
  });

  Map<String, dynamic> toJson() => {
        'boardState': boardState.toJson(),
        'transitionSeconds': transitionSeconds,
        'holdSeconds': holdSeconds,
        'ease': ease.index,
        'thumbnail': thumbnail != null ? base64Encode(thumbnail!) : null,
      };

  factory Keyframe.fromJson(Map<String, dynamic> json) => Keyframe(
        boardState: BoardState.fromJson(json['boardState']),
        transitionSeconds: (json['transitionSeconds'] as num?)?.toDouble() ?? 1.5,
        holdSeconds: (json['holdSeconds'] as num?)?.toDouble() ?? 0.0,
        ease: json['ease'] != null ? EaseType.values[json['ease']] : EaseType.easeInOut,
        thumbnail: json['thumbnail'] != null ? base64Decode(json['thumbnail']) : null,
      );
}

// ---------------------------------------------------------------------------
// Formation presets — spots as fractions of (length, width) for the team
// defending the left goal. Index 0 is the keeper.
// ---------------------------------------------------------------------------
class Formation {
  final String name;
  final List<Offset> spots;
  const Formation(this.name, this.spots);
}

const List<Formation> kFormations = [
  Formation('4-4-2', [
    Offset(0.05, 0.50),
    Offset(0.22, 0.18), Offset(0.22, 0.40), Offset(0.22, 0.60), Offset(0.22, 0.82),
    Offset(0.42, 0.18), Offset(0.42, 0.40), Offset(0.42, 0.60), Offset(0.42, 0.82),
    Offset(0.60, 0.38), Offset(0.60, 0.62),
  ]),
  Formation('4-3-3', [
    Offset(0.05, 0.50),
    Offset(0.22, 0.18), Offset(0.22, 0.40), Offset(0.22, 0.60), Offset(0.22, 0.82),
    Offset(0.40, 0.30), Offset(0.40, 0.50), Offset(0.40, 0.70),
    Offset(0.60, 0.22), Offset(0.60, 0.50), Offset(0.60, 0.78),
  ]),
  Formation('4-2-3-1', [
    Offset(0.05, 0.50),
    Offset(0.20, 0.18), Offset(0.20, 0.40), Offset(0.20, 0.60), Offset(0.20, 0.82),
    Offset(0.35, 0.38), Offset(0.35, 0.62),
    Offset(0.52, 0.22), Offset(0.52, 0.50), Offset(0.52, 0.78),
    Offset(0.64, 0.50),
  ]),
  Formation('3-5-2', [
    Offset(0.05, 0.50),
    Offset(0.20, 0.30), Offset(0.20, 0.50), Offset(0.20, 0.70),
    Offset(0.38, 0.12), Offset(0.38, 0.35), Offset(0.38, 0.50), Offset(0.38, 0.65), Offset(0.38, 0.88),
    Offset(0.60, 0.38), Offset(0.60, 0.62),
  ]),
  Formation('4-1-4-1', [
    Offset(0.05, 0.50),
    Offset(0.20, 0.18), Offset(0.20, 0.40), Offset(0.20, 0.60), Offset(0.20, 0.82),
    Offset(0.34, 0.50),
    Offset(0.50, 0.18), Offset(0.50, 0.40), Offset(0.50, 0.60), Offset(0.50, 0.82),
    Offset(0.64, 0.50),
  ]),
];
