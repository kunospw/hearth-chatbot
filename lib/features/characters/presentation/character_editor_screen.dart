import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/hearth_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/character_avatar.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/motion_widgets.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/toast.dart';
import '../../../data/mock/mock_data.dart';
import '../../chat/data/conversation_repository.dart';
import '../../library/data/library_repository.dart';
import '../../relationship/data/relationship_providers.dart';
import '../../relationship/domain/relationship_models.dart';
import '../data/character_repository.dart';
import '../data/draft_repository.dart';
import '../domain/character.dart';
import '../domain/character_form.dart';

/// Picks a picture from the phone's photos and returns its bytes (null if the
/// user backs out). Overridable so tests don't need a real picker.
final pickPictureProvider = Provider<Future<Uint8List?> Function()>((ref) {
  return () async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file?.readAsBytes();
  };
});

const _uuid = Uuid();

/// Create or edit a character. Only the name is required; More details stays
/// collapsed. Leaving with changes asks (Save draft / Keep editing / Discard).
/// "Save & start chat" replaces this screen, so Back from the new chat goes home.
class CharacterEditorScreen extends ConsumerStatefulWidget {
  const CharacterEditorScreen({
    super.key,
    this.characterId,
    this.draftId,
    this.initialName,
  });

  /// Set when editing an existing character.
  final String? characterId;

  /// Set when resuming a saved draft.
  final String? draftId;

  /// Pre-fills the name (from "Create “query”" on the home search).
  final String? initialName;

  @override
  ConsumerState<CharacterEditorScreen> createState() =>
      _CharacterEditorScreenState();
}

class _CharacterEditorScreenState extends ConsumerState<CharacterEditorScreen> {
  late CharacterForm _form;
  late CharacterForm _initial;
  Character? _base;
  String? _draftId;
  bool _ready = false;
  bool _advancedOpen = false;
  bool _bypassGuard = false;

  final _name = TextEditingController();
  final _short = TextEditingController();
  final _personality = TextEditingController();
  final _greeting = TextEditingController();
  final _backstory = TextEditingController();
  final _speaking = TextEditingController();
  final _examples = TextEditingController();
  final _rules = TextEditingController();
  final _relationships = TextEditingController();
  final _scenario = TextEditingController();

  bool get _editing => widget.characterId != null;
  bool get _dirty => _form != _initial;

  @override
  void initState() {
    super.initState();
    _draftId = widget.draftId;
    if (!_editing) _load(null);
    // A toast from the screen we came from must not sit on top of Save.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ScaffoldMessenger.of(context).clearSnackBars();
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name, _short, _personality, _greeting, _backstory, _speaking, //
      _examples, _rules, _relationships, _scenario,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Sets up the form from the character being edited, a draft, or blank.
  void _load(Character? base) {
    _base = base;
    final draft = widget.draftId == null
        ? null
        : ref.read(draftsProvider.notifier).byId(widget.draftId!);
    final original = base != null
        ? CharacterForm.fromCharacter(base)
        : const CharacterForm();
    _initial = original;
    _form =
        draft?.form ??
        (widget.initialName != null && base == null
            ? original.copyWith(name: widget.initialName)
            : original);
    _name.text = _form.name;
    _short.text = _form.short;
    _personality.text = _form.personality;
    _greeting.text = _form.greeting;
    _backstory.text = _form.backstory;
    _speaking.text = _form.speaking;
    _examples.text = _form.examples;
    _rules.text = _form.rules;
    _relationships.text = _form.relationships;
    _scenario.text = _form.scenario;
    _ready = true;
  }

  void _change(CharacterForm next) => setState(() => _form = next);

  /// How you know each other. A greeting that is still the one written for
  /// the old starting point follows the new one.
  void _setStartingPoint(StartingPoint start) {
    var next = _form.copyWith(startingPoint: start);
    final f = _form.first;
    if (f.isNotEmpty &&
        _form.greeting.trim() == defaultGreeting(f, _form.startingPoint)) {
      final g = defaultGreeting(f, start);
      _greeting.text = g;
      next = next.copyWith(greeting: g);
    }
    _change(next);
  }

  // ── picture ───────────────────────────────────────────────────────────

  Future<void> _pickPicture() async {
    try {
      final bytes = await ref.read(pickPictureProvider)();
      if (bytes == null || !mounted) return;
      _change(_form.copyWith(imageBytes: bytes, imageRemoved: false));
    } catch (_) {
      if (mounted) showToast(context, 'We couldn’t open your photos.');
    }
  }

  void _removePicture() =>
      _change(_form.copyWith(clearImageBytes: true, imageRemoved: true));

  bool get _hasPicture =>
      _form.imageBytes != null ||
      (!_form.imageRemoved && (_base?.hasPortrait ?? false));

  // ── leaving ───────────────────────────────────────────────────────────

  void _leave() {
    setState(() => _bypassGuard = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.canPop() ? context.pop() : context.go(Routes.characters);
    });
  }

