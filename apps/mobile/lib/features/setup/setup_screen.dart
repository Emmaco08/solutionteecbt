import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/states.dart';
import '../shell/shell.dart';

const nigerianStates = [
  'Abia',
  'Adamawa',
  'Akwa Ibom',
  'Anambra',
  'Bauchi',
  'Bayelsa',
  'Benue',
  'Borno',
  'Cross River',
  'Delta',
  'Ebonyi',
  'Edo',
  'Ekiti',
  'Enugu',
  'FCT Abuja',
  'Gombe',
  'Imo',
  'Jigawa',
  'Kaduna',
  'Kano',
  'Katsina',
  'Kebbi',
  'Kogi',
  'Kwara',
  'Lagos',
  'Nasarawa',
  'Niger',
  'Ogun',
  'Ondo',
  'Osun',
  'Oyo',
  'Plateau',
  'Rivers',
  'Sokoto',
  'Taraba',
  'Yobe',
  'Zamfara',
];

/// Profile setup in 3 steps: exams → JAMB subjects (English + 3) → goal. Saved to `profiles`.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 0;
  final _exams = <String>{'JAMB'};
  final _subjects = <String>{'eng'};
  double _target = 280;
  String? _state;
  bool _saving = false;
  String? _error;

  bool get _needsJamb => _exams.contains('JAMB');
  int get _steps => _needsJamb ? 3 : 2;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client
          .from('profiles')
          .update({
            'target_exams': _exams.toList(),
            'jamb_subjects': _needsJamb ? _subjects.toList() : <String>[],
            'target_score': _needsJamb ? _target.round() : null,
            'state': _state,
          })
          .eq('id', uid);
      ref.invalidate(profileProvider);
      if (mounted) context.go('/welcome-new');
    } catch (e) {
      setState(() => _error = 'Could not save. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _next() {
    if (_step == 0 && _exams.isEmpty) return setState(() => _error = 'Choose at least one exam.');
    if (_step == 1 && _needsJamb && _subjects.length != 4) return setState(() => _error = 'Choose 3 subjects besides Use of English.');
    setState(() => _error = null);
    if (_step == _steps - 1) {
      _save();
    } else {
      setState(() => _step = _needsJamb ? _step + 1 : 2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final visualStep = _needsJamb ? _step : (_step == 0 ? 0 : 1);
    return Scaffold(
      appBar: AppBar(
        leading: _step == 0
            ? null
            : IconButton(tooltip: 'Back', icon: Icon(PhosphorIcons.arrowLeft()), onPressed: () => setState(() => _step = _needsJamb ? _step - 1 : 0)),
        title: Text('Step ${visualStep + 1} of $_steps'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.s5),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: (visualStep + 1) / _steps, minHeight: 6, backgroundColor: c.surfaceSunken, color: c.secondary),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.base,
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: switch (_step) {
                    0 => _examsStep(),
                    1 => _subjectsStep(),
                    _ => _goalStep(),
                  },
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.s5),
                child: Text(
                  _error!,
                  style: TextStyle(color: c.error, fontWeight: FontWeight.w700),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(Space.s5),
              child: FilledButton(
                onPressed: _saving ? null : _next,
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : Text(_step == _steps - 1 || (!_needsJamb && _step == 2) ? 'Finish' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String t, String s) => Padding(
    padding: const EdgeInsets.fromLTRB(0, Space.s5, 0, Space.s5),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: context.t.headlineSmall),
        gap2,
        Text(s, style: context.t.bodyMedium?.copyWith(color: context.c.textMuted)),
      ],
    ),
  );

  Widget _examsStep() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Space.s5),
    children: [
      _title('Which exams are you preparing for?', 'Choose all that apply. You can change this later.'),
      for (final (code, name) in [('JAMB', 'JAMB UTME'), ('WAEC', 'WAEC WASSCE'), ('NECO', 'NECO SSCE')]) ...[
        _ChoiceTile(
          selected: _exams.contains(code),
          leading: ExamLogo(code, size: 44),
          title: name,
          onTap: () => setState(() => _exams.contains(code) ? _exams.remove(code) : _exams.add(code)),
        ),
        gap3,
      ],
    ],
  );

  Widget _subjectsStep() {
    final subjects = ref.watch(subjectsProvider);
    final jambOnly = ref.watch(examSubjectsProvider).value;
    final exams = ref.watch(examsProvider).value ?? const [];
    final jambId = exams.where((e) => e['code'] == 'JAMB').map((e) => e['id']).firstOrNull;
    return asyncView(subjects, (list) {
      final allowed = jambOnly == null
          ? null
          : {
              for (final r in jambOnly)
                if (r['exam_id'] == jambId) r['subject_id'],
            };
      final shown = list.where((s) => allowed == null || allowed.contains(s['id'])).toList();
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: Space.s5),
        children: [
          _title('Your JAMB subjects', 'Use of English is compulsory. Pick 3 more (${_subjects.length - 1}/3).'),
          Wrap(
            spacing: Space.s2,
            runSpacing: Space.s2,
            children: [
              for (final s in shown)
                FilterChip(
                  label: Text(s['name'] as String),
                  selected: _subjects.contains(s['code']),
                  onSelected: s['code'] == 'eng'
                      ? null
                      : (on) => setState(() {
                          if (on && _subjects.length >= 4) return;
                          on ? _subjects.add(s['code'] as String) : _subjects.remove(s['code']);
                        }),
                ),
            ],
          ),
        ],
      );
    }, onRetry: () => ref.invalidate(subjectsProvider));
  }

  Widget _goalStep() => ListView(
    padding: const EdgeInsets.symmetric(horizontal: Space.s5),
    children: [
      _title('Set your goal', 'We use this to show how close you are.'),
      if (_needsJamb) ...[
        Text('Target JAMB score', style: context.t.labelLarge),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _target,
                min: 120,
                max: 400,
                divisions: 28,
                label: _target.round().toString(),
                onChanged: (v) => setState(() => _target = v),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text('${_target.round()}', style: context.t.headlineSmall, textAlign: TextAlign.end),
            ),
          ],
        ),
        gap5,
      ],
      DropdownButtonFormField<String>(
        initialValue: _state,
        decoration: const InputDecoration(labelText: 'Your state (optional)'),
        items: [for (final s in nigerianStates) DropdownMenuItem(value: s, child: Text(s))],
        onChanged: (v) => setState(() => _state = v),
      ),
    ],
  );
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({required this.selected, required this.leading, required this.title, required this.onTap});
  final bool selected;
  final Widget leading;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: selected ? c.secondarySoft : c.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
        side: BorderSide(color: selected ? c.secondary : c.border, width: selected ? 2 : 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Space.s4),
          child: Row(
            children: [
              leading,
              gap4,
              Expanded(child: Text(title, style: context.t.titleMedium)),
              Icon(selected ? PhosphorIcons.checkCircle(PhosphorIconsStyle.fill) : PhosphorIcons.circle(), color: selected ? c.secondary : c.borderStrong),
            ],
          ),
        ),
      ),
    );
  }
}
