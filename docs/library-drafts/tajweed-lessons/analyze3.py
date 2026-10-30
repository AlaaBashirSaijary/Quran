"""Qalqalah, the letter ra and the lam of Allah, found in the mushaf text.

Rules as in ar.wikipedia (قلقلة، تفخيم وترقيق، أحكام الراء، أحكام لفظ
الجلالة). Only unambiguous places are kept: words with a single letter in
question, no idgham, no waqf-dependent doubt in the middle of an ayah."""
import re
from analyze import *

FATHA, DAMMA, KASRA = 'َ', 'ُ', 'ِ'
TANWEEN = 'ًٌٍٖٗٞ'
STOPS = re.compile('[ۖ-ۜ۞-۠]')
ISTILA = 'خصضغطقظ'
QALQALA = 'قطبجد'

def clean(word):
    return STOPS.sub('', word)

def vowel(marks):
    """'f', 'd', 'k', 's' (sukun) or '' / 't' (tanween) for a letter's marks."""
    if any(m in marks for m in TANWEEN): return 't'
    if SUKUN in marks: return 's'
    for m, v in ((FATHA, 'f'), (DAMMA, 'd'), (KASRA, 'k')):
        if m in marks: return v
    return ''

def qalqala_cases():
    for (s, a), words in AYAHS.items():
        for i, w in enumerate(words):
            ls = letters_with_marks(clean(w))
            hits = [k for k, (c, m) in enumerate(ls) if c in QALQALA]
            if len(hits) != 1 or ('ٱ' in w and False):
                continue
            k = hits[0]
            c, m = ls[k]
            final_word = i == len(words) - 1
            last = k == len(ls) - 1
            # a qalqalah letter that is the last of the word and carries a
            # tanween / vowel in the middle of an ayah is read with its vowel
            if final_word and last:
                # waqf: the letter becomes sakin
                if m and re.search('[ًٌٍٖٗٞ]', m) and False:
                    continue
                rule = 'aala' if SHADDA in m else 'awsat'
                if k + 1 < len(ls): continue
                # tanween fatha ends in an alef when stopping; skip those
                yield dict(surah=s, ayah=a, i=i, rule=rule, words=words)
            elif not final_word and SUKUN in m and not SHADDA in m:
                # next letter must not cause idgham
                nxt = letters_with_marks(words[i + 1])
                if not last:
                    follower = ls[k + 1]
                    if SHADDA in follower[1] or follower[0] == c: continue
                else:
                    if SHADDA in nxt[0][1] or nxt[0][0] == c: continue
                    # wasl-alef after sakin: kasra arid, still qalqalah, but skip
                    if nxt[0][0] == 'ٱ': continue
                yield dict(surah=s, ayah=a, i=i, rule='aqal', words=words)

def ra_cases():
    for (s, a), words in AYAHS.items():
        for i, w in enumerate(words):
            ls = letters_with_marks(clean(w))
            hits = [k for k, (c, m) in enumerate(ls) if c == 'ر']
            if len(hits) != 1:
                continue
            k = hits[0]
            m = ls[k][1]
            v = vowel(m)
            last = k == len(ls) - 1
            final_word = i == len(words) - 1
            if 'ۜ' in w or 'ؘ' in w:  # imalah / special signs
                continue
            if final_word and last:
                # waqf: the ra is sakin
                if k >= 2 and ls[k - 1][0] == 'ي' and not ls[k - 1][1].replace(KASRA, '') and v in ('d', 'k', 't', 'f'):
                    if v != 'f' or True:
                        yield dict(surah=s, ayah=a, i=i, rule='tarqiq-waqf', words=words)
                elif k >= 2 and v in ('d', 'k') and vowel(ls[k - 1][1]) == 's' and ls[k - 1][0] not in ISTILA and ls[k - 1][0] not in 'يو' and vowel(ls[k - 2][1]) == 'k':
                    yield dict(surah=s, ayah=a, i=i, rule='tarqiq-waqf', words=words)
                continue
            if last and v in ('s', ''):
                continue
            if v in ('f', 'd') or (v == '' and SHADDA in m and False):
                if not (last and v == 't'):
                    yield dict(surah=s, ayah=a, i=i, rule='tafkhim-harakah', words=words)
            elif v == 'k':
                if not any(x in m for x in TANWEEN):
                    yield dict(surah=s, ayah=a, i=i, rule='tarqiq-maksura', words=words)
            elif v == 's' and k > 0 and not last:
                pc, pm = ls[k - 1]
                pv = vowel(pm)
                if pc == 'ٱ': continue
                nc, nm = ls[k + 1]
                if pv in ('f', 'd'):
                    yield dict(surah=s, ayah=a, i=i, rule='tafkhim-sakina', words=words)
                elif pv == 'k':
                    nv = vowel(nm)
                    if nc in ISTILA:
                        if nv in ('f', 'd'):
                            yield dict(surah=s, ayah=a, i=i, rule='tafkhim-kasra-istila', words=words)
                    else:
                        yield dict(surah=s, ayah=a, i=i, rule='tarqiq-sakina', words=words)

def jalala_cases():
    for (s, a), words in AYAHS.items():
        for i, w in enumerate(words):
            core = clean(w)
            ls = letters_with_marks(core)
            # the word Allah: ا ل ل ه with the lam doubled, in any case
            if MARK.sub('', core.replace('ٰ', 'ا')).startswith(('الله',)) is False:
                pass
            m = re.match('^(?:[وفبكل][َُِ]?)?(ٱ|ل)', core)
            base_w = MARK.sub('', core).replace('ٱ', 'ا')
            if not (base_w in ('الله', 'لله') or re.match('^[وفب]الله$', base_w)):
                continue
            if base_w == 'الله' and core.startswith('ٱ'):
                if i == 0:
                    continue  # at the start of an ayah: begun with tafkhim
                pc, pm = letters_with_marks(clean(words[i - 1]))[-1]
                pv = vowel(pm)
                if pv in ('f', 'd'):
                    rule = 'tafkhim'
                elif pv == 'k':
                    rule = 'tarqiq'
                else:
                    continue
                if words[i - 1][-1] in 'ۖۗۘۙۚۛ':
                    continue
                yield dict(surah=s, ayah=a, i=i, rule=rule, words=words, span=(i - 1, i))
            elif base_w in ('بالله', 'والله', 'فالله') and core[0] in 'وفب':
                pv = vowel(ls[0][1])
                rule = 'tafkhim' if pv in ('f', 'd') else 'tarqiq' if pv == 'k' else None
                if rule:
                    yield dict(surah=s, ayah=a, i=i, rule=rule, words=words, span=(i, i))

if __name__ == '__main__':
    import collections
    for name, g in (('qalqala', qalqala_cases), ('ra', ra_cases), ('jalala', jalala_cases)):
        c = collections.Counter(x['rule'] for x in g())
        print(name, dict(c))