  /// Saves the form as a draft (an edit of an existing character keeps its id).
  void _saveDraft({bool leave = true}) {
    final id = _draftId ?? _uuid.v4();
    ref
        .read(draftsProvider.notifier)
        .save(
          CharacterDraft(id: id, form: _form, editingId: widget.characterId),
        );
    _draftId = id;
    if (leave) {
      showToast(context, 'Draft saved', aboveBottomBar: false);
      _leave();
    }
  }

  Future<void> _onPopBlocked() async {
    final choice = await showDiscardSheet(
      context,
      title: 'Leave without saving?',
      message:
          'You’ve started on this character. Save a draft to finish later, '
          'or discard the changes.',
    );
    if (!mounted) return;
    switch (choice) {
      case DiscardChoice.saveDraft:
        _saveDraft();
      case DiscardChoice.discard:
        _leave();
      case DiscardChoice.keepEditing:
        break;
    }
  }

  // ── saving ────────────────────────────────────────────────────────────

  bool _saving = false;

  Future<void> _save() async {
    if (!_form.hasName || _saving) return;
    final id = widget.characterId ?? _uuid.v4();
    final character = _form.toCharacter(id, base: _base);
    setState(() => _saving = true);
    try {
      await ref.read(charactersProvider.notifier).save(character);
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        showToast(
          context,
          'Couldn’t save. Check your connection and try again.',
          aboveBottomBar: true,
        );
      }
      return;
    }
    if (_draftId != null) ref.read(draftsProvider.notifier).remove(_draftId!);
    if (!mounted) return;

