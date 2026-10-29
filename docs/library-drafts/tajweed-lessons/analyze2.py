"""Meem sakin, lam of al-, and madd examples, derived the same way."""
import re, collections
from analyze import *

HAMZA = 'ءأإؤئ'
KASRA, FATHA, DAMMA = 'ِ', 'َ', 'ُ'

def meem_cases():
    for (s, a), words in AYAHS.items():
        for i in range(len(words) - 1):
            ls = letters_with_marks(words[i])
            if not ls or ls[-1][0] != 'م':
                continue
            m = ls[-1][1]
            if re.search('[ً-ّٖٗٞ]', m):
                continue
            nxt = letters_with_marks(words[i + 1])
            first = norm(nxt[0][0])
            if first == 'ٱ':
                continue
            if len(ls) < 2:   # the particle م by itself
                continue
            rule = 'ikhfa' if first == 'ب' else 'idgham' if first == 'م' else 'izhar'
            ok = (SUKUN in m) if rule == 'izhar' else (SUKUN not in m)
            if rule == 'idgham':
                ok = ok and SHADDA in nxt[0][1]
            yield dict(surah=s, ayah=a, i=i, rule=rule, ok=ok, words=words)

QAMARI = 'ابغحجكوخفعقيمه'
SHAMSI = 'طثصرتضذندسظزشل'
assert len(QAMARI) == 14 and len(SHAMSI) == 14 and len(set(QAMARI + SHAMSI)) == 28

def lam_cases():
    for (s, a), words in AYAHS.items():
        for i, w in enumerate(words):
            ls = letters_with_marks(w)
            for k in range(min(3, len(ls) - 2)):
                if ls[k][0] == 'ٱ' and ls[k + 1][0] == 'ل' and k <= 1 and all(c[0] in 'وفبكل' for c in ls[:k]):
                    nxt = norm(ls[k + 2][0]).replace('ء', 'ا')
                    if nxt == 'ل' and len(ls) == k + 4 and w.endswith(('هِ', 'هُ', 'هَ')):
                        pass
                    if ls[k + 2][0] == 'ل' and 'ٱللَّه' in w:
                        break
                    rule = 'qamari' if nxt in QAMARI else 'shamsi'
                    sign_ok = (SUKUN in ls[k + 1][1]) if rule == 'qamari' else (SUKUN not in ls[k + 1][1] and (SHADDA in ls[k + 1][1] or SHADDA in ls[k + 2][1]))
                    yield dict(surah=s, ayah=a, i=i, rule=rule, ok=sign_ok, words=words)
                    break

def madd_cases():
    n = len(AYAHS)
    for (s, a), words in AYAHS.items():
        for i, w in enumerate(words):
            ls = letters_with_marks(w)
            for k, (ch, mk) in enumerate(ls):
                if MADDA in mk and k + 1 < len(ls):
                    nx = ls[k + 1]
                    if nx[0] in HAMZA:
                        yield dict(surah=s, ayah=a, i=i, rule='muttasil', words=words)
                    elif SHADDA in nx[1]:
                        yield dict(surah=s, ayah=a, i=i, rule='lazim', words=words)
                elif MADDA in mk and k == len(ls) - 1 and i + 1 < len(words):
                    if norm(letters_with_marks(words[i + 1])[0][0]) == 'ء':
                        yield dict(surah=s, ayah=a, i=i, rule='munfasil', words=words)
            # badal: hamza + madd letter of the same vowel, nothing heavy after
            for k in range(len(ls) - 2):
                (c1, m1), (c2, m2), (c3, m3) = ls[k], ls[k + 1], ls[k + 2]
                if c1 in HAMZA and not m2.replace('ٰ', ''):
                    if ((FATHA in m1 and c2 == 'ا') or (DAMMA in m1 and c2 == 'و') or (KASRA in m1 and c2 == 'ي')) \
                            and c3 not in HAMZA and SUKUN not in m3 and SHADDA not in m3 and c3 != 'ٱ':
                        yield dict(surah=s, ayah=a, i=i, rule='badal', words=words)
                        break
        # arid: ayah's last word, madd letter then the final consonant
        w = words[-1]
        ls = letters_with_marks(re.sub('[ۖ-ۜ۝۞]', '', w))
        if len(ls) >= 3 and ls[-1][0] not in HAMZA:
            c, m = ls[-2]
            prev = ls[-3][1]
            if (c == 'ي' and KASRA in prev and not m) or (c == 'و' and DAMMA in prev and not m):
                if not re.search('[ً-ّٖٗٞ]', ls[-1][1]) or True:
                    yield dict(surah=s, ayah=a, i=len(words) - 1, rule='arid', words=words)

if __name__ == '__main__':
    for name, gen in (('meem', meem_cases), ('lam', lam_cases), ('madd', madd_cases)):
        st = collections.Counter(); bad = []
        for c in gen():
            st[(c['rule'], c.get('ok', True))] += 1
            if c.get('ok', True) is False and len(bad) < 14:
                bad.append((c['surah'], c['ayah'], c['words'][c['i']]))
        print(name, dict(st)); print(bad)
