import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/phosphor.g.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/providers.dart';
import '../../data/db.dart';
import '../../theme/theme.dart';
import '../../theme/tokens.g.dart';
import '../../widgets/exam_logo.dart';
import '../../widgets/states.dart';
import '../shell/shell.dart';

const _supportEmailFallback = 'support@mail.solutiontee.com';

/// Finished tests on this phone, newest first.
final historyProvider = FutureProvider.autoDispose<List<LocalAttempt>>((ref) => ref.watch(dbProvider).finishedAttempts());

Map<String, dynamic>? _score(LocalAttempt a) {
  final raw = a.serverScoreJson ?? a.clientScoreJson;
  return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
}

/// Signs out and clears everything this account left on the phone.
Future<void> signOutAndWipe(WidgetRef ref) async {
  try {
    await Supabase.instance.client.auth.signOut();
  } catch (_) {
    // Offline: the local session is still removed below.
  }
  await ref.read(dbProvider).wipe();
  ref.invalidate(profileProvider);
  ref.invalidate(myPlanProvider);
  ref.invalidate(historyProvider);
}

Future<void> _open(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open that. Please try again.')));
  }
}

// ---------------------------------------------------------------- profile (Me tab)
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final profile = ref.watch(profileProvider);
    final plan = ref.watch(myPlanProvider).value;
    final premium = plan?['tier'] == 'premium';
    final history = ref.watch(historyProvider).value ?? const [];
    final scores = [for (final a in history) _score(a)].whereType<Map<String, dynamic>>().where((s) => (s['max'] as num) > 0).toList();
    final avg = scores.isEmpty ? null : (scores.fold<double>(0, (t, s) => t + (s['total'] as num) / (s['max'] as num)) / scores.length * 100).round();
    final email = Supabase.instance.client.auth.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Me')),
      body: asyncView(profile, (p) {
        final name = (p?['full_name'] as String?) ?? '';
        final exams = [for (final e in (p?['target_exams'] as List? ?? const [])) e as String];
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileProvider);
            ref.invalidate(myPlanProvider);
            ref.invalidate(historyProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.s5, Space.s2, Space.s5, Space.s8),
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: c.primary,
                    child: Text(name.isEmpty ? '?' : name.trim()[0].toUpperCase(), style: context.t.headlineSmall?.copyWith(color: c.onPrimary)),
                  ),
                  gap4,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name.isEmpty ? 'Student' : name, style: context.t.titleLarge),
                        Text(
                          email,
                          style: context.t.bodySmall?.copyWith(color: c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(tooltip: 'Edit name', icon: Icon(PhosphorIcons.pencilSimple()), onPressed: () => _editName(context, ref, name)),
                ],
              ),
              gap4,
              Container(
                padding: const EdgeInsets.all(Space.s4),
                decoration: BoxDecoration(color: premium ? c.accentSoft : c.surfaceAlt, borderRadius: BorderRadius.circular(Radii.lg)),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.crown(PhosphorIconsStyle.fill), color: premium ? c.onAccentSoft : c.textMuted),
                    gap3,
                    Expanded(
                      child: Text(
                        premium
                            ? 'Premium${plan?['ends_at'] != null ? ' until ${_date(DateTime.parse(plan!['ends_at'] as String).toLocal())}' : ''}'
                            : 'Free plan. Premium payments are coming soon.',
                        style: context.t.bodyMedium?.copyWith(color: premium ? c.onAccentSoft : c.text),
                      ),
                    ),
                  ],
                ),
              ),
              gap4,
              Row(
                children: [
                  _Stat(value: '${history.length}', label: 'Tests taken'),
                  gap3,
                  _Stat(value: avg == null ? '–' : '$avg%', label: 'Average score'),
                  gap3,
                  _Stat(value: p?['target_score'] == null ? '–' : '${p!['target_score']}', label: 'JAMB target'),
                ],
              ),
              if (exams.isNotEmpty) ...[
                gap4,
                Row(
                  children: [
                    Text('Preparing for', style: context.t.labelLarge),
                    gap3,
                    for (final e in exams)
                      Padding(
                        padding: const EdgeInsets.only(right: Space.s2),
                        child: ExamLogo(e, size: 32),
                      ),
                  ],
                ),
              ],
              gap5,
              Card(
                child: Column(
                  children: [
                    _Row(icon: PhosphorIcons.clockCounterClockwise(), title: 'Test history', onTap: () => context.push('/history')),
                    _Row(icon: PhosphorIcons.gear(), title: 'Settings', onTap: () => context.push('/settings')),
                    _Row(icon: PhosphorIcons.question(), title: 'Help and support', onTap: () => context.push('/help')),
                    _Row(icon: PhosphorIcons.info(), title: 'About SolutionTee', onTap: () => context.push('/legal?p=about')),
                    _Row(icon: PhosphorIcons.fileText(), title: 'Terms of use', onTap: () => context.push('/legal?p=terms')),
                    _Row(icon: PhosphorIcons.shieldCheck(), title: 'Privacy policy', onTap: () => context.push('/legal?p=privacy')),
                  ],
                ),
              ),
              gap4,
              OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Log out?'),
                      content: const Text('Tests saved on this phone will be removed. Tests already sent to SolutionTee stay in your account.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Log out')),
                      ],
                    ),
                  );
                  if (ok == true) {
                    await signOutAndWipe(ref);
                    if (context.mounted) context.go('/login');
                  }
                },
                icon: Icon(PhosphorIcons.signOut()),
                label: const Text('Log out'),
              ),
              gap2,
              TextButton(
                onPressed: () => context.push('/delete-account'),
                child: Text('Delete my account', style: TextStyle(color: c.error)),
              ),
            ],
          ),
        );
      }, onRetry: () => ref.invalidate(profileProvider)),
    );
  }

  Future<void> _editName(BuildContext context, WidgetRef ref, String current) async {
    final ctl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
          decoration: const InputDecoration(labelText: 'Full name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctl.text.trim()), child: const Text('Save')),
        ],
      ),
    );
    if (name == null || name.length < 2 || name == current) return;
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('profiles').update({'full_name': name}).eq('id', uid);
      ref.invalidate(profileProvider);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not save. Check your internet and try again.')));
    }
  }
}

