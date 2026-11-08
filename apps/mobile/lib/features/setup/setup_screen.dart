import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/ads.dart';
import '../../core/providers.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../ui/kit.dart';
import '../../ui/subject_icons.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/phosphor.g.dart';
import '../../widgets/states.dart';
import 'age_gate.dart';

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

/// Profile setup (prototype: setup): about you, [parent or guardian, for ages 13 to 17 (D-109)], exams + target score,
/// JAMB subjects (English + 3). Saved to `profiles`. Without JAMB the subjects step is skipped. Under 13: no account.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key, this.subjectsOnly = false});

  /// Settings → "Change JAMB subjects": only step 3, then back.
  final bool subjectsOnly;
  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  int _step = 1;
  final _guardianKey = GlobalKey<GuardianStepState>();
  bool _guardianDone = false, _birthLocked = false;
  final _name = TextEditingController(), _phone = TextEditingController(), _school = TextEditingController();
  String? _state, _birth;
  final _exams = <String>{'JAMB'};
  final _subjects = <String>{};
  double _target = 290;
  bool _saving = false;
  String? _nameErr, _stateErr, _birthErr, _error;

  bool get _jamb => _exams.contains('JAMB');
  bool get _teen {
    final y = int.tryParse(_birth ?? '');
    if (y == null) return false;
    final a = ageFromYear(y);
    return a >= minAge && a < adultAge;
  }

  /// The steps, in order: about, guardian (13 to 17), exams, subjects (JAMB).
  List<String> get _steps => ['about', if (_teen) 'guardian', 'exams', if (_jamb) 'subjects'];
  int get _total => _steps.length;
  String get _id => widget.subjectsOnly ? 'subjects' : _steps[(_step - 1).clamp(0, _steps.length - 1)];

  @override
  void initState() {
    super.initState();
    // Pre-fill from the profile (a setup left half-way).
    final p = ref.read(profileProvider).value;
    if (widget.subjectsOnly) {
      _step = 3;
      _subjects.addAll(((p?['jamb_subjects'] as List?) ?? const []).cast<String>().where((c) => c != 'eng'));
    }
    if (p != null) {
      _name.text = (p['full_name'] as String?) ?? '';
      _phone.text = (p['phone'] as String?) ?? '';
      _school.text = (p['school'] as String?) ?? '';
      _state = p['state'] as String?;
      if (p['birth_year'] != null) {
        _birth = '${p['birth_year']}';
        _birthLocked = true; // set once, on the server
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _school.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      if (widget.subjectsOnly) {
        final exams = {...((ref.read(profileProvider).value?['target_exams'] as List?) ?? const []).cast<String>(), 'JAMB'};
        await Supabase.instance.client
            .from('profiles')
            .update({
              'jamb_subjects': ['eng', ..._subjects],
              'target_exams': exams.toList(),
            })
            .eq('id', uid);
        ref.invalidate(profileProvider);
        if (!mounted) return;
        toast(context, 'Your JAMB subjects are saved.');
        context.pop();
        return;
      }
      await Supabase.instance.client
          .from('profiles')
          .update({
            'full_name': _name.text.trim(),
            'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            'state': _state,
            'school': _school.text.trim().isEmpty ? null : _school.text.trim(),
            'target_exams': _exams.toList(),
            'jamb_subjects': _jamb ? ['eng', ..._subjects] : <String>[],
            'target_score': _jamb ? _target.round() : null,
          })
          .eq('id', uid);
      ref.invalidate(profileProvider);
      await ref.read(profileProvider.future);
      if (mounted) context.go('/welcome-new');
    } catch (e) {
      setState(() => _error = 'Could not save. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// After "Tell us about you": the details and the year of birth go to the server now (the parent email needs the
  /// name and age). Under 13: the new account is deleted at once. Returns false when setup must stop here.
  Future<bool> _saveAbout() async {
    final by = int.parse(_birth!);
    if (ageFromYear(by) < minAge) {
      await blockUnder13(context, ref);
      return false;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final sb = Supabase.instance.client;
      await sb
          .from('profiles')
          .update({
            'full_name': _name.text.trim(),
            'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            'state': _state,
            'school': _school.text.trim().isEmpty ? null : _school.text.trim(),
          })
          .eq('id', sb.auth.currentUser!.id);
      if (!_birthLocked) {
        final r = Map<String, dynamic>.from(await sb.rpc('set_birth_year', params: {'p_year': by}) as Map);
        if (r['why'] == 'under_13') {
          if (mounted) await blockUnder13(context, ref);
          return false;
        }
        _birthLocked = true;
        ref.invalidate(adsConfigProvider);
      }
      if (_teen && !_guardianDone) {
        final g = await sb.from('guardian_consents').select('sent_at').maybeSingle();
        _guardianDone = g?['sent_at'] != null;
      }
      return true;
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Check your internet and try again.');
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _continue() async {
    if (_id == 'about') {
      setState(() {
        _nameErr = _name.text.trim().length < 2 ? 'Enter your full name' : null;
        _stateErr = _state == null ? 'Choose your state' : null;
        _birthErr = _birth == null ? 'Choose the year you were born' : null;
      });
      if (_nameErr != null || _stateErr != null || _birthErr != null) return;
      if (!await _saveAbout() || !mounted) return;
      if (_teen && _guardianDone) {
        setState(() => _step += 2); // the parent email already went out: straight to the exams
        return;
      }
    }
    if (_id == 'guardian' && !_guardianDone) {
      setState(() => _saving = true);
      final ok = await _guardianKey.currentState?.send() ?? false;
      if (mounted) setState(() => _saving = false);
      if (!ok || !mounted) return;
    }
    if (_id == 'exams' && _exams.isEmpty) {
      toast(context, 'Pick at least one exam.', icon: PhosphorIcons.info(PhosphorIconsStyle.fill));
      return;
    }
    if (_step == _total || widget.subjectsOnly) {
      _save();
    } else {
      setState(() => _step++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = switch (_id) {
      'about' => _about(),
      'guardian' => GuardianStep(key: _guardianKey, footerButton: false, onSent: () => _guardianDone = true),
      'exams' => _examsStep(),
      _ => _subjectsStep(),
    };
    final canFinish = _id != 'subjects' || _subjects.length == 3;
    if (widget.subjectsOnly) {
      return Scaffold(
        appBar: const TopBar(title: 'Change JAMB subjects'),
        body: _subjectsStep(),
        bottomNavigationBar: FooterCta(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[ErrText(_error!), const Gap(Space.s3)],
              Btn('Save subjects', block: true, loading: _saving, onPressed: _subjects.length == 3 ? _save : null),
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: _step == 1,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _step > 1) setState(() => _step -= (_id == 'exams' && _teen && _guardianDone) ? 2 : 1);
      },
      child: Scaffold(
        appBar: TopBar(
          showBack: _step > 1,
          onBack: () => setState(() => _step -= (_id == 'exams' && _teen && _guardianDone) ? 2 : 1),
          center: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.s4),
            child: StepsBar(step: _step, total: _total),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Space.s3),
              child: Text('$_step/$_total', style: context.ty.cap.bold.col(context.c.textMuted)),
            ),
          ],
        ),
        body: AnimatedSwitcher(
          duration: Motion.base,
          child: KeyedSubtree(key: ValueKey(_step), child: body),
        ),
        bottomNavigationBar: FooterCta(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ...[ErrText(_error!), const Gap(Space.s3)],
              Btn(
                _step == _total
                    ? 'Finish setup'
                    : _id == 'guardian' && !_guardianDone
                    ? 'Send the email'
                    : 'Continue',
                block: true,
                loading: _saving,
                onPressed: canFinish ? _continue : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _page(String title, Widget subtitle, List<Widget> children) {
    final rm = context.reduceMotion;
    return ListView(
      padding: const EdgeInsets.fromLTRB(Space.s5, Space.s4, Space.s5, Space.s8),
      children: [
        Text(title, style: context.ty.h1),
        const Gap(Space.s2),
        DefaultTextStyle(style: context.ty.body.col(context.c.textMuted), child: subtitle),
        const Gap(Space.s4),
        for (var i = 0; i < children.length; i++)
          rm ? children[i] : children[i].animate(delay: Motion.stagger * i).fadeIn(duration: Motion.slow).slideY(begin: .1, curve: Motion.out),
      ],
    );
  }

  // Step 1: Tell us about you
  Widget _about() => _page('Tell us about you', const Text('This helps us personalise your practice.'), [
    Field(
      label: 'Full name',
      hint: 'e.g. Tolu Adeyemi',
      icon: PhosphorIcons.user(),
      controller: _name,
      caps: TextCapitalization.words,
      autofill: const [AutofillHints.name],
      error: _nameErr,
    ),
    const Gap(Space.s4),
    Field(
      label: 'Phone number (optional)',
      hint: '0803 000 0000',
      icon: PhosphorIcons.phone(),
      controller: _phone,
      keyboard: TextInputType.phone,
      autofill: const [AutofillHints.telephoneNumber],
      help: 'For class reminders only. We never share it.',
    ),
    const Gap(Space.s4),
    _SelectField(
      label: 'State',
      value: _state,
      hint: 'Choose your state',
      options: nigerianStates,
      error: _stateErr,
      onChanged: (v) => setState(() {
        _state = v;
        _stateErr = null;
      }),
    ),
    const Gap(Space.s4),
    _SelectField(
      label: 'Year you were born',
      value: _birth,
      hint: 'Choose the year',
      // Set once: after it is saved only that year is offered.
      options: _birthLocked && _birth != null ? [_birth!] : [for (var y = DateTime.now().year - 6; y >= DateTime.now().year - 70; y--) '$y'],
      error: _birthErr,
      onChanged: (v) => setState(() {
        _birth = v;
        _birthErr = null;
      }),
    ),
    const Gap(Space.s4),
    Field(
      label: 'School (optional)',
      hint: 'e.g. Loyola College, Ibadan',
      icon: PhosphorIcons.graduationCap(),
      controller: _school,
      caps: TextCapitalization.words,
    ),
  ]);

  // Step 2: Which exams are you writing? + target JAMB score
  Widget _examsStep() => _page('Which exams are you writing?', const Text('Pick all that apply. You can change this later.'), [
    for (final (code, name, sub) in const [
      ('JAMB', 'JAMB UTME', '4 subjects · 180 questions · 2 hours'),
      ('WAEC', 'WAEC WASSCE', 'Objective papers per subject'),
      ('NECO', 'NECO SSCE', 'Objective papers per subject'),
    ]) ...[
      SubjTile(
        on: _exams.contains(code),
        minHeight: 72,
        lead: ExamLogo(code),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: context.ty.label.bold),
            Text(sub, style: context.ty.cap.col(context.c.textMuted)),
          ],
        ),
        onTap: () => setState(() => _exams.contains(code) ? _exams.remove(code) : _exams.add(code)),
      ),
      const Gap(Space.s3),
    ],
    if (_jamb) ...[
      const Gap(Space.s2),
      Text('Target JAMB score', style: context.ty.sm.bold),
      const Gap(Space.s2),
      Row(
        children: [
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: context.c.secondary,
                thumbColor: context.c.secondary,
                inactiveTrackColor: context.c.surfaceSunken,
                overlayColor: context.c.secondary.withValues(alpha: .12),
              ),
              child: Slider(value: _target, min: 180, max: 400, divisions: 44, label: '${_target.round()}', onChanged: (v) => setState(() => _target = v)),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text('${_target.round()}', style: context.ty.h3.tnum, textAlign: TextAlign.right),
          ),
        ],
      ),
      Text('Most competitive courses need 280+.', style: context.ty.cap.col(context.c.textMuted)),
    ],
  ]);

  // Step 3: Your JAMB subjects (English + 3)
  Widget _subjectsStep() {
    final subjects = ref.watch(subjectsProvider);
    final links = ref.watch(examSubjectsProvider).value;
    final exams = ref.watch(examsProvider).value ?? const [];
    final jambId = exams.where((e) => e['code'] == 'JAMB').map((e) => e['id']).firstOrNull;
    return asyncView(subjects, (list) {
      final allowed = links == null
          ? null
          : {
              for (final r in links)
                if (r['exam_id'] == jambId) r['subject_id'],
            };
      final shown = list.where((s) => s['code'] != 'eng' && (allowed == null || allowed.contains(s['id']))).toList();
      return _page(
        'Your JAMB subjects',
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Use of English is compulsory. Choose '),
              TextSpan(text: '3 more', style: context.ty.body.bold.col(context.c.textMuted)),
              const TextSpan(text: '.'),
            ],
          ),
        ),
        [
          Row(
            children: [
              Expanded(child: Text('${_subjects.length} of 3 chosen', style: context.ty.sm.bold)),
              Pill('English + 3', icon: PhosphorIcons.info(PhosphorIconsStyle.fill)),
            ],
          ),
          const Gap(Space.s2),
          SubjTile(
            on: true,
            locked: true,
            lead: Icon(subjectIcon('eng'), size: 20),
            trailingBadge: const Pill('Compulsory', kind: BadgeKind.neutral),
            child: Text('Use of English', style: context.ty.label.bold),
          ),
          const Gap(Space.s2),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: Space.s3,
            crossAxisSpacing: Space.s3,
            childAspectRatio: 2.9,
            children: [
              for (final s in shown)
                SubjTile(
                  on: _subjects.contains(s['code']),
                  dense: true,
                  lead: Icon(subjectIcon(s['code'] as String), size: 20),
                  child: Text(
                    s['name'] as String,
                    style: context.ty.sm.bold.copyWith(height: 17 / 13),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () {
                    final code = s['code'] as String;
                    if (!_subjects.contains(code) && _subjects.length >= 3) {
                      toast(context, 'You can pick only 3. Tap one to remove it first.', icon: PhosphorIcons.info(PhosphorIconsStyle.fill));
                      return;
                    }
                    setState(() => _subjects.contains(code) ? _subjects.remove(code) : _subjects.add(code));
                  },
                ),
            ],
          ),
        ],
      );
    }, onRetry: () => ref.invalidate(subjectsProvider));
  }
}

