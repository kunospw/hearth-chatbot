"""Generates the carousel + profile HTML from the brand tokens, then renders PNGs with headless Chrome."""
import subprocess, pathlib

here = pathlib.Path(__file__).parent
CHROME = r'C:\Program Files\Google\Chrome\Application\chrome.exe'
FLAME = ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">'
         '<path d="M256 56 C300 120 392 190 392 300 C392 376 332 440 256 440 C180 440 120 376 120 300 '
         'C120 236 160 196 188 164 C196 196 214 212 226 214 C214 150 232 100 256 56 Z" fill="#9A3349"/>'
         '<path d="M256 250 C282 286 320 310 320 356 C320 394 292 420 256 420 C220 420 192 394 192 356 '
         'C192 320 226 296 256 250 Z" fill="#E9A0AE"/></svg>')

SLIDES = [
    ('Coming soon', 'Write the story <em>only you</em> can.', 'A quiet place to write, plan and shape your worlds. AI helps when you ask.', ''),
    ('Write', 'A calm page for <em>long</em> stories.', 'Chapters, notes and a distraction-free editor that remembers where you stopped.', ''),
    ('Organise', 'Your world, <em>all in one place</em>.', 'Characters, places and lore stay linked to your chapters, so nothing gets lost.',
     '<div style="margin-top:56px"><span class="chip">Characters</span><span class="chip">Places</span><span class="chip">Lore</span><span class="chip">Timeline</span></div>'),
    ('AI, on your terms', 'Stuck? <em>Ask</em> for a nudge.', 'Continue a scene, rewrite a line, or brainstorm the next beat. You choose what stays.',
     '<div class="card"><div class="u"><i>The lamp flickered. She counted the stairs down&hellip;</i></div></div><div class="bubble">Make it more tense</div>'),
    ('Join early', 'Be one of the <em>first</em> writers in.', 'Early access is opening in small groups. Link in bio.', ''),
]

def render(html, png, w, h):
    url = (here / 'templates' / html).resolve().as_uri()
    subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--allow-file-access-from-files',
                    f'--window-size={w},{h}', '--virtual-time-budget=3000',
                    f'--screenshot={here / "out" / png}', url], check=True, capture_output=True)

(here / 'out').mkdir(exist_ok=True)
for i, (eyebrow, h1, lead, extra) in enumerate(SLIDES, 1):
    page = (f'<!doctype html><meta charset="utf-8"><link rel="stylesheet" href="brand.css"><div class="slide">'
            f'<div class="eyebrow">{eyebrow}</div><h1>{h1}</h1><p class="lead">{lead}</p>{extra}'
            f'<div class="brand">{FLAME}Hearth</div><div class="count">{i} / {len(SLIDES)}</div></div>')
    (here / 'templates' / f'carousel_{i}.html').write_text(page, encoding='utf8')
    render(f'carousel_{i}.html', f'carousel_{i}.png', 1080, 1350)

(here / 'templates' / 'profile.html').write_text(
    '<!doctype html><meta charset="utf-8"><style>html,body{margin:0;background:#131214}svg{width:1080px;height:1080px;display:block}</style>' + FLAME,
    encoding='utf8')
render('profile.html', 'profile.png', 1080, 1080)
print('done')
