"""Finds tajweed examples in the bundled Quran text (assets/quran_text.txt).

The rule of each example is derived from the letters alone (the letter
groups below are the ones in Tuhfat al-Atfal and ar.wikipedia's articles on
the rules) and then checked against the signs the mushaf itself prints
(sukun, shadda, small meem), so the Quran text is never typed by hand."""
import re, sys, json, collections

TEXT = '/home/user/Quran/assets/quran_text.txt'
AYAHS = {}
for line in open(TEXT, encoding='utf8').read().split('\n'):
    if line:
        s, a, p, t = line.split('|', 3)
        AYAHS[(int(s), int(a))] = t.split()

SUKUN, SHADDA, MEEM_IQLAB, MADDA = 'ۡ', 'ّ', 'ۢ', 'ٓ'
OPEN_TANWEEN = 'ٖٗٞ'          # ٗ ٖ ٞ  (idgham / ikhfa / iqlab)
CLOSED_TANWEEN = 'ًٌٍ'        # ً ٌ ٍ  (izhar)
MARK = re.compile('[ؐ-ًؚ-ٰٟۖ-ۭـ]')

def base(word):
    return MARK.sub('', word)

def norm(ch):
    if ch in 'أإآءؤئٱ':
        return 'ء' if ch != 'ٱ' else 'ٱ'
    return {'ى': 'ي', 'ة': 'ه'}.get(ch, ch)

def letters_with_marks(word):
    out = []
    for ch in word:
        if MARK.match(ch) and out:
            out[-1][1] += ch
        elif not MARK.match(ch):
            out.append([ch, ''])
    return out

NOON_GROUPS = {
    'izhar': 'ءهعحغخ',
    'idgham-ghunna': 'ينمو',
    'idgham-bila': 'لر',
    'iqlab': 'ب',
    'ikhfa': 'صذثكجشقسدطزفتضظ',
}
GROUP_OF = {c: g for g, cs in NOON_GROUPS.items() for c in cs}

def noon_cases():
    """Words ending in a quiescent noon or a tanween, and the next word."""
    for (s, a), words in AYAHS.items():
        for i in range(len(words) - 1):
            ls = letters_with_marks(words[i])
            if not ls:
                continue
            last = ls[-1]
            kind = None
            if last[0] == 'ن' and not re.search('[\u064B-\u0651\u0656\u0657\u065E]', last[1]):
                kind = 'noon'
                sign = 'sukun' if SUKUN in last[1] else 'iqlab' if MEEM_IQLAB in last[1] else 'bare'
            else:
                # tanween: on the last letter, or on the one before an alef /
                # alef maqsura that carries it in writing
                cand = [ls[-1]] + ([ls[-2]] if len(ls) > 1 and ls[-1][0] in 'اى' and not ls[-1][1] else [])
                for c in cand:
                    if any(m in c[1] for m in CLOSED_TANWEEN + OPEN_TANWEEN):
                        kind = 'tanween'
                        sign = 'closed' if any(m in c[1] for m in CLOSED_TANWEEN) else 'open'
                        if MEEM_IQLAB in c[1] or MEEM_IQLAB in last[1]:
                            sign += '+iqlab'
                        break
            if not kind:
                continue
            nxt = letters_with_marks(words[i + 1])
            first = norm(nxt[0][0])
            if first == 'ٱ' or first not in GROUP_OF:
                continue
            yield dict(surah=s, ayah=a, i=i, kind=kind, sign=sign,
                       rule=GROUP_OF[first], next=first,
                       shadda_next=SHADDA in nxt[0][1], words=words)

def check_noon(c):
    """The mushaf's own signs must agree with the rule from the letters."""
    r, sign = c['rule'], c['sign']
    if c['kind'] == 'noon':
        if r == 'izhar': return sign == 'sukun'
        if r == 'iqlab': return sign == 'iqlab'
        if r.startswith('idgham'): return sign == 'bare' and (c['shadda_next'] or c['next'] in 'يو')
        if r == 'ikhfa': return sign == 'bare' and not c['shadda_next']
    else:
        if r == 'izhar': return sign == 'closed'
        if r == 'iqlab': return sign.startswith('open') and 'iqlab' in sign
        if r.startswith('idgham'): return sign == 'open' and (c['shadda_next'] or c['next'] in 'يو')
        if r == 'ikhfa': return sign == 'open' and not c['shadda_next']
    return False

if __name__ == '__main__':
    stats = collections.Counter(); bad = collections.Counter(); samples = []
    for c in noon_cases():
        ok = check_noon(c)
        stats[(c['kind'], c['rule'], ok)] += 1
        if not ok and len(samples) < 12:
            samples.append((c['surah'], c['ayah'], ' '.join(c['words'][c['i']:c['i'] + 2]), c['kind'], c['sign'], c['rule'], c['shadda_next']))
    for k, v in sorted(stats.items()): print(k, v)
    for s in samples: print(s)
