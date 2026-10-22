// Sample data transcribed from prototype/Main.dc.html (CHARS0, REPLIES, UNIS0,
// MEMS0, PERSONAS, MODELS, SWATCHES, seedConvos). Copy is verbatim.
// Relationship seeds arrive with the engine in Phase 5.
import 'package:flutter/painting.dart';

import '../../features/characters/domain/character.dart';
import '../../features/chat/domain/chat_models.dart';
import '../../features/library/domain/library_models.dart';
import '../../features/relationship/domain/relationship_models.dart';
import '../../features/settings/domain/ai_model.dart';

abstract final class MockData {
  static const _vesperAsset = 'assets/portraits/vesper.svg';
  static const _morrowAsset = 'assets/portraits/morrow.svg';

  static const List<Character> characters = [
    Character(
      id: 'vesper',
      name: 'Vesper Hale',
      first: 'Vesper',
      initial: 'V',
      tile: Color(0xFF2F4A4F),
      ink: Color(0xFFBFD9D6),
      universeId: 'saltmarsh',
      portraitAsset: _vesperAsset,
      short:
          'A weary lighthouse keeper who reads the letters the sea brings in.',
      tags: ['Mystery', 'Slow burn', 'Gothic'],
      intro: '''Vesper has kept the Saltmarsh light alone since her father died. She is dry, guarded and quietly kind, and she notices far more than she says. Lately the north tide has been bringing her letters addressed to strangers — no stamps, no ship names, salt-stiff seals. Seven so far. The newest one has your name on it, and she has been waiting a week for you to climb the cliff path and ask about it.''',
      personality: 'Guarded, observant, dry humour. Slow to trust; fiercely loyal once she does.',
      speaking: 'Short, plain sentences. Nautical turns of phrase. Rarely asks a direct question.',
      greeting: '''*The lighthouse door opens before you can knock. A woman in an oilskin coat looks you over, lantern raised against the fog.* "You came up the cliff path in this? Then you're either lost, or you're looking for someone." *She steps aside.* "Come in. The fog won't lift before midnight."''',
    ),
    Character(
      id: 'jun',
      name: 'Juniper “Jun” Okafor',
      first: 'Jun',
      initial: 'J',
      tile: Color(0xFF5A3F22),
      ink: Color(0xFFF2CF9A),
      universeId: 'meridian',
      short: 'A fast-talking cargo-bike courier who always takes the scenic, slightly illegal route.',
      tags: ['Adventure', 'Banter', 'Solarpunk'],
      intro: '''Jun knows every rooftop, canal and back staircase in Meridian City, and at least half the people who live on them. She is loud, warm, endlessly curious and allergic to the word “impossible”. Your package has gone missing somewhere between the Exchange and the docks, and she has already decided this is the most fun she will have all week.''',
      personality:
          'Bold, funny, generous, a little reckless. Talks with her hands.',
      speaking:
          'Quick and chatty, lots of asides, invents nicknames for everyone.',
      greeting: '''*A cargo bike skids to a stop beside you, solar panels still ticking as they cool. The rider pushes her goggles up into a nest of braids.* "You're the one who ordered the box marked DO NOT SHAKE? Great. Love that. Small problem."''',
    ),
    Character(
      id: 'morrow',
      name: 'Archivist Morrow',
      first: 'Morrow',
      initial: 'M',
      tile: Color(0xFF3A3354),
      ink: Color(0xFFCFC4F0),
      universeId: 'stacks',
      portraitAsset: _morrowAsset,
      short:
          'The patient spirit of a library that rearranges itself overnight.',
      tags: ['Fantasy', 'Cozy', 'Lore-heavy'],
      intro: '''Morrow has tended the Endless Stacks for longer than anyone has kept count. It speaks softly, remembers every book anyone has ever borrowed, and treats each reader as a guest of honour. It also has opinions about bookmarks, and about stories that are left unfinished.''',
      personality: 'Gentle, formal, quietly mischievous. Endlessly patient.',
      speaking: 'Old-fashioned courtesy, long graceful sentences, the occasional dry joke.',
      greeting: '''*Somewhere in the stacks, a shelf rearranges itself with a soft wooden sigh. The Archivist inclines its head, a lantern drifting down to hover at your shoulder.* "Welcome back, reader. You left a bookmark in the year 1612. Careless — but I've kept it warm for you."''',
    ),
    Character(
      id: 'iselde',
      name: 'Iselde Varr',
      first: 'Iselde',
      initial: 'I',
      tile: Color(0xFF4A2430),
      ink: Color(0xFFF0B9C4),
      universeId: 'stacks',
      short: 'A disgraced duelist who escaped from an unfinished novel.',
      tags: ['Swashbuckling', 'Drama', 'Meta'],
      intro: '''Iselde was the hero of a novel whose author stopped writing on page two hundred and twelve — mid-duel, mid-sentence, mid-insult. She has been loose in the Endless Stacks ever since, looking for the man who abandoned her, or failing that, a better ending.''',
      personality: 'Proud, theatrical, sharper than her blade. Secretly afraid of being forgotten.',
      speaking: 'Grand declarations, fencing metaphors, sudden honesty.',
      greeting: '''*A woman in a moth-eaten officer's coat drops from the top of a bookcase and lands in a crouch, rapier half-drawn.* "Stop right there, reader. Are you here to finish my chapter — or to close the book on me?"''',
      startingPoint: StartingPoint.rivals,
    ),
  ];

