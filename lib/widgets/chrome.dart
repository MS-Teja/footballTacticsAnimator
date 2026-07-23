import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models.dart';
import '../controller.dart';
import '../theme.dart';

// ===========================================================================
// Top app bar
// ===========================================================================
class TopBar extends StatelessWidget {
  final TacticsController c;
  final VoidCallback onSave;
  final VoidCallback onLoad;
  final VoidCallback onExport;

  const TopBar({super.key, required this.c, required this.onSave, required this.onLoad, required this.onExport});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppColors.accent, AppColors.accentDim]),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.sports_soccer, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text('Tactics Animator',
                overflow: TextOverflow.ellipsis, softWrap: false, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          const SizedBox(width: 14),
          Flexible(child: Align(alignment: Alignment.centerLeft, child: _ProjectTitle(c: c))),
          const Spacer(),
          _IconBtn(icon: Icons.undo, tip: 'Undo (⌘Z)', onTap: c.canUndo ? c.undo : null),
          _IconBtn(icon: Icons.redo, tip: 'Redo (⌘⇧Z)', onTap: c.canRedo ? c.redo : null),
          const _Sep(),
          _IconBtn(icon: Icons.save_outlined, tip: 'Save project (⌘S)', onTap: onSave),
          _IconBtn(icon: Icons.folder_open_outlined, tip: 'Open project', onTap: onLoad),
          const SizedBox(width: 12),
          // On the web, MP4 export can't run (no native encoder) — the button
          // stays available and routes to a "get the macOS app" nudge instead.
          Tooltip(
            message: kIsWeb ? 'MP4 export needs the free macOS app' : 'Export an MP4 video',
            child: FilledButton.icon(
              onPressed: (kIsWeb || c.keyframes.length >= 2) ? onExport : null,
              icon: Icon(kIsWeb ? Icons.desktop_mac_outlined : Icons.movie_creation_outlined, size: 18),
              label: const Text('Export MP4'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: const Color(0xFF08130B),
                disabledBackgroundColor: AppColors.panel2,
                disabledForegroundColor: AppColors.tx3,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectTitle extends StatefulWidget {
  final TacticsController c;
  const _ProjectTitle({required this.c});
  @override
  State<_ProjectTitle> createState() => _ProjectTitleState();
}

class _ProjectTitleState extends State<_ProjectTitle> {
  late final TextEditingController _t = TextEditingController(text: widget.c.projectName);
  final _focus = FocusNode();

  @override
  void didUpdateWidget(covariant _ProjectTitle old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && _t.text != widget.c.projectName) _t.text = widget.c.projectName;
  }

  @override
  void dispose() {
    _t.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.line),
      ),
      child: TextField(
        controller: _t,
        focusNode: _focus,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, color: AppColors.tx2),
        decoration: const InputDecoration(
          isCollapsed: true,
          filled: false,
          border: InputBorder.none,
          hintText: 'Play name',
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
        ),
        onSubmitted: widget.c.setProjectName,
        onTapOutside: (_) => widget.c.setProjectName(_t.text),
      ),
    );
  }
}

class _SegToggle extends StatelessWidget {
  final List<String> options;
  final int selected;
  final ValueChanged<int> onChanged;
  const _SegToggle({required this.options, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < options.length; i++)
            GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: selected == i ? AppColors.elev : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected == i ? AppColors.tx : AppColors.tx2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool on;
  final String tip;
  final VoidCallback onTap;
  const _ChipToggle({required this.icon, required this.label, required this.on, required this.tip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: on ? AppColors.accent.withValues(alpha: 0.16) : AppColors.panel2,
            borderRadius: BorderRadius.circular(AppRadii.control),
            border: Border.all(color: on ? AppColors.accent.withValues(alpha: 0.5) : AppColors.line),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: on ? AppColors.accent : AppColors.tx2),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? AppColors.accent : AppColors.tx2)),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, required this.tip, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tip,
      child: IconButton(
        icon: Icon(icon),
        iconSize: 20,
        color: AppColors.tx2,
        disabledColor: AppColors.tx3.withValues(alpha: 0.4),
        onPressed: onTap,
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 26, margin: const EdgeInsets.symmetric(horizontal: 8), color: AppColors.line);
}