/// Selectable tile (`.subj`, `.subj.on`, `.subj.locked`) with a round tick on the right.
class SubjTile extends StatelessWidget {
  const SubjTile({
    super.key,
    required this.on,
    required this.child,
    this.lead,
    this.onTap,
    this.locked = false,
    this.minHeight = 52,
    this.dense = false,
    this.trailingBadge,
  });
  final bool on, locked, dense;
  final Widget child;
  final Widget? lead, trailingBadge;
  final VoidCallback? onTap;
  final double minHeight;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Semantics(
      selected: on,
      button: !locked,
      child: Opacity(
        opacity: locked ? .6 : 1,
        child: Pressable(
          onTap: locked ? null : onTap,
          scale: .98,
          borderRadius: BorderRadius.circular(Radii.md),
          child: AnimatedContainer(
            duration: Motion.fast,
            constraints: BoxConstraints(minHeight: minHeight),
            padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 14),
            decoration: BoxDecoration(
              color: on ? c.secondarySoft : c.surface,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: on ? c.secondary : c.border, width: on ? 2 : 1.5),
            ),
            child: Row(
              children: [
                if (lead != null) ...[
                  IconTheme(
                    data: IconThemeData(color: c.text),
                    child: lead!,
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(child: child),
                if (trailingBadge != null)
                  trailingBadge!
                else
                  AnimatedContainer(
                    duration: Motion.fast,
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: on ? c.secondary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: on ? null : Border.all(color: c.borderStrong, width: 1.5),
                    ),
                    child: on ? Icon(PhosphorIcons.check(PhosphorIconsStyle.fill), size: 13, color: Colors.white) : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Select styled as an `.input` with a caret; opens a sheet with the options.
class _SelectField extends StatelessWidget {
  const _SelectField({required this.label, required this.value, required this.options, required this.onChanged, this.hint, this.error});
  final String label;
  final String? value, hint, error;
  final List<String> options;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: context.ty.sm.bold),
        const Gap(Space.s2),
        Semantics(
          button: true,
          label: '$label: ${value ?? hint ?? ''}',
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.md),
            onTap: () async {
              final v = await showSheet<String>(
                context,
                builder: (ctx) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(label, style: ctx.ty.h3),
                    const Gap(Space.s3),
                    for (final o in options)
                      ListTile(
                        title: Text(o, style: ctx.ty.body),
                        trailing: o == value ? Icon(PhosphorIcons.check(PhosphorIconsStyle.fill), color: ctx.c.secondary) : null,
                        onTap: () => Navigator.pop(ctx, o),
                      ),
                  ],
                ),
              );
              if (v != null) onChanged(v);
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: Sizes.inputHeight),
              padding: const EdgeInsets.symmetric(horizontal: Space.s4),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.md),
                border: Border.all(color: error != null ? c.error : c.borderStrong, width: error != null ? 2 : 1.5),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(value ?? hint ?? '', style: context.ty.body.copyWith(fontSize: 16).col(value == null ? c.textSubtle : c.text))),
                  Icon(PhosphorIcons.caretDown(), size: 18, color: c.textSubtle),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[const Gap(Space.s2), ErrText(error!)],
      ],
    );
  }
}
