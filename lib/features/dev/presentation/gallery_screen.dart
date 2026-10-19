import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/chat_tile.dart';
import '../../../core/widgets/composer.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/inline_notice.dart';
import '../../../core/widgets/jump_to_latest_pill.dart';
import '../../../core/widgets/message_actions.dart';
import '../../../core/widgets/rich_roleplay_text.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/toast.dart';
import '../../../data/mock/mock_data.dart';
import '../../characters/presentation/widgets/character_card.dart';
import '../../characters/presentation/widgets/character_grid.dart';

/// Debug-only catalogue of every shared widget in each of its states, with a
/// 200% text-scale switch. Not part of the spec; registered only in debug.
class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  bool _bigText = false;

  // streaming demo
  String _streamed = '';
  bool _streaming = false;
  Timer? _timer;

  // controls demo
  String _seg = 'dark';
  bool _chip = true;
  bool _switch = true;
  int _radio = 0;
  int _alt = 1;
  bool _pill = true;
  bool _composerBusy = false;
  String _stateDemo = 'none';

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _stream() {
    _timer?.cancel();
    final words = MockData.replies['vesper']![0].split(' ');
    var i = 0;
    setState(() {
      _streamed = '';
      _streaming = true;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 60), (t) {
      if (i >= words.length) {
        t.cancel();
        setState(() => _streaming = false);
        return;
      }
      setState(() => _streamed += (i == 0 ? '' : ' ') + words[i++]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    final c = context.hc;
    final chars = MockData.characters;
    final v = chars[0];

    Widget section(String title, List<Widget> kids) => Padding(
      padding: const EdgeInsets.only(bottom: Space.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: t.overline),
          const SizedBox(height: Space.md),
          ...kids,
        ],
      ),
    );

    final body = Scaffold(
      appBar: AppBar(
        title: const Text('Widget gallery'),
        actions: [
          Row(
            children: [
              Text('200% text', style: t.caption),
              Switch(
                value: _bigText,
                onChanged: (v) => setState(() => _bigText = v),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          section('Avatars', [
            Wrap(
              spacing: Space.md,
              runSpacing: Space.md,
              children: [
                CharacterAvatar.of(chars[0], size: Sizes.avatarLarge),
                CharacterAvatar.of(
                  chars[2],
                  size: Sizes.avatarLarge,
                  shape: AvatarShape.circle,
                ),
                CharacterAvatar.of(chars[1], size: Sizes.avatarLarge),
                CharacterAvatar.of(
                  chars[3],
                  size: Sizes.avatarLarge,
                  shape: AvatarShape.circle,
                ),
                CharacterAvatar(
                  tile: chars[0].tile,
                  ink: chars[0].ink,
                  initial: 'E',
                  asset: 'assets/portraits/missing.svg',
                  size: Sizes.avatarLarge,
                ),
              ],
            ),
            Text(
              'Last one: the image failed, so the initial stays.',
              style: t.caption,
            ),
          ]),
          section('Character cards', [
            CharacterGrid(
              children: [
                CharacterCard(
                  character: chars[0],
                  onTap: () => showToast(context, 'Opened Vesper'),
                ),
                CharacterCard(character: chars[1], onTap: () {}, index: 1),
                CharacterCard(character: chars[2], onTap: () {}, index: 2),
                CreateCharacterCard(onTap: () {}, index: 3),
              ],
            ),
          ]),
          section('Continue card + chat tile', [
            ContinueCard(
              avatar: CharacterAvatar.of(v, size: Sizes.avatarLarge),
              title: 'The letter from the north tide',
              subtitle: 'Vesper · 2m ago',
              preview: 'Your word. She seems to weigh it like rope. Fine. They stay sealed until we open them together.',
              onTap: () {},
            ),
            const SizedBox(height: Space.md),
            ChatTile(
              avatar: CharacterAvatar.of(chars[1], size: Sizes.avatar),
              title: 'Rooftop delivery',
              subtitle: 'Jun · Yesterday',
              preview: 'Okay, so — good news, I found your package.',
              pinned: true,
              onTap: () {},
              onMore: () => showOptionsSheet<String>(
                context,
                options: const [
                  SheetOption(
                    value: 'pin',
                    label: 'Unpin',
                    icon: Icons.push_pin_outlined,
                  ),
                  SheetOption(
                    value: 'rename',
                    label: 'Rename',
                    icon: Icons.edit_outlined,
                  ),
                  SheetOption(
                    value: 'delete',
                    label: 'Delete chat',
                    icon: Icons.delete_outline,
                    destructive: true,
                  ),
                ],
              ),
            ),
          ]),
          section('Roleplay text (chat and story)', [
            RichRoleplayText(MockData.replies['jun']![0], style: t.chatStyle()),
            const SizedBox(height: Space.lg),
            RichRoleplayText(
              MockData.replies['vesper']![0],
              style: t.storyStyle(),
            ),
          ]),
          section('Streaming (half-written markup stays tidy)', [
            FilledButton(
              onPressed: _stream,
              child: const Text('Stream a reply'),
            ),
            const SizedBox(height: Space.md),
            if (_streamed.isNotEmpty || _streaming)
              RichRoleplayText(
                _streamed,
                style: t.chatStyle(),
                streaming: _streaming,
              ),
          ]),
          section('Message actions', [
            MessageActions(
              altIndex: _alt,
              altCount: 3,
              onPrevAlt: () => setState(() => _alt--),
              onNextAlt: () => setState(() => _alt++),
              onRewrite: () => showToast(context, 'Rewriting…'),
              onCopy: () {
                Clipboard.setData(
                  const ClipboardData(text: 'Copied from gallery'),
                );
                showToast(context, 'Copied');
              },
              onEdit: () {},
            ),
          ]),
          section('Inline notice (model limit)', [
            InlineNotice(
              title: 'Daily limit reached',
              message: 'Ember has used all of today’s free replies. Your message is saved.',
              primaryLabel: 'Switch model',
              onPrimary: () {},
              secondaryLabel: 'Try again',
              onSecondary: () {},
            ),
          ]),
          section('Composer', [
            ClipRRect(
              borderRadius: BorderRadius.circular(Radii.card),
              child: Column(
                children: [
                  Composer(
                    isGenerating: _composerBusy,
                    onSend: (_) {
                      setState(() => _composerBusy = true);
                      Timer(const Duration(seconds: 3), () {
                        if (mounted) setState(() => _composerBusy = false);
                      });
                    },
                    onStop: () => setState(() => _composerBusy = false),
                  ),
                  Composer(
                    variant: ComposerVariant.story,
                    isGenerating: _composerBusy,
                    onSend: (text) => showToast(
                      context,
                      text.isEmpty ? 'Continue' : 'Sent: $text',
                    ),
                    onStop: () => setState(() => _composerBusy = false),
                  ),
                ],
              ),
            ),
            Text(
              'Send a message to see Send turn into Stop (3s). Story: empty = Continue.',
              style: t.caption,
            ),
          ]),
          section('Controls', [
            HearthSegmented<String>(
              options: const {
                'dark': 'Dark',
                'black': 'True black',
                'system': 'System',
              },
              value: _seg,
              onChanged: (v) => setState(() => _seg = v),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              children: [
                HearthChip(
                  label: 'Pinned',
                  selected: _chip,
                  onTap: () => setState(() => _chip = !_chip),
                ),
                HearthChip(
                  label: 'Saltmarsh',
                  icon: Icons.public,
                  onTap: () {},
                ),
              ],
            ),
            SwitchRow(
              title: 'Show relationship notes',
              subtitle: 'A muted line when something shifts',
              value: _switch,
              onChanged: (v) => setState(() => _switch = v),
            ),
            for (var i = 0; i < 3; i++)
              RadioRow(
                title: MockData.models[i].name,
                subtitle: MockData.models[i].description,
                status: i == 0
                    ? 'Available · 2 of 30 free replies left today'
                    : i == 1
                    ? 'Daily limit reached · resets 07:00'
                    : 'Busy right now',
                statusColor: i == 0 ? c.ok : c.textSubtle,
                enabled: i != 2,
                selected: _radio == i,
                onTap: () => setState(() => _radio = i),
              ),
          ]),
          section('Sheets and toasts', [
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                OutlinedButton(
                  onPressed: () async {
                    final r = await showDiscardSheet(context);
                    if (context.mounted) showToast(context, 'Chose ${r.name}');
                  },
                  child: const Text('Discard sheet'),
                ),
                OutlinedButton(
                  onPressed: () async {
                    final ok = await showConfirmDeleteSheet(
                      context,
                      title: 'Delete this chat?',
                      message: 'This can’t be undone.',
                      keepLabel: 'Keep chat',
                      deleteLabel: 'Delete chat',
                    );
                    if (context.mounted) {
                      showToast(context, ok ? 'Deleted' : 'Kept');
                    }
                  },
                  child: const Text('Confirm delete'),
                ),
                OutlinedButton(
                  onPressed: () => showToast(
                    context,
                    'Memory deleted',
                    onUndo: () => showToast(context, 'Restored'),
                  ),
                  child: const Text('Toast with Undo'),
                ),
                OutlinedButton(
                  onPressed: () => showToast(context, 'Copied'),
                  child: const Text('Toast'),
                ),
              ],
            ),
          ]),
          section('New-reply pill', [
            Center(
              child: JumpToLatestPill(
                visible: _pill,
                onTap: () => setState(() => _pill = false),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _pill = true),
              child: const Text('Show again'),
            ),
          ]),
          section('Home states', [
            HearthSegmented<String>(
              options: const {
                'none': 'Hide',
                'load': 'Loading',
                'first': 'First run',
                'off': 'Offline',
              },
              value: _stateDemo,
              onChanged: (v) => setState(() => _stateDemo = v),
            ),
            const SizedBox(height: Space.md),
            if (_stateDemo != 'none')
              SizedBox(
                height: 460,
                child: switch (_stateDemo) {
                  'load' => const HomeSkeleton(),
                  'first' => FirstRunState(
                    icon: const Icon(
                      Icons.local_fire_department_outlined,
                      size: Sizes.avatar,
                    ),
                    onMeetSamples: () {},
                    onCreate: () {},
                  ),
                  _ => OfflineState(
                    onRetry: () => setState(() => _stateDemo = 'load'),
                  ),
                },
              ),
            const SizedBox(height: Space.md),
            const OfflineBanner(),
          ]),
        ],
      ),
    );

    // The 200% switch mirrors the accessibility requirement (SPEC §9).
    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: _bigText ? const TextScaler.linear(2) : null),
      child: body,
    );
  }
}
