"""Run:  python3 tools/make_assets.py   (needs pillow, numpy, scipy)
Regenerates every PNG/WAV in assets/generated/ ."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
import art_world
art_world.run()
try:
    import art_chars
    art_chars.run()
except ImportError:
    pass
try:
    import art_ui
    art_ui.run()
except ImportError:
    pass
try:
    import art_audio
    art_audio.run()
except ImportError:
    pass
print("assets done")