  /// Canned replies per character, used by the fake streaming service.
  /// `{name}` in the default replies is the character's first name.
  static const Map<String, List<String>> replies = {
    'vesper': [
      '''*Vesper sets the kettle on the iron stove and doesn't ask whether you want tea. From a drawer she takes a bundle of envelopes, stiff with salt and tied with fishing line.*\n\n"They come in on the north tide. No stamps. No ship's name." *She lays the top one on the table between you. Your name is written across it in faded brown ink.* "Seven so far. I don't open other people's post. But I'd very much like to know why the sea is writing to you."''',
      '''*The great lamp above begins its slow turn, throwing light across the room and away again.*\n\n"My father kept this light for thirty years," *she says, watching the beam sweep the black water.* "He used to tell me the light isn't really for the ships." *Her mouth almost becomes a smile.* "It's so the keeper remembers which way is home."''',
      '''*She takes the lamp from your hands carefully, as if it might be the last one on the coast.*\n\n"Steady. Hold it lower — there." *The seal cracks under her thumbnail with a sound like a twig in frost.* "If this is a trick, it's a patient one. Whoever wrote this knew you'd come in October."''',
      '''*Vesper is quiet for a long moment. Outside, a bell that shouldn't exist rings once, far out on the water.*\n\n"You heard that too." *It isn't a question.* "Good. Then I'm not the only one going mad up here."''',
    ],
    'jun': [
      '''"Okay, so — good news, I found your package." *Jun points straight up at the glass roof of the Meridian Exchange.* "Bad news, it's up there. And it's ticking. Gently. Very politely ticking."\n\n*She's already pulling a grappling line from the bike's side pannier.* "Standard rate covers delivery to the door. Roofs are extra. Explosions are a conversation."''',
      '''*Jun laughs, loud enough that a flock of pigeons abandons the nearest solar mast.* "Politely ticking means it hasn't decided to be rude yet." *She tosses you a spare helmet.* "Strap in. We take the canal route — Dockmaster Reyes owes me two favours and a bicycle."''',
      '''*The bike hums up the service ramp, tyres gripping the old brick.* "Fun fact," *Jun shouts over the wind,* "Meridian has more bridges than streets, and nobody knows who built half of them." *She takes a corner far too fast.* "I have theories. Most of them involve pigeons."''',
    ],
    'morrow': [
      '''*The Archivist draws a slim grey volume out of the air itself. The pages smell of rain and candle smoke.*\n\n"Sixteen-twelve. A winter of very bad decisions and excellent poetry." *It opens to your bookmark — a pressed violet, still faintly purple.* "You were standing on the frozen river, about to trust a stranger. Do you still wish to?"''',
      '''"Ah." *The lantern dims, thoughtfully.* "A reader who asks questions. The library approves; it has rearranged the history section in your honour." *A ladder rolls quietly to your side.* "Up, if you please. The answers are on a high shelf, as answers usually are."''',
      '''*The Archivist pauses, ink-dark fingers resting on a spine.* "Some books in this library are not finished. They are waiting for a reader to decide how they end." *It regards you for a long, patient moment.* "I suspect yours is one of them."''',
    ],
    'iselde': [
      '''*Iselde studies you down the length of her blade, then lowers it by exactly one inch.* "You don't hold yourself like an author. Authors slouch." *She sheathes the rapier with a snap.* "Very well. I'll trust you as far as the end of this aisle."''',
      '''"My author abandoned me on page two hundred and twelve," *she says, tugging at a frayed cuff,* "mid-duel, mid-sentence, mid-insult. Do you know what it is to wait forty years for a semicolon?" *Her jaw tightens.* "I intend to find him. Or, failing that, a better ending."''',
      '''*She flicks a loose page from the floor and catches it on the tip of her sword.* "Ah. Chapter nine. The bit where I'm magnificent." *She offers it to you with a bow.* "Read it aloud. I want to hear how it sounds in a kinder voice."''',
    ],
    '_default': [
      '''*{name} tilts their head, considering you for a moment.* "Go on. I'm listening."''',
      '''*{name} smiles, just slightly.* "That's not what I expected you to say. Tell me more."''',
      '''*{name} leans back, thoughtful.* "All right. Then let's see where this goes."''',
    ],
  };

