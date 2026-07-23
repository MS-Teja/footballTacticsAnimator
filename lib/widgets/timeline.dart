import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models.dart';
import '../controller.dart';
import '../theme.dart';

/// Bottom panel: a compact playback transport above a horizontal keyframe
/// track. Keyframes are nodes; the transitions between them are editable
/// connectors that show duration + easing and light up as the play advances.
class TimelinePanel extends StatelessWidget {
  final TacticsController c;
  final VoidCallback onAddKeyframe;
  final void Function(int index) onUpdateKeyframe;

  const TimelinePanel({
    super.key,
    required this.c,
    required this.onAddKeyframe,
    required this.onUpdateKeyframe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(top: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TransportBar(c: c, onAddKeyframe: onAddKeyframe),
          const Divider(height: 1, color: AppColors.line),
          _KeyframeTrack(c: c, onAddKeyframe: onAddKeyframe, onUpdateKeyframe: onUpdateKeyframe),
        ],
      ),
    );
  }
}

// ===========================================================================
// Transport bar
// ===========================================================================
class _TransportBar extends StatelessWidget {
  final TacticsController c;
  final VoidCallback onAddKeyframe;
  const _TransportBar({required this.c, required this.onAddKeyframe});

  @override
  Widget build(BuildContext context) {
    final canPlay = c.keyframes.length >= 2;
    final total = c.totalDuration;
    final active = c.isPlaying || c.hasPreview;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(
        children: [
          _circleBtn(Icons.stop_rounded, 'Back to edit', 34, AppColors.panel2, AppColors.tx2,
              active ? c.stopAndReturnToEdit : null),
          const SizedBox(width: 8),
          _circleBtn(
            c.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            c.isPlaying ? 'Pause (Space)' : 'Play (Space)',
            46,
            canPlay ? AppColors.accent : AppColors.panel2,
            canPlay ? const Color(0xFF08130B) : AppColors.tx3,
            canPlay ? (c.isPlaying ? c.pause : c.play) : null,
          ),
          const SizedBox(width: 8),
          _circleBtn(Icons.repeat_rounded, c.loop ? 'Looping — click to stop' : 'Loop', 34,
              c.loop ? AppColors.accent.withValues(alpha: 0.16) : AppColors.panel2,
              c.loop ? AppColors.accent : AppColors.tx2, c.toggleLoop),
          const SizedBox(width: 18),
          _time(_fmt(total * c.scrub)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Slider(value: c.scrub.clamp(0.0, 1.0), onChanged: canPlay ? c.seek : null),
            ),
          ),
          _time(_fmt(total)),
          const SizedBox(width: 16),
          _SpeedMenu(c: c),
        ],
      ),
    );
  }

  Widget _time(String s) => Text(s,
      style: const TextStyle(
          fontFeatures: [FontFeature.tabularFigures()], color: AppColors.tx2, fontSize: 12.5, fontWeight: FontWeight.w600));

  Widget _circleBtn(IconData icon, String tip, double size, Color bg, Color fg, VoidCallback? onTap) {
    return Tooltip(
      message: tip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: onTap == null ? AppColors.tx3.withValues(alpha: 0.4) : fg, size: size * 0.56),
          ),
        ),
      ),
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  final TacticsController c;
  const _SpeedMenu({required this.c});
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: c.playbackSpeed,
      color: AppColors.panel2,
      onSelected: c.setSpeed,
      itemBuilder: (_) => const [
        PopupMenuItem(value: 0.25, child: Text('0.25×')),
        PopupMenuItem(value: 0.5, child: Text('0.5×')),
        PopupMenuItem(value: 1.0, child: Text('1×')),
        PopupMenuItem(value: 1.5, child: Text('1.5×')),
        PopupMenuItem(value: 2.0, child: Text('2×')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: AppColors.panel2,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.speed_rounded, size: 15, color: AppColors.tx2),
            const SizedBox(width: 6),
            Text('${_trim(c.playbackSpeed)}×',
                style: const TextStyle(fontSize: 12.5, color: AppColors.tx, fontWeight: FontWeight.w600)),
            const Icon(Icons.arrow_drop_down_rounded, size: 16, color: AppColors.tx2),
          ],
        ),
      ),
    );
  }

  static String _trim(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

// ===========================================================================
// Keyframe track
// ===========================================================================
class _KeyframeTrack extends StatelessWidget {
  final TacticsController c;
  final VoidCallback onAddKeyframe;
  final void Function(int index) onUpdateKeyframe;
  const _KeyframeTrack({required this.c, required this.onAddKeyframe, required this.onUpdateKeyframe});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 138,
      child: c.keyframes.isEmpty
          ? _empty(context)
          : Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                  child: _CaptureButton(onTap: onAddKeyframe, compact: true),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    scrollDirection: Axis.horizontal,
                    buildDefaultDragHandles: false,
                    padding: const EdgeInsets.fromLTRB(2, 12, 16, 12),
                    itemCount: c.keyframes.length,
                    onReorder: c.reorderKeyframe,
                    proxyDecorator: (child, index, anim) =>
                        Material(color: Colors.transparent, child: child),
                    itemBuilder: (context, i) => Row(
                      key: ValueKey(c.keyframes[i]),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (i > 0) _Connector(c: c, index: i),
                        ReorderableDragStartListener(
                          index: i,
                          child: _KeyframeNode(c: c, index: i, onUpdate: () => onUpdateKeyframe(i)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _empty(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CaptureButton(onTap: onAddKeyframe, compact: false),
          const SizedBox(width: 20),
          const SizedBox(
            width: 250,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('No keyframes yet', style: TextStyle(color: AppColors.tx, fontSize: 14, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text('Arrange the pitch, then capture a keyframe. A few keyframes animate between one another.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: AppColors.tx3, fontSize: 12.5, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool compact;
  const _CaptureButton({required this.onTap, required this.compact});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: compact ? 84 : 116,
      height: compact ? double.infinity : 96,
      child: Material(
        color: AppColors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: CustomPaint(
            painter: _DashPainter(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_a_photo_outlined, color: AppColors.accent, size: compact ? 24 : 30),
                const SizedBox(height: 7),
                Text('Capture',
                    style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w800, fontSize: compact ? 12 : 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Keyframe node (thumbnail + number + hover actions)
// ---------------------------------------------------------------------------
class _KeyframeNode extends StatefulWidget {
  final TacticsController c;
  final int index;
  final VoidCallback onUpdate;
  const _KeyframeNode({required this.c, required this.index, required this.onUpdate});

  @override
  State<_KeyframeNode> createState() => _KeyframeNodeState();
}

class _KeyframeNodeState extends State<_KeyframeNode> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final i = widget.index;
    final kf = c.keyframes[i];
    final selected = c.selectedKeyframeIndex == i;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => selected ? c.deselectKeyframe() : c.selectKeyframe(i),
        child: Container(
          width: 150,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: selected ? AppColors.accent : AppColors.line2, width: selected ? 2.5 : 1.5),
            boxShadow: selected
                ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.25), blurRadius: 12, spreadRadius: 1)]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              fit: StackFit.expand,
              children: [
                kf.thumbnail != null
                    ? Image.memory(kf.thumbnail!, fit: BoxFit.cover, gaplessPlayback: true)
                    : Container(color: AppColors.stage, child: const Icon(Icons.image_outlined, color: AppColors.tx3, size: 22)),
                // Number badge.
                Positioned(top: 6, left: 6, child: _badge('${i + 1}', selected)),
                // Per-frame timing (transition in + hold) — tap to edit.
                Positioned(bottom: 6, left: 0, right: 0, child: Center(child: _durationChip(context, i, kf))),
                // Hover / selected actions.
                if (_hover || selected)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Row(
                      children: [
                        _miniAction(Icons.sync_rounded, 'Update to current board', widget.onUpdate),
                        const SizedBox(width: 4),
                        _miniAction(Icons.delete_outline_rounded, 'Delete keyframe', () => c.deleteKeyframe(i)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String t, bool selected) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.black.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(t,
            style: TextStyle(
                fontSize: 11.5, fontWeight: FontWeight.w800, color: selected ? const Color(0xFF08130B) : Colors.white)),
      );

  Widget _durationChip(BuildContext context, int i, Keyframe kf) {
    final label = i == 0 ? 'Start' : '${kf.transitionSeconds.toStringAsFixed(1)}s';
    return GestureDetector(
      onTap: () => showDialog(context: context, builder: (_) => _TimingDialog(c: widget.c, index: i)),
      child: Tooltip(
        message: 'Edit timing (duration / hold)',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (i > 0) ...[
                const Icon(Icons.schedule_rounded, size: 11, color: Colors.white70),
                const SizedBox(width: 4),
              ],
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              if (kf.holdSeconds > 0) ...[
                const SizedBox(width: 5),
                const Icon(Icons.pause_rounded, size: 11, color: AppColors.accent),
                Text('${kf.holdSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.accent)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniAction(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.6),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 24, height: 24, child: Icon(icon, size: 14, color: Colors.white)),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Connector between two keyframes: shows + edits the transition (duration+ease)
// ---------------------------------------------------------------------------
class _Connector extends StatelessWidget {
  final TacticsController c;
  final int index; // node position; edits keyframes[index].transition
  const _Connector({required this.c, required this.index});

  @override
  Widget build(BuildContext context) {
    final kf = c.keyframes[index];
    final segActive = (c.isPlaying || c.hasPreview) && c.activeSegment == index - 1;
    final accent = segActive ? AppColors.accent : AppColors.tx2;
    return Tooltip(
      message: 'Transition: ${kf.transitionSeconds.toStringAsFixed(1)}s · ${kf.ease.label}\nClick to edit',
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _edit(context),
        child: SizedBox(
          width: 66,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomPaint(size: const Size(30, 20), painter: _EaseGlyph(kf.ease, accent)),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 8, height: 2, color: accent.withValues(alpha: 0.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: segActive ? AppColors.accent.withValues(alpha: 0.16) : AppColors.panel2,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: segActive ? AppColors.accent.withValues(alpha: 0.5) : AppColors.line),
                        ),
                        child: Text('${kf.transitionSeconds.toStringAsFixed(1)}s',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w700, color: segActive ? AppColors.accent : AppColors.tx2)),
                      ),
                      Icon(Icons.arrow_right_alt_rounded, size: 16, color: accent.withValues(alpha: 0.7)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _edit(BuildContext context) {
    showDialog(context: context, builder: (_) => _TimingDialog(c: c, index: index));
  }
}

/// A little glyph that plots the easing curve.
class _EaseGlyph extends CustomPainter {
  final EaseType ease;
  final Color color;
  _EaseGlyph(this.ease, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(4)), track);

    final path = Path();
    const steps = 22;
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final v = ease.curve.transform(t);
      final x = 3 + t * (size.width - 6);
      final y = size.height - 3 - v * (size.height - 6);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _EaseGlyph old) => old.ease != ease || old.color != color;
}

/// Compact editor for a keyframe's timing: the transition into it (duration +
/// easing, when it isn't the first frame) and how long to hold on it.
class _TimingDialog extends StatefulWidget {
  final TacticsController c;
  final int index;
  const _TimingDialog({required this.c, required this.index});
  @override
  State<_TimingDialog> createState() => _TimingDialogState();
}

class _TimingDialogState extends State<_TimingDialog> {
  late double _seconds;
  late double _hold;
  late EaseType _ease;
  late final TextEditingController _field;

  bool get _hasTransition => widget.index > 0;

  @override
  void initState() {
    super.initState();
    final kf = widget.c.keyframes[widget.index];
    _seconds = kf.transitionSeconds;
    _hold = kf.holdSeconds;
    _ease = kf.ease;
    _field = TextEditingController(text: _seconds.toStringAsFixed(1));
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _apply() {
    if (_hasTransition) {
      widget.c.setKeyframeDuration(widget.index, _seconds);
      widget.c.setKeyframeEase(widget.index, _ease);
    }
    widget.c.setKeyframeHold(widget.index, _hold);
  }

  void _setSeconds(double v) {
    setState(() => _seconds = v.clamp(0.1, 30.0));
    _field.text = _seconds.toStringAsFixed(1);
    _apply();
  }

  static Widget _heading(String t) => Text(t,
      style: const TextStyle(color: AppColors.tx3, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Keyframe ${widget.index + 1} timing'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasTransition) ...[
              _heading('TRANSITION IN'),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Slider(value: _seconds.clamp(0.1, 8.0), min: 0.1, max: 8.0, onChanged: _setSeconds),
                  ),
                  SizedBox(
                    width: 58,
                    child: TextField(
                      controller: _field,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(suffixText: 's', isDense: true),
                      onChanged: (v) {
                        final d = double.tryParse(v);
                        if (d != null) {
                          setState(() => _seconds = d.clamp(0.1, 30.0));
                          _apply();
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _heading('EASING'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: EaseType.values.map((e) {
                  final on = _ease == e;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _ease = e);
                      _apply();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: on ? AppColors.accent.withValues(alpha: 0.16) : AppColors.panel,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: on ? AppColors.accent : AppColors.line),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CustomPaint(size: const Size(24, 16), painter: _EaseGlyph(e, on ? AppColors.accent : AppColors.tx2)),
                          const SizedBox(width: 7),
                          Text(e.label,
                              style: TextStyle(fontSize: 12.5, color: on ? AppColors.accent : AppColors.tx2, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
            ],
            _heading('HOLD ON THIS FRAME'),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _hold.clamp(0.0, 5.0),
                    max: 5.0,
                    onChanged: (v) {
                      setState(() => _hold = v);
                      _apply();
                    },
                  ),
                ),
                SizedBox(
                  width: 46,
                  child: Text('${_hold.toStringAsFixed(1)}s',
                      textAlign: TextAlign.end, style: const TextStyle(color: AppColors.tx2, fontSize: 12.5)),
                ),
              ],
            ),
            const Text('Pause here before the next move.', style: TextStyle(color: AppColors.tx3, fontSize: 11.5)),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: const Color(0xFF08130B)),
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

String _fmt(double seconds) {
  final s = seconds.floor();
  final ms = ((seconds - s) * 10).floor();
  return '${s.toString().padLeft(2, '0')}.${ms}s';
}

// ---------------------------------------------------------------------------
// Dashed border used by the capture button.
// ---------------------------------------------------------------------------
class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12));
    final path = Path()..addRRect(rrect);
    const dash = 5.0, gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
