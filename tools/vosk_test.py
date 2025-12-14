"""
Simple host-side Vosk smoke test.

This script expects a local Vosk model directory (default: tools/vosk-models/vosk-model-small-en-us-0.15)
and a WAV file to run inference on. It will load the model and run recognition on the sample audio,
printing partial/final results.

Usage:
    python tools/vosk_test.py --model tools/vosk-models/vosk-model-small-en-us-0.15 --wav sample.wav

If you don't have a sample WAV, record a short ~3 second 16kHz PCM WAV and provide its path.
"""
import argparse
import sys
import os

try:
    from vosk import Model, KaldiRecognizer  # type: ignore[import]
    import soundfile as sf  # type: ignore[import]
except ImportError as e:
    print('❌ Missing dependencies. Install with:')
    print('   pip install vosk soundfile')
    sys.exit(1)


def run(model_path: str, wav_path: str):
    if not os.path.isdir(model_path):
        print('Model path not found:', model_path)
        return 2
    if not os.path.isfile(wav_path):
        print('WAV file not found:', wav_path)
        return 3

    print('Loading model from', model_path)
    model = Model(model_path)
    print('Reading audio', wav_path)
    data, samplerate = sf.read(wav_path, dtype='int16')
    if samplerate != 16000:
        print('Warning: model expects 16000Hz audio; your file is', samplerate)

    rec = KaldiRecognizer(model, samplerate)
    # If stereo, take first channel
    if data.ndim > 1:
        data = data[:,0]
    # process in small chunks
    i = 0
    step = 4000
    while i < len(data):
        chunk = data[i:i+step].tobytes()
        if rec.AcceptWaveform(chunk):
            print('RESULT:', rec.Result())
        else:
            print('PARTIAL:', rec.PartialResult())
        i += step
    print('FINAL:', rec.FinalResult())
    return 0


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--model', default='tools/vosk-models/vosk-model-small-en-us-0.15')
    p.add_argument('--wav', required=True)
    args = p.parse_args()
    sys.exit(run(args.model, args.wav))
