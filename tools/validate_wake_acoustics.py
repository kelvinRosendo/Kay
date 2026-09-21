import sys, wave, json
from pathlib import Path
sys.path.insert(0, 'build/wake-validation-tools')
from vosk import Model, KaldiRecognizer, SetLogLevel
SetLogLevel(-1)
model = Model('android/app/src/main/assets/vosk-model-small-en-us-0.15')
for path in sorted(Path('test/acoustic').glob('*.wav')):
    recognizer = KaldiRecognizer(model, 16000, json.dumps(['kay','kai','k','hey kay','hey kai','okay','ok','[unk]']))
    with wave.open(str(path)) as wav: data = wav.readframes(wav.getnframes()) + bytes(32000)
    previous = ''; stable = 0; detected = False; final_texts = []
    for offset in range(0, len(data), 3200):
        final = recognizer.AcceptWaveform(data[offset:offset+3200])
        text = json.loads(recognizer.Result() if final else recognizer.PartialResult()).get('text' if final else 'partial', '').strip().lower()
        if final: final_texts.append(text)
        stable = stable + 1 if previous == text else 1
        previous = text
        if text in {'kay','kai','k','hey kay','hey kai'} and (final or stable >= 3): detected = True
    expected = not path.stem.startswith('negative')
    print(path.stem, 'detected=', detected, 'expected=', expected, final_texts)
    assert detected == expected, path

