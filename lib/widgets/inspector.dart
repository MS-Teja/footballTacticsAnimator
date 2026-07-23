import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models.dart';
import '../controller.dart';
import '../theme.dart';
import '../utils/file_helper.dart';

/// Right-hand context inspector with a header that adapts to the selection.
class InspectorPanel extends StatelessWidget {
  final TacticsController c;
  const InspectorPanel({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = _content(context);
    return Container(
      width: 300,
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(left: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.tx2),
                const SizedBox(width: 9),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: body,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Widget) _content(BuildContext context) {
    if (c.selectedPlayer != null) {
      return (Icons.person, 'Player · ${c.selectedPlayer!.name}', _PlayerEditor(c: c, player: c.selectedPlayer!));
    }
    if (c.ballSelected && c.ball != null) return (Icons.sports_soccer, 'Ball', _BallEditor(c: c, ball: c.ball!));
    if (c.selectedArrow != null) return (Icons.north_east, 'Arrow', _ArrowEditor(c: c, arrow: c.selectedArrow!));
    if (c.selectedHighlight != null) return (Icons.crop_square, 'Zone', _HighlightEditor(c: c, highlight: c.selectedHighlight!));
    return (Icons.groups_outlined, 'Team Setup', _TeamSettings(c: c));
  }
}

const double _kMinSize = 1.6;
const double _kMaxSize = 5.0;

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(color: AppColors.tx3, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
    );

Widget _swatchRow(BuildContext context, String label, Color color, VoidCallback onTap, {bool isNull = false}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(label, style: const TextStyle(color: AppColors.tx2, fontSize: 13.5)),
        const Spacer(),
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isNull ? Colors.transparent : color,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.line2, width: isNull ? 1 : 2),
            ),
            child: isNull ? const Icon(Icons.add, size: 16, color: AppColors.tx3) : null,
          ),
        ),
      ],
    ),
  );
}

void _pickColor(BuildContext context, Color initial, ValueChanged<Color> onChanged) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.panel2,
      title: const Text('Pick a color'),
      content: SingleChildScrollView(
        child: ColorPicker(
          pickerColor: initial,
          onColorChanged: onChanged,
          enableAlpha: false,
          displayThumbColor: true,
          pickerAreaHeightPercent: 0.8,
          hexInputBar: true,
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done'))],
    ),
  );
}

Widget _dangerButton(String label, VoidCallback onPressed) => SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.danger.withValues(alpha: 0.16),
          foregroundColor: const Color(0xFFFF9B96),
          padding: const EdgeInsets.symmetric(vertical: 13),
        ),
        icon: const Icon(Icons.delete_outline, size: 18),
        label: Text(label),
        onPressed: onPressed,
      ),
    );

// ---------------------------------------------------------------------------
// Player editor
// ---------------------------------------------------------------------------
class _PlayerEditor extends StatefulWidget {
  final TacticsController c;
  final Player player;
  const _PlayerEditor({required this.c, required this.player});
  @override
  State<_PlayerEditor> createState() => _PlayerEditorState();
}

class _PlayerEditorState extends State<_PlayerEditor> {
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.player.name);
  }

  @override
  void didUpdateWidget(covariant _PlayerEditor old) {
    super.didUpdateWidget(old);
    if (old.player.id != widget.player.id) _name.text = widget.player.name;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    final c = widget.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Number / name'),
        TextField(
          controller: _name,
          onChanged: (v) {
            p.name = v;
            c.refresh();
          },
          onSubmitted: (_) => c.commit(),
        ),
        _label('Size'),
        Slider(
          value: p.size.clamp(_kMinSize, _kMaxSize),
          min: _kMinSize,
          max: _kMaxSize,
          onChanged: (v) {
            p.size = v;
            c.refresh();
          },
          onChangeEnd: (_) => c.commit(),
        ),
        _label('Colors'),
        _swatchRow(context, 'Primary', p.color, () => _pickColor(context, p.color, (col) {
              p.color = col;
              c.refresh();
            })),
        _swatchRow(context, 'Secondary', p.color2 ?? Colors.transparent, () => _pickColor(context, p.color2 ?? Colors.white, (col) {
              p.color2 = col;
              c.refresh();
            }), isNull: p.color2 == null),
        if (p.color2 != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                p.color2 = null;
                c.commit();
              },
              icon: const Icon(Icons.close, size: 15),
              label: const Text('Remove secondary'),
            ),
          ),
        _swatchRow(context, 'Text', p.textColor, () => _pickColor(context, p.textColor, (col) {
              p.textColor = col;
              c.refresh();
            })),
        _label('Photo'),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.image_outlined, size: 18),
                label: Text(p.imageData == null ? 'Add photo' : 'Change'),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.line2), foregroundColor: AppColors.tx),
                onPressed: () async {
                  final bytes = await pickImageBytes();
                  if (bytes != null) {
                    p.imageData = bytes;
                    c.commit();
                  }
                },
              ),
            ),
            if (p.imageData != null) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Remove photo',
                icon: const Icon(Icons.hide_image_outlined),
                color: AppColors.tx2,
                onPressed: () {
                  p.imageData = null;
                  c.commit();
                },
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy_all_outlined, size: 17),
            label: const Text('Duplicate'),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.line2), foregroundColor: AppColors.tx2),
            onPressed: c.duplicateSelectedPlayer,
          ),
        ),
        const SizedBox(height: 8),
        _dangerButton('Delete player', c.removeSelected),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Ball editor