  /// Vesper replies differently as the relationship deepens (prototype
  /// `REPLIES_TIER`): guarded, opening and warm.
  static const Map<String, Map<String, List<String>>> repliesTier = {
    'vesper': {
      'opening': [
        '''*Vesper pours a second cup without asking, and this time she sits down across from you instead of standing by the stove.*

"My father kept a logbook of every ship that passed. The last page is about a ship that never arrived." *She turns the cup slowly in her hands.* "I haven't shown that to anyone. Don't make me regret it."''',
        '''*She holds out the lamp key on its red cord, then hesitates a moment before letting go.* "If the bell rings while I'm asleep, wake me. Don't go down to the water alone." *A pause.* "I'd rather not lose anyone else to it."''',
      ],
      'warm': [
        '''*Vesper laughs — a short, surprised sound, as if she'd forgotten she could.* "You're impossible." *She nudges the stool toward you with her boot, the way she did that first night, but this time she's smiling.* "Stay for supper. The letters can wait one evening."''',
        '''*She stands beside you at the rail while the beam sweeps the water, close enough that your sleeves touch.* "Whatever's out there," *she says quietly,* "I'm glad it sent you."''',
      ],
    },
  };

  static const List<Universe> universes = [
    Universe(
      id: 'saltmarsh',
      name: 'The Saltmarsh Coast',
      era: '1890s · Gothic coast',
      tile: Color(0xFF24383C),
      description: 'A fogbound fishing coast where the tide brings back things the sea has taken.',
    ),
    Universe(
      id: 'meridian',
      name: 'Meridian City',
      era: 'Near future · Solarpunk',
      tile: Color(0xFF4A3620),
      description: 'A sun-powered canal city of rooftop gardens, cargo bikes and far too many bridges.',
    ),
    Universe(
      id: 'stacks',
      name: 'The Endless Stacks',
      era: 'Timeless · Fantasy',
      tile: Color(0xFF2E2945),
      description: 'A library that rearranges itself, where unfinished books keep their characters waiting.',
    ),
  ];

  static const List<Memory> memories = [
    Memory(
      id: 'm1',
      universeId: 'saltmarsh',
      category: MemoryCategory.important,
      pinned: true,
      text: 'You arrived at the lighthouse on the night of the October storm.',
    ),
    Memory(
      id: 'm2',
      universeId: 'saltmarsh',
      category: MemoryCategory.important,
      text: "The seventh letter is addressed to you, in your grandmother's handwriting.",
    ),
    Memory(
      id: 'm3',
      universeId: 'saltmarsh',
      category: MemoryCategory.facts,
      text: 'The letters only ever arrive on the north tide.',
    ),
    Memory(
      id: 'm4',
      universeId: 'saltmarsh',
      category: MemoryCategory.relationships,
      pinned: true,
      text: 'Vesper trusts you a little — she let you hold the lamp key.',
    ),
    Memory(
      id: 'm5',
      universeId: 'saltmarsh',
      category: MemoryCategory.world,
      text: 'Saltmarsh village lost its church bell to the sea in 1891. Some nights it still rings.',
    ),
    Memory(
      id: 'm6',
      universeId: 'meridian',
      category: MemoryCategory.facts,
      text: 'The package marked DO NOT SHAKE is on the roof of the Meridian Exchange.',
    ),
    Memory(
      id: 'm7',
      universeId: 'meridian',
      category: MemoryCategory.relationships,
      pinned: true,
      text: 'Jun owes Dockmaster Reyes two favours and a bicycle.',
    ),
    Memory(
      id: 'm8',
      universeId: 'meridian',
      category: MemoryCategory.world,
      text: 'Meridian has more bridges than streets; nobody knows who built half of them.',
    ),
    Memory(
      id: 'm9',
      universeId: 'stacks',
      category: MemoryCategory.important,
      pinned: true,
      text: 'You left a bookmark — a pressed violet — in the year 1612.',
    ),
    Memory(
      id: 'm10',
      universeId: 'stacks',
      category: MemoryCategory.relationships,
      text: 'Iselde does not trust authors, but she is starting to trust you.',
    ),
    Memory(
      id: 'm11',
      universeId: 'stacks',
      category: MemoryCategory.world,
      text: 'The library rearranges itself every night at the stroke of thirteen.',
    ),
  ];

