# Breathing Exercise Audio Files

The breathing exercise feature requires specific audio files for different techniques:

## Required Files:

### Box Breathing (Phase-specific sounds):
- **`inhale.mp3`** - Plays during "Breathe In" phase
- **`exhale.mp3`** - Plays during "Breathe Out" phase  
- **`hold.mp3`** - Plays during "Hold" phases
- **Location**: `frontend/assets/sounds/`

These files should be short sound cues or voice guidance like:
- "Breathe in" or a gentle chime for inhale
- "Breathe out" or a soft tone for exhale
- "Hold" or a sustained tone for hold

### 4:7:8 Breathing (Full session audio):
- **`478_1st_half.mp3`** - 4-minute guided breathing audio (first half)
- **`478_2nd_half.mp3`** - 4-minute guided breathing audio (second half)
- **Location**: `frontend/assets/sounds/`

## How It Works:

### Box Breathing:
- User selects ratio (4:4:4:4, 5:5:5:5, or 6:6:6:6)
- User selects duration (4, 8, or 12 minutes)
- Phase-specific audio plays at each phase transition
- Exercise runs for the selected duration
- Shows live countdown timer

### 4:7:8 Breathing:
- User selects duration (4 or 8 minutes)
- If 4 min: plays `478_1st_half.mp3` only
- If 8 min: plays `478_1st_half.mp3` then automatically plays `478_2nd_half.mp3`
- Shows live countdown timer

## Audio Specifications:
- **Format**: MP3
- **Sample rate**: 44.1kHz or 48kHz recommended
- **Bit rate**: 128kbps or higher
- **Phase sounds**: 1-3 seconds each
- **Session audio**: 4 minutes each (240 seconds)

## Recommended Sources:
- [FreeSound.org](https://freesound.org) - Search for "meditation bell", "breathing", "chime"
- [YouTube Audio Library](https://www.youtube.com/audiolibrary) - Wellness & meditation sounds
- Text-to-Speech tools - Generate "Breathe in", "Hold", "Breathe out" voice guidance
- Audio editing software - Create custom breathing guidance tracks

## Creating Your Own:
1. **Phase sounds**: Record or generate short 1-2 second audio cues
2. **Session audio**: Create a 4-minute track with timed breathing instructions following 4:7:8 pattern (4s in, 7s hold, 8s out)

## Testing Without Audio:
The app works perfectly without audio files - they fail silently and the breathing exercise continues with visual guidance only. Audio enhances the experience but is not required for functionality.