// ---------------------------------------------------------------------------
class _BallEditor extends StatelessWidget {
  final TacticsController c;
  final Ball ball;
  const _BallEditor({required this.c, required this.ball});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Size'),
        Slider(
          value: ball.size.clamp(0.8, 3.0),
          min: 0.8,
          max: 3.0,
          onChanged: (v) {
            ball.size = v;
            c.refresh();
          },
          onChangeEnd: (_) => c.commit(),
        ),
        const SizedBox(height: 20),
        _dangerButton('Remove ball', c.removeSelected),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Arrow editor
// ---------------------------------------------------------------------------
class _ArrowEditor extends StatelessWidget {
  final TacticsController c;
  final Arrow arrow;
  const _ArrowEditor({required this.c, required this.arrow});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: AppColors.line),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: AppColors.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text('This arrow animates during playback. Pick how it enters below.',
                    style: TextStyle(color: AppColors.tx2, fontSize: 12.5, height: 1.35)),
              ),
            ],
          ),
        ),
        _label('Animation'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<ArrowAnim>(
            segments: const [
              ButtonSegment(value: ArrowAnim.draw, label: Text('Draw along')),
              ButtonSegment(value: ArrowAnim.fade, label: Text('Fade in')),
            ],
            selected: {arrow.anim},
            showSelectedIcon: false,
            onSelectionChanged: (s) => c.setArrowAnim(arrow, s.first),
          ),
        ),
        if (arrow.isCurved) ...[
          _label('Curve'),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz, size: 18),
              label: const Text('Flip curve direction'),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.line2), foregroundColor: AppColors.tx),
              onPressed: () => c.flipArrowCurve(arrow),
            ),
          ),
        ],
        _label('Color'),
        _swatchRow(context, 'Line color', arrow.color, () => _pickColor(context, arrow.color, (col) {
              arrow.color = col;
              c.refresh();
            })),
        const SizedBox(height: 20),
        _dangerButton('Delete arrow', c.removeSelected),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Highlight editor
// ---------------------------------------------------------------------------
class _HighlightEditor extends StatelessWidget {
  final TacticsController c;
  final Highlight highlight;
  const _HighlightEditor({required this.c, required this.highlight});
  @override
  Widget build(BuildContext context) {
    final base = highlight.color.withValues(alpha: 1);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Color'),
        _swatchRow(context, 'Fill color', base, () => _pickColor(context, base, (col) {
              highlight.color = col.withValues(alpha: 0.4);
              c.refresh();
            })),
        const SizedBox(height: 20),
        _dangerButton('Delete zone', c.removeSelected),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Team setup (default view)
// ---------------------------------------------------------------------------
class _TeamSettings extends StatelessWidget {
  final TacticsController c;
  const _TeamSettings({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: AppColors.line),
          ),
          child: const Row(
            children: [
              Icon(Icons.lightbulb_outline, size: 16, color: AppColors.tx3),
              SizedBox(width: 8),
              Expanded(
                child: Text('Click a player, the ball, an arrow or a zone to edit it here.',
                    style: TextStyle(color: AppColors.tx2, fontSize: 12.5, height: 1.35)),
              ),
            ],
          ),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show numbers', style: TextStyle(fontSize: 13.5)),
          subtitle: const Text('Off = plain colored discs', style: TextStyle(fontSize: 11, color: AppColors.tx3)),
          value: c.showNumbers,
          activeThumbColor: AppColors.accent,
          onChanged: c.setShowNumbers,
        ),
        _teamBlock(context, 'Home', Team.home, c.homeColor, c.homeColor2, c.homeSize),
        const Divider(height: 32, color: AppColors.line),
        _teamBlock(context, 'Away', Team.away, c.awayColor, c.awayColor2, c.awaySize),
      ],
    );
  }

  Widget _teamBlock(BuildContext context, String name, Team team, Color primary, Color secondary, double size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: primary, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
        _label('Formation'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: kFormations
              .map((f) => OutlinedButton(
                    onPressed: () => c.applyFormation(team, f),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: const Size(0, 32),
                      side: const BorderSide(color: AppColors.line2),
                      foregroundColor: AppColors.tx,
                    ),
                    child: Text(f.name, style: const TextStyle(fontSize: 12)),
                  ))
              .toList(),
        ),
        _label('Colors'),
        _swatchRow(context, 'Primary', primary, () => _pickColor(context, primary, (col) => c.setTeamColor(team, col, primary: true))),
        _swatchRow(context, 'Secondary', secondary, () => _pickColor(context, secondary, (col) => c.setTeamColor(team, col, primary: false))),
        _label('Player size'),
        Slider(
          value: size.clamp(_kMinSize, _kMaxSize),
          min: _kMinSize,
          max: _kMaxSize,
          onChanged: (v) => c.setTeamSize(team, v),
          onChangeEnd: (_) => c.commit(),
        ),
      ],
    );
  }
}