// ===========================================================================
// Floating view controls over the pitch stage
// ===========================================================================
class StageControls extends StatelessWidget {
  final TacticsController c;
  const StageControls({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.panel.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegToggle(
            options: const ['Horizontal', 'Vertical'],
            selected: c.orientation == BoardOrientation.horizontal ? 0 : 1,
            onChanged: (_) => c.toggleOrientation(),
          ),
          const SizedBox(width: 6),
          _SegToggle(
            options: const ['Full', 'Half'],
            selected: c.layout == BoardLayout.full ? 0 : 1,
            onChanged: (_) => c.toggleLayout(),
          ),
          const SizedBox(width: 6),
          _ChipToggle(
            icon: Icons.tag,
            label: 'Numbers',
            on: c.showNumbers,
            tip: c.showNumbers ? 'Numbers shown — click to hide' : 'Numbers hidden — click to show',
            onTap: () => c.setShowNumbers(!c.showNumbers),
          ),
          const SizedBox(width: 6),
          _ChipToggle(
            icon: Icons.badge_outlined,
            label: 'Names',
            on: c.showNames,
            tip: c.showNames ? 'Name labels shown — click to hide' : 'Name labels hidden — click to show',
            onTap: () => c.setShowNames(!c.showNames),
          ),
          const SizedBox(width: 6),
          _ChipToggle(
            icon: Icons.motion_photos_on_outlined,
            label: 'Trails',
            on: c.showTrails,
            tip: c.showTrails ? 'Motion trails on — click to hide' : 'Motion trails off — click to show',
            onTap: () => c.setShowTrails(!c.showTrails),
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Left tool rail (icon-only, high contrast, grouped, tooltips)
// ===========================================================================
class ToolRail extends StatelessWidget {
  final TacticsController c;
  const ToolRail({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      decoration: const BoxDecoration(
        color: AppColors.panel,
        border: Border(right: BorderSide(color: AppColors.line)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _Tool(icon: Icons.near_me_outlined, tip: 'Select & move  (Esc)', active: c.activeTool == Tool.none, onTap: c.selectMode),
          _sep(),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _Action(icon: Icons.add, tip: 'Add home player', color: c.homeColor, onTap: () => c.addPlayer(Team.home)),
                  _Action(icon: Icons.add, tip: 'Add away player', color: c.awayColor, onTap: () => c.addPlayer(Team.away)),
                  _Action(icon: Icons.sports_soccer, tip: 'Add ball', color: AppColors.ball, onTap: c.ball == null ? c.addBall : null),
                  _sep(),
                  _Tool(icon: Icons.arrow_outward, tip: 'Straight arrow — draws itself on playback\nDrag from start to end', active: c.activeTool == Tool.arrow, onTap: () => c.setTool(Tool.arrow)),
                  _Tool(icon: Icons.gesture, tip: 'Curved arrow — dashes flow on playback\nDrag from start to end', active: c.activeTool == Tool.arrowCurved, onTap: () => c.setTool(Tool.arrowCurved)),
                  _Tool(icon: Icons.blur_on, tip: 'Highlight zone\nDrag to draw an area', active: c.activeTool == Tool.zone, onTap: () => c.setTool(Tool.zone)),
                ],
              ),
            ),
          ),
          _sep(),
          _Action(icon: Icons.layers_clear_outlined, tip: 'Clear drawings', color: AppColors.tx2, onTap: c.clearDrawings),
          _Action(icon: Icons.restart_alt, tip: 'Reset board', color: AppColors.tx2, onTap: () => _confirmReset(context)),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _sep() => Container(width: 26, height: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: AppColors.line);

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panel2,
        title: const Text('Reset board?'),
        content: const Text('This removes all players, drawings and keyframes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              c.resetAll();
              Navigator.pop(ctx);
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  final IconData icon;
  final String tip;
  final bool active;
  final VoidCallback onTap;
  const _Tool({required this.icon, required this.tip, required this.active, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Tooltip(
        message: tip,
        child: Material(
          color: active ? AppColors.accent.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: AppColors.panel2,
            onTap: onTap,
            child: Container(
              width: 44,
              height: 40,
              decoration: active
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
                    )
                  : null,
              child: Icon(icon, size: 21, color: active ? AppColors.accent : AppColors.tx2),
            ),
          ),
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final IconData icon;
  final String tip;
  final Color color;
  final VoidCallback? onTap;
  const _Action({required this.icon, required this.tip, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 8),
      child: Tooltip(
        message: tip,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: AppColors.panel2,
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 40,
              child: Icon(icon, size: 22, color: enabled ? color : AppColors.tx3.withValues(alpha: 0.4)),
            ),
          ),
        ),
      ),
    );
  }
}