String _date(DateTime d) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(Space.s3),
      decoration: BoxDecoration(
        color: context.c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: context.c.border),
      ),
      child: Column(
        children: [
          Text(value, style: context.t.titleLarge),
          Text(
            label,
            style: context.t.labelSmall?.copyWith(color: context.c.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.title, required this.onTap, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: Sizes.tapMin + 8,
    leading: Icon(icon, color: context.c.secondary),
    title: Text(title),
    subtitle: subtitle == null ? null : Text(subtitle!),
    trailing: Icon(PhosphorIcons.caretRight(), size: 18),
    onTap: onTap,
  );
}

// ---------------------------------------------------------------- history
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    return Scaffold(
      appBar: AppBar(title: const Text('Test history')),
      body: asyncView(ref.watch(historyProvider), (list) {
        if (list.isEmpty) {
          return StateView(
            icon: PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.fill),
            title: 'No tests yet',
            message: 'Tests you finish on this phone will show here.',
            action: FilledButton(onPressed: () => context.go('/test'), child: const Text('Start a test')),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(Space.s5),
          itemCount: list.length,
          separatorBuilder: (_, _) => gap3,
          itemBuilder: (_, i) {
            final a = list[i];
            final s = _score(a);
            final title = ((jsonDecode(a.configJson) as Map)['title'] as String?) ?? a.examCode;
            return Card(
              child: ListTile(
                minTileHeight: 72,
                leading: ExamLogo(a.examCode, size: 40),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Row(
                  children: [
                    Text(_date(a.submittedAt!.toLocal())),
                    if (!a.synced) ...[const SizedBox(width: 6), Icon(PhosphorIcons.cloudSlash(), size: 14, color: c.textMuted, semanticLabel: 'Not sent yet')],
                  ],
                ),
                trailing: s == null ? null : Text('${s['total']}/${s['max']}', style: context.t.titleMedium),
                onTap: () => context.push('/results/${a.id}'),
              ),
            );
          },
        );
      }),
    );
  }
}

