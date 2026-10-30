"""Waqf signs of the mushaf: each sign is read from the text itself."""
from analyze import *

SIGNS = {'ۘ': 'lazim', 'ۙ': 'mamnu', 'ۚ': 'jaiz',
         'ۖ': 'wasl-awla', 'ۗ': 'waqf-awla', 'ۛ': 'muanaqa'}

def waqf_cases():
    for (s, a), words in AYAHS.items():
        for i, w in enumerate(words):
            found = {SIGNS[c] for c in w if c in SIGNS}
            if len(found) == 1 and i < len(words) - 1:
                yield dict(surah=s, ayah=a, i=i, rule=found.pop(), words=words)

if __name__ == '__main__':
    import collections
    print(collections.Counter(c['rule'] for c in waqf_cases()))