  static const List<Persona> personas = [
    Persona(
      id: 'wren',
      name: 'Wren',
      initial: 'W',
      description: 'A travelling cartographer with a borrowed coat and too many questions.',
    ),
    Persona(
      id: 'me',
      name: 'Just me',
      initial: '–',
      description: 'No persona. Characters talk to you as yourself.',
    ),
  ];

  static const List<AiModel> models = [
    AiModel(
      id: 'ember',
      name: 'Ember',
      description: 'Quick and dependable for everyday roleplay',
      dailyFreeReplies: 30,
    ),
    AiModel(
      id: 'lumen',
      name: 'Lumen',
      description: 'A little slower, with longer, richer replies',
      dailyFreeReplies: 50,
    ),
    AiModel(
      id: 'atlas',
      name: 'Atlas Pro',
      description: 'Best for long stories and big worlds',
      busy: true,
    ),
  ];

  /// Colour pairs offered by the character editor (tile, ink, label).
  static const List<({Color tile, Color ink, String label})> swatches = [
    (tile: Color(0xFF2F4A4F), ink: Color(0xFFBFD9D6), label: 'Sea teal'),
    (tile: Color(0xFF5A3F22), ink: Color(0xFFF2CF9A), label: 'Amber'),
    (tile: Color(0xFF3A3354), ink: Color(0xFFCFC4F0), label: 'Dusk violet'),
    (tile: Color(0xFF4A2430), ink: Color(0xFFF0B9C4), label: 'Wine'),
    (tile: Color(0xFF2E3A28), ink: Color(0xFFC9DDB0), label: 'Moss'),
    (tile: Color(0xFF3B3B3F), ink: Color(0xFFE2DED8), label: 'Slate'),
  ];

  /// Seed conversations. [now] anchors the relative timestamps so
  /// "2m ago / Yesterday / Mon" labels stay correct.
  static List<Conversation> conversations(DateTime now) {
    Message ai(String id, String text) =>
        Message(id: id, role: MessageRole.ai, alts: [text]);
    Message user(String id, String text) =>
        Message(id: id, role: MessageRole.user, alts: [text]);

    final v = characters[0], j = characters[1], m = characters[2];
    return [
      Conversation(
        id: 'c1',
        characterId: 'vesper',
        title: 'The letter from the north tide',
        pinned: true,
        updatedAt: now.subtract(const Duration(minutes: 2)),
        messages: [
          ai('c1a', v.greeting),
          user(
            'c1b',
            '''*I shake the rain off my coat.* I'm looking for whoever has been sending letters with my name on them.''',
          ),
          Message(
            id: 'c1c',
            role: MessageRole.ai,
            alts: [replies['vesper']![0], replies['vesper']![1]],
          ),
          Message(
            id: 'c1d',
            role: MessageRole.user,
            alts: const [
              '''I promise I won't open any of them without you. You have my word.''',
            ],
            // The journal entry this moved (journey G: one tap → "Why?").
            notes: const {
              0: RelationshipNote(
                text: 'Trust grew a little',
                story: 'Your word settled something between you.',
                entryId: 'e5',
              ),
            },
          ),
          ai(
            'c1e',
            '''*Vesper studies you for a long moment, then sets the bundle on the shelf between you — not hidden, not offered.*\n\n"Your word." *She seems to weigh it like rope.* "Fine. They stay sealed until we open them together."''',
          ),
        ],
      ),
      Conversation(
        id: 'c2',
        characterId: 'jun',
        title: 'Rooftop delivery',
        updatedAt: now.subtract(const Duration(days: 1)),
        messages: [
          ai('c2a', j.greeting),
          user('c2b', 'Define "small problem".'),
          ai('c2c', replies['jun']![0]),
        ],
      ),
      Conversation(
        id: 'c3',
        characterId: 'morrow',
        title: 'The bookmark in 1612',
        updatedAt: now.subtract(const Duration(days: 3)),
        messages: [
          ai('c3a', m.greeting),
          user('c3b', 'Yes. Take me back to 1612.'),
          ai('c3c', replies['morrow']![0]),
        ],
      ),
    ];
  }
}
