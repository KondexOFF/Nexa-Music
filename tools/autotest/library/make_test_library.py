#!/usr/bin/env python3
"""NEXA AutoTest - generates the synthetic test music library.

Pure sine tones (no music, no copyright): every track has its own
frequency, an exact duration and known tags, so the AutoTest can check
import, metadata and - from a WASAPI loopback recording - which track is
audible, how long tracks overlap (crossfade) and gaps (gapless).

Needs Python 3 + ffmpeg (with libmp3lame) + Pillow.
Usage: make_test_library.py <output folder>
The folder is written OUTSIDE the repository (audio files are never
committed); tools/autotest/library/manifest.json describes it, with the
SHA-256 of every file so the AutoTest can verify it before use.

Note: when audio files are copied to the owner's PC through the Claude file
transfer, a content-credentials (C2PA) block is added to them (WAV: an extra
chunk; MP3: an ID3 frame; FLAC: an ID3v2 tag in front). Standard FLAC files
are therefore delivered inside a base64 text package that NEXA_AutoTest.ps1
unpacks; the manifest holds the hashes of the files as they are on the PC.
"""
import hashlib
import json
import os
import subprocess
import sys

AMPLITUDE = 0.5  # -6 dBFS: a crossfade of two tones never clips.
RATE = 44100

TRACKS = []


def add(group, name, fmt, seconds, freq, title=None, artist=None,
        album=None, genre=None, track=None, tag_issue=None, id3_prefix=False):
    TRACKS.append(dict(
        group=group, file=f'{group}/{name}.{fmt}', format=fmt,
        seconds=seconds, frequency=freq, title=title, artist=artist,
        album=album, genre=genre, track=track, tag_issue=tag_issue,
        id3_prefix=id3_prefix))


# 24 tracks of one album, 6 s each, for 20-30 tracks in a row (FT-06).
for n in range(1, 25):
    fmt = ['flac', 'wav', 'mp3'][n % 3]
    add('seq', f'seq_{n:02d}', fmt, 6.0, 300 + 110 * n,
        title=f'Seq {n:02d}', artist='AutoTest Band',
        album='AutoTest Sequence', genre='Electronic', track=n)

# Four 40 s tracks of different albums for crossfade / Smart Mix (FT-11..15).
for key, fmt, freq, genre in [('a', 'wav', 440, 'Ambient'),
                              ('b', 'flac', 660, 'Jazz'),
                              ('c', 'mp3', 880, 'Rock'),
                              ('d', 'wav', 1100, 'Ambient')]:
    add('mix', f'mix_{key}', fmt, 40.0, freq, title=f'Mix {key.upper()}',
        artist=f'Mix Artist {key.upper()}', album=f'Mix Album {key.upper()}',
        genre=genre, track=1)

# A continuous album: consecutive tracks must play gapless (FT-13).
for n, freq in [(1, 1300), (2, 1500), (3, 1700)]:
    add('album', f'live_{n}', 'flac', 12.0, freq, title=f'Live {n}',
        artist='Live Band', album='AutoTest Live Album', genre='Rock',
        track=n)

# Cyrillic tags, cover image, untagged file (FT-02, FT-05, TD-04).
add('meta', 'Тестовая песня', 'mp3', 8.0, 2000, title='Тестовая песня',
    artist='Тестовый исполнитель', album='Тестовый альбом', genre='Поп',
    track=1)
add('meta', 'Кириллица FLAC', 'flac', 8.0, 2200, title='Песня на кириллице',
    artist='Исполнитель Ё', album='Тестовый альбом', genre='Поп', track=2)
add('meta', 'Кириллица WAV', 'wav', 8.0, 2400, title='Песня WAV',
    artist='Исполнитель WAV', album='Альбом WAV', genre='Поп', track=1,
    tag_issue='TD-04')
add('meta', 'untagged_track', 'wav', 5.0, 2600)

# Edge case: a FLAC file with an ID3v2 tag in front of the FLAC data (some
# taggers and content-credential tools write this). The real tags are the
# FLAC Vorbis comments (TD-19).
add('edge', 'id3_prefixed', 'flac', 6.0, 2800, title='Edge ID3 FLAC',
    artist='Edge Artist', album='Edge Album', genre='Electronic', track=1,
    id3_prefix=True)


def id3v2_tag(title):
    """A small ID3v2.4 tag (one TIT2 frame + padding)."""
    text = b'\x03' + title.encode('utf-8')
    frame = b'TIT2' + len(text).to_bytes(4, 'big') + b'\x00\x00' + text
    body = frame + b'\x00' * 64
    n = len(body)
    size = bytes([(n >> 21) & 0x7F, (n >> 14) & 0x7F, (n >> 7) & 0x7F, n & 0x7F])
    return b'ID3\x04\x00\x00' + size + body


def run(cmd):
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL,
                   stderr=subprocess.PIPE)


def make(out, t):
    path = os.path.join(out, t['file'])
    os.makedirs(os.path.dirname(path), exist_ok=True)
    src = (f"aevalsrc={AMPLITUDE}*sin(2*PI*{t['frequency']}*t)"
           f":s={RATE}:d={t['seconds']}")
    cmd = ['ffmpeg', '-y', '-hide_banner', '-f', 'lavfi', '-i', src,
           '-ac', '1', '-map_metadata', '-1']
    for key in ('title', 'artist', 'album', 'genre'):
        if t[key]:
            cmd += ['-metadata', f'{key}={t[key]}']
    if t['track']:
        cmd += ['-metadata', f"track={t['track']}"]
    cmd += {'mp3': ['-c:a', 'libmp3lame', '-b:a', '128k',
                    '-id3v2_version', '3'],
            'flac': ['-c:a', 'flac'],
            'wav': ['-c:a', 'pcm_s16le']}[t['format']]
    run(cmd + [path])
    if t.get('id3_prefix'):
        with open(path, 'rb') as f:
            data = f.read()
        with open(path, 'wb') as f:
            f.write(id3v2_tag('ID3 title (ignored)') + data)
    with open(path, 'rb') as f:
        t['sha256'] = hashlib.sha256(f.read()).hexdigest()
    t['bytes'] = os.path.getsize(path)


def make_cover(out):
    from PIL import Image, ImageDraw
    img = Image.new('RGB', (300, 300), (0x2E, 0x29, 0x50))
    d = ImageDraw.Draw(img)
    for i in range(0, 300, 20):
        d.line([(0, i), (300, 300 - i)], fill=(0xAD, 0x9A, 0xFF), width=4)
    path = os.path.join(out, 'meta', 'cover.jpg')
    img.save(path, quality=90)
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def main():
    out = sys.argv[1]
    for t in TRACKS:
        make(out, t)
    cover = make_cover(out)
    manifest = {
        'name': 'NEXA AutoTest library',
        'version': 1,
        'amplitude': AMPLITUDE,
        'sampleRate': RATE,
        'tracks': [{k: v for k, v in t.items() if k != 'group'} |
                   {'group': t['group']} for t in TRACKS],
        'extraFiles': [{'file': 'meta/cover.jpg', 'sha256': cover}],
    }
    with open(os.path.join(out, 'manifest.json'), 'w', encoding='utf-8') as f:
        json.dump(manifest, f, ensure_ascii=False, indent=1)


if __name__ == '__main__':
    main()