    if (_editing) {
      var message = 'Changes saved';
      // A new starting point starts your story with them over from there.
      if (_base != null && character.startingPoint != _base!.startingPoint) {
        try {
          await ref
              .read(relationshipsProvider.notifier)
              .setStartingPoint(id, character.startingPoint);
          message =
              'Changes saved — starting point: ${character.startingPoint.label}';
        } catch (_) {
          message =
              'Changes saved, but your story couldn’t start over. '
              'Try again in the relationship journal.';
        }
        if (!mounted) return;
      }
      setState(() => _bypassGuard = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.canPop() ? context.pop() : context.go(Routes.characters);
        showToast(context, message, aboveBottomBar: false);
      });
      return;
    }
    // Save & start chat: replace the editor, so Back from the chat goes home.
    final conversationId = ref
        .read(conversationsProvider.notifier)
        .startNew(character);
    context.pushReplacement(Routes.chat(conversationId));
  }

  // ── build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_editing && !_ready) {
      final async = ref.watch(characterProvider(widget.characterId!));
      return async.when(
        loading: () =>
            Scaffold(appBar: AppBar(), body: const SkeletonRows(count: 4)),
        error: (_, _) =>
            Scaffold(appBar: AppBar(), body: const SizedBox.shrink()),
        data: (ch) {
          if (ch == null) {
            return Scaffold(
              appBar: AppBar(),
              body: EmptyState(
                title: 'We can’t find this character',
                primaryLabel: 'Back to characters',
                onPrimary: () => context.go(Routes.characters),
              ),
            );
          }
          // Load once, then rebuild with the form.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_ready) setState(() => _load(ch));
          });
          return Scaffold(appBar: AppBar(), body: const SkeletonRows(count: 4));
        },
      );
    }

    final c = context.hc;
    final t = context.ht;
    final universes = ref.watch(universesProvider).valueOrNull ?? const [];

    return PopScope(
      canPop: !_dirty || _bypassGuard,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onPopBlocked();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(
                  Space.xs,
                  Space.sm,
                  Space.md,
                  Space.sm,
                ),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.outline)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Close editor',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Expanded(
                      child: Text(
                        _editing ? 'Edit character' : 'New character',
                        style: t.label.copyWith(fontSize: 18),
                      ),
                    ),
                    // At large text sizes the label becomes an icon so the header fits.
                    if (MediaQuery.textScalerOf(context).scale(1) > 1.3)
                      IconButton(
                        tooltip: 'Save draft',
                        icon: const Icon(Icons.bookmark_add_outlined),
                        onPressed: _form.isBlank && !_dirty
                            ? null
                            : () => _saveDraft(),
                      )
                    else
                      TextButton(
                        onPressed: _form.isBlank && !_dirty
                            ? null
                            : () => _saveDraft(),
                        child: const Text('Save draft'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    Space.gutter,
                    Space.gutter,
                    Space.gutter,
                    Space.xxl,
                  ),
                  children: [
                    _PictureSection(
                      form: _form,
                      base: _base,
                      hasPicture: _hasPicture,
                      onPick: _pickPicture,
                      onRemove: _removePicture,
                      onSwatch: (i) => _change(_form.copyWith(swatch: i)),
                    ),
                    const SizedBox(height: Space.xl),
                    _Field(
                      label: 'Name',
                      controller: _name,
                      hint: 'e.g. Captain Mara Quill',
                      capitalization: TextCapitalization.words,
                      onChanged: (v) => _change(_form.copyWith(name: v)),
                    ),
                    _Field(
                      label: 'Short description',
                      helper: 'One line shown on their card.',
                      controller: _short,
                      hint: 'A smuggler with a soft spot for strays',
                      onChanged: (v) => _change(_form.copyWith(short: v)),
                    ),
                    _Field(
                      label: 'Personality',
                      helper:
                          'A few words is plenty — how do they come across?',
                      controller: _personality,
                      hint: 'Charming, reckless, secretly sentimental',
                      lines: 3,
                      onChanged: (v) => _change(_form.copyWith(personality: v)),
                    ),
                    _Field(
                      label: 'Greeting',
                      helper:
                          'Their first message. Put actions in *asterisks*. '
                          'Leave it blank and we’ll write one that fits how you know each other.',
                      controller: _greeting,
                      hint: '*She glances up from the map.* "You\'re late. Sit — we sail at dawn."',
                      lines: 4,
                      onChanged: (v) => _change(_form.copyWith(greeting: v)),
                    ),
                    _StartingPointField(
                      first: _form.first,
                      value: _form.startingPoint,
                      restarts:
                          _editing &&
                          _base != null &&
                          _form.startingPoint != _base!.startingPoint,
                      onChanged: _setStartingPoint,
                    ),
                    _MoreDetails(
                      open: _advancedOpen,
                      onToggle: () =>
                          setState(() => _advancedOpen = !_advancedOpen),
                      children: [
                        _Field(
                          label: 'Backstory',
                          controller: _backstory,
                          hint: 'Where they come from and what shaped them',
                          lines: 3,
                          compact: true,
                          onChanged: (v) =>
                              _change(_form.copyWith(backstory: v)),
                        ),
                        _Field(
                          label: 'Speaking style',
                          controller: _speaking,
                          hint: 'Clipped sentences, sailor slang',
                          compact: true,
                          onChanged: (v) =>
                              _change(_form.copyWith(speaking: v)),
                        ),
                        _Field(
                          label: 'Example dialogue',
                          helper: 'A line or two in their voice helps them sound like themselves.',
                          controller: _examples,
                          hint: '"Rules are for people with nowhere to be."',
                          lines: 3,
                          compact: true,
                          onChanged: (v) =>
                              _change(_form.copyWith(examples: v)),
                        ),
                        _Field(
                          label: 'Things they always or never do',
                          controller: _rules,
                          hint: 'Never breaks a promise. Always calls you \'kid\'.',
                          lines: 2,
                          compact: true,
                          onChanged: (v) => _change(_form.copyWith(rules: v)),
                        ),
                        _Field(
                          label: 'Relationships',
                          controller: _relationships,
                          hint: 'Owes the harbor master a favor',
                          compact: true,
                          onChanged: (v) =>
                              _change(_form.copyWith(relationships: v)),
                        ),
                        _Field(
                          label: 'Opening scenario',
                          controller: _scenario,
                          hint: 'A storm traps you both in a roadside inn',
                          compact: true,
                          onChanged: (v) =>
                              _change(_form.copyWith(scenario: v)),
                        ),
                        Text('Universe', style: t.label.copyWith(fontSize: 14)),
                        Text(
                          'They’ll share that world’s memories and lore.',
                          style: t.caption,
                        ),
                        const SizedBox(height: Space.sm),
                        Wrap(
                          spacing: Space.sm,
                          runSpacing: Space.xs,
                          children: [
                            HearthChip(
                              label: 'None',
                              selected: _form.universeId == null,
                              onTap: () =>
                                  _change(_form.copyWith(clearUniverse: true)),
                            ),
                            for (final u in universes)
                              HearthChip(
                                label: u.name,
                                selected: _form.universeId == u.id,
                                onTap: () =>
                                    _change(_form.copyWith(universeId: u.id)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ToastInset(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    Space.lg,
                    Space.md,
                    Space.lg,
                    Space.sm,
                  ),
                  decoration: BoxDecoration(
                    color: c.bg,
                    border: Border(top: BorderSide(color: c.outline)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!_form.hasName)
                          Padding(
                            padding: const EdgeInsets.only(bottom: Space.sm),
                            child: Text(
                              'Add a name to continue — everything else is optional.',
                              textAlign: TextAlign.center,
                              style: t.caption,
                            ),
                          ),
                        FilledButton(
                          onPressed: _form.hasName && !_saving ? _save : null,
                          child: _saving
                              ? const SizedBox.square(
                                  dimension: Space.xl,
                                  child: CircularProgressIndicator(
                                    strokeWidth: Sizes.stroke,
                                  ),
                                )
                              : Text(
                                  _editing
                                      ? 'Save changes'
                                      : 'Save & start chat',
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PictureSection extends StatelessWidget {
  const _PictureSection({
    required this.form,
    required this.base,
    required this.hasPicture,
    required this.onPick,
    required this.onRemove,
    required this.onSwatch,
  });

  final CharacterForm form;
  final Character? base;
  final bool hasPicture;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final ValueChanged<int> onSwatch;

  static const double _preview = 88;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    final sw =
        MockData.swatches[form.swatch.clamp(0, MockData.swatches.length - 1)];
    final keep = form.imageBytes == null && !form.imageRemoved;
    final big = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final avatar = CharacterAvatar(
      tile: sw.tile,
      ink: sw.ink,
      initial: form.hasName ? form.first.substring(0, 1).toUpperCase() : '?',
      bytes: form.imageBytes ?? (keep ? base?.portraitBytes : null),
      asset: keep ? base?.portraitAsset : null,
      url: keep ? base?.portraitUrl : null,
      size: _preview,
      radius: Radii.card + 6,
    );
    final actions = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.image_outlined),
          label: Text(hasPicture ? 'Change picture' : 'Add picture'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(Hit.primary, Hit.inline),
          ),
        ),
        if (hasPicture)
          TextButton(
            onPressed: onRemove,
            child: Text(
              'Remove picture',
              style: t.label.copyWith(fontSize: 14, color: c.textMuted),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: Space.xs),
            child: Text(
              'Optional. Until you add one, their initial is shown.',
              style: t.caption,
            ),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // At large text sizes the picture and its buttons stack, so nothing overflows.
        if (big) ...[
          avatar,
          const SizedBox(height: Space.md),
          actions,
        ] else
          Row(
            children: [
              avatar,
              const SizedBox(width: Space.lg),
              Expanded(child: actions),
            ],
          ),
        const SizedBox(height: Space.md),
        Text(
          'Colour behind the initial, and while a picture loads',
          style: t.caption,
        ),
        const SizedBox(height: Space.xs),
        Wrap(
          children: [
            for (var i = 0; i < MockData.swatches.length; i++)
              Semantics(
                button: true,
                selected: form.swatch == i,
                label: MockData.swatches[i].label,
                excludeSemantics: true,
                onTap: () => onSwatch(i),
                child: InkResponse(
                  onTap: () => onSwatch(i),
                  radius: Hit.inline / 2,
                  child: SizedBox(
                    width: Hit.inline,
                    height: Hit.inline,
                    child: Center(
                      child: AnimatedContainer(
                        duration: Motion.press,
                        width: Space.xl + Space.sm - 2,
                        height: Space.xl + Space.sm - 2,
                        decoration: BoxDecoration(
                          color: MockData.swatches[i].tile,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: form.swatch == i
                                ? c.text
                                : Colors.transparent,
                            width: Sizes.stroke,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.helper,
    this.hint,
    this.lines = 1,
    this.compact = false,
    this.capitalization = TextCapitalization.sentences,
  });

  final String label;
  final String? helper;
  final String? hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int lines;
  final bool compact;
  final TextCapitalization capitalization;

  @override
  Widget build(BuildContext context) {
    final t = context.ht;
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? Space.lg : Space.xl - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.label.copyWith(fontSize: compact ? 14 : 15)),
          if (helper != null) Text(helper!, style: t.caption),
          const SizedBox(height: Space.sm - 2),
          TextField(
            controller: controller,
            onChanged: onChanged,
            minLines: lines,
            maxLines: lines == 1 ? 1 : lines + 4,
            textCapitalization: capitalization,
            keyboardType: lines == 1
                ? TextInputType.text
                : TextInputType.multiline,
            style: t.chat,
            decoration: InputDecoration(
              hintText: hint,
              constraints: const BoxConstraints(minHeight: Hit.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// "You and Mara": how you know each other when a story with them begins.
/// Every new relationship with the character starts here.
class _StartingPointField extends StatelessWidget {
  const _StartingPointField({
    required this.first,
    required this.value,
    required this.restarts,
    required this.onChanged,
  });

  final String first;
  final StartingPoint value;

  /// Editing a character: saving starts the story with them over.
  final bool restarts;
  final ValueChanged<StartingPoint> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    final who = first.isEmpty ? 'them' : first;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.xl - 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('You and $who', style: t.label.copyWith(fontSize: 15)),
          Text(
            'How you know each other when the story begins.',
            style: t.caption,
          ),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.xs,
            children: [
              for (final s in StartingPoint.values)
                HearthChip(
                  label: s.label,
                  selected: value == s,
                  onTap: () => onChanged(s),
                ),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(value.hint, style: t.caption.copyWith(color: c.textMuted)),
          if (restarts)
            Padding(
              padding: const EdgeInsets.only(top: Space.xs),
              child: Text(
                'When you save, your story with $who starts again from here. '
                'Earlier moments stay in the relationship journal.',
                style: t.caption.copyWith(color: c.primaryInk),
              ),
            ),
        ],
      ),
    );
  }
}

class _MoreDetails extends StatelessWidget {
  const _MoreDetails({
    required this.open,
    required this.onToggle,
    required this.children,
  });

  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.hc;
    final t = context.ht;
    return Material(
      color: c.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card - 2),
        side: BorderSide(color: c.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: 'More details, optional',
            excludeSemantics: true,
            onTap: onToggle,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: Hit.primary + Space.lg,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.sm + 2,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                style: t.label.copyWith(fontSize: 15),
                                children: [
                                  const TextSpan(text: 'More details '),
                                  TextSpan(
                                    text: '· optional',
                                    style: t.body.copyWith(color: c.textSubtle),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Backstory, speaking style, example dialogue, world',
                              style: t.caption,
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: reduceMotion(context)
                            ? Duration.zero
                            : Motion.press,
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: reduceMotion(context) ? Duration.zero : Motion.sheet,
            curve: Motion.emphasizedDecelerate,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.lg,
                      Space.sm,
                      Space.lg,
                      Space.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