// ---------------------------------------------------------------- settings
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(Space.s5),
        children: [
          Text('Appearance', style: context.t.titleMedium),
          gap3,
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
              ButtonSegment(value: ThemeMode.light, label: Text('Light')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
            ],
            selected: {s.theme},
            onSelectionChanged: (v) => n.update((x) => x.copyWith(theme: v.first)),
          ),
          gap5,
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  value: s.reduceMotion,
                  onChanged: (v) => n.update((x) => x.copyWith(reduceMotion: v)),
                  title: const Text('Reduce motion'),
                  subtitle: const Text('Fewer animations. Your phone setting is also followed.'),
                ),
                SwitchListTile(
                  value: s.dataSaver,
                  onChanged: (v) => n.update((x) => x.copyWith(dataSaver: v)),
                  title: const Text('Data saver'),
                  subtitle: const Text('Diagrams load only when you tap them.'),
                ),
              ],
            ),
          ),
          gap5,
          Text(
            'Version ${Config.appVersion}',
            style: context.t.bodySmall?.copyWith(color: context.c.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- help
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider).value ?? const {};
    final support = (settings['support'] as Map?) ?? const {};
    final wa = (support['whatsapp_link'] as String?) ?? 'https://wa.me/2348122445948';
    final waNumber = (support['whatsapp'] as String?) ?? '+2348122445948';
    final email = (support['email'] as String?) ?? _supportEmailFallback;
    return Scaffold(
      appBar: AppBar(title: const Text('Help and support')),
      body: ListView(
        padding: const EdgeInsets.all(Space.s5),
        children: [
          Text('We are happy to help', style: context.t.headlineSmall),
          gap2,
          Text('Message us about your account, payments or any question that looks wrong.', style: context.t.bodyMedium?.copyWith(color: context.c.textMuted)),
          gap5,
          Card(
            child: Column(
              children: [
                _Row(icon: PhosphorIcons.whatsappLogo(), title: 'Chat on WhatsApp', subtitle: waNumber, onTap: () => _open(context, Uri.parse(wa))),
                _Row(
                  icon: PhosphorIcons.envelopeSimple(),
                  title: 'Email support',
                  subtitle: email,
                  onTap: () => _open(context, Uri(scheme: 'mailto', path: email, queryParameters: {'subject': 'SolutionTee CBT help'})),
                ),
              ],
            ),
          ),
          gap5,
          Text('Common questions', style: context.t.titleMedium),
          gap2,
          const _Faq(
            q: 'Can I practise without internet?',
            a: 'Yes. Once a test has loaded, you can finish it offline. Your result is sent to SolutionTee the next time you are online.',
          ),
          const _Faq(
            q: 'What happens if my phone goes off during a test?',
            a: 'Every answer is saved as you tap it. Open the app and tap "Continue your test" on Home. The timer pauses while the app is closed.',
          ),
          const _Faq(
            q: 'How is my JAMB score worked out?',
            a: 'Each subject is marked out of 100, and the four subjects add up to a score out of 400, like the real UTME.',
          ),
          const _Faq(q: 'Why are some years locked?', a: 'Free accounts can open some years. Premium opens every year. Premium payments are coming soon.'),
        ],
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq({required this.q, required this.a});
  final String q, a;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text(q, style: context.t.labelLarge),
    childrenPadding: const EdgeInsets.only(bottom: Space.s3),
    expandedAlignment: Alignment.centerLeft,
    children: [Text(a, style: context.t.bodyMedium)],
  );
}

// ---------------------------------------------------------------- about / terms / privacy
class LegalScreen extends ConsumerWidget {
  const LegalScreen({super.key, required this.page});
  final String page;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final settings = ref.watch(appSettingsProvider).value ?? const {};
    final company = (settings['company'] as Map?) ?? const {};
    final disclaimer = (settings['disclaimer'] as String?) ?? Config.disclaimer;
    final website = (company['website'] as String?) ?? 'https://solutiontee.com';
    final (title, path) = switch (page) {
      'terms' => ('Terms of use', 'terms'),
      'privacy' => ('Privacy policy', 'privacy'),
      _ => ('About SolutionTee', ''),
    };

    final disclaimerBox = Container(
      padding: const EdgeInsets.all(Space.s4),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.border),
      ),
      child: Text(disclaimer, style: context.t.bodySmall),
    );

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(Space.s5),
        children: [
          if (path.isEmpty) ...[
            Image.asset('assets/brand/solutiontee-mark-transparent.png', height: 64, alignment: Alignment.centerLeft),
            gap4,
            Text('SolutionTee CBT', style: context.t.headlineSmall),
            Text('Learn. Think. Solve.', style: context.t.bodyMedium?.copyWith(color: c.textMuted)),
            gap4,
            Text(
              'Practise JAMB, WAEC and NECO past questions in a real CBT setting, see your score at once and learn from every mistake.',
              style: context.t.bodyLarge,
            ),
            gap5,
            disclaimerBox,
            gap5,
            Text((company['name'] as String?) ?? 'SolutionTee', style: context.t.labelLarge),
            if (company['rc_number'] != null) Text(company['rc_number'] as String, style: context.t.bodySmall),
            if (company['address'] != null) Text(company['address'] as String, style: context.t.bodySmall),
            gap3,
            TextButton(onPressed: () => _open(context, Uri.parse(website)), child: Text(website.replaceFirst('https://', ''))),
            Text('Version ${Config.appVersion}', style: context.t.bodySmall?.copyWith(color: c.textMuted)),
          ] else ...[
            // The full legal text is being reviewed by our lawyer and will live on the website (one source of truth).
            Text('The full $title is on our website.', style: context.t.bodyLarge),
            gap4,
            FilledButton.icon(
              onPressed: () => _open(context, Uri.parse('$website/$path')),
              icon: Icon(PhosphorIcons.arrowSquareOut()),
              label: Text('Read the $title'),
            ),
            gap5,
            disclaimerBox,
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- delete account (Google Play requirement)
class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _ctl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).deleteAccount();
      await signOutAndWipe(ref);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Your account and data have been deleted.')));
      context.go('/welcome');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final ready = _ctl.text.trim() == 'DELETE';
    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: ListView(
        padding: const EdgeInsets.all(Space.s5),
        children: [
          Icon(PhosphorIcons.warning(PhosphorIconsStyle.fill), color: c.error, size: 48),
          gap4,
          Text('This cannot be undone', style: context.t.headlineSmall),
          gap3,
          Text(
            'Deleting your account removes your profile, test history and scores from SolutionTee. Any Premium time left will be lost.',
            style: context.t.bodyMedium,
          ),
          gap5,
          TextField(
            controller: _ctl,
            enabled: !_busy,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Type DELETE to confirm'),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            gap3,
            Text(
              _error!,
              style: TextStyle(color: c.error, fontWeight: FontWeight.w700),
            ),
          ],
          gap5,
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: c.error, foregroundColor: Colors.white),
            onPressed: ready && !_busy ? _delete : null,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Delete my account'),
          ),
          gap3,
          OutlinedButton(onPressed: _busy ? null : () => context.pop(), child: const Text('Keep my account')),
        ],
      ),
    );
  }
}
