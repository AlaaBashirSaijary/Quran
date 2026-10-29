"""Builds assets/library/tajweed-lessons.json.

The explanations are written for the app from the rules as stated in
Tuhfat al-Atfal (already in the library, public domain) and the Arabic
Wikipedia articles listed in SOURCES; the Quran examples are located in the
bundled mushaf text by analyze.py / analyze2.py, never typed."""
import json, re, random
from analyze import *
import analyze2 as an2

TUHFAT = json.load(open('/home/user/Quran/assets/library/tuhfat-al-atfal.json', encoding='utf8'))

def tuhfat_lines(section_start, count):
    for s in TUHFAT['sections']:
        if s['title'].startswith(section_start):
            return s['texts'][:count]
    raise KeyError(section_start)

def pick(cases, rule, n, skip=lambda c: False, span=lambda c: (c['i'], c['i'] + 1), seed=1):
    rows = [c for c in cases if c['rule'] == rule and c.get('ok', True) and not skip(c)]
    rows.sort(key=lambda c: (len(c['words']), c['surah'], c['ayah']))
    seen, out = set(), []
    for c in rows:
        if c['surah'] in seen:
            continue
        seen.add(c['surah'])
        lo, hi = span(c)
        out.append(dict(rule=rule, surah=c['surah'], ayah=c['ayah'], **{'from': lo + 1, 'to': hi + 1}, focus=c['i'] + 1))
        if len(out) == n:
            break
    return out

def noon_pick(rule, n, kinds=('noon', 'tanween')):
    cases = [c for c in noon_cases() if check_noon(c) and c['kind'] in kinds
             and not (c['surah'], c['ayah']) == (75, 27)]
    out = []
    # half with the noon, half with tanween, so both are seen
    for kind in kinds:
        out += pick([c for c in cases if c['kind'] == kind], rule, (n + 1) // 2 if kind == kinds[0] else n // 2)
    return out

def word_example(base_form, rule):
    for (s, a), ws in sorted(AYAHS.items()):
        for i, w in enumerate(ws):
            if MARK.sub('', w.replace('\u0670', 'ا')).replace('ٱ', 'ا') == base_form:
                return dict(rule=rule, surah=s, ayah=a, **{'from': i + 1, 'to': i + 1}, focus=i + 1)
    raise KeyError(base_form)

meem = list(an2.meem_cases()); lam = list(an2.lam_cases())

def clean_madd():
    """Only words that show a single kind of madd, and not the cases a
    beginner's lesson would have to qualify: the ya of calling and ha of
    warning (their alef is not written out), and ha of the pronoun."""
    rows = list(an2.madd_cases())
    kinds = {}
    for c in rows:
        kinds.setdefault((c['surah'], c['ayah'], c['i']), set()).add(c['rule'])
    out = []
    for c in rows:
        w = c['words'][c['i']]
        if len(kinds[(c['surah'], c['ayah'], c['i'])]) != 1:
            continue
        b = MARK.sub('', w)
        if re.match('^[وف]?[يه]\u064e?\u0640?\u0670', w.replace('ـ', '')) or b.startswith(('يا', 'ها', 'وها')):
            continue
        if re.search('[\u06E5\u06E6]\u0653?$', re.sub('[\u06D6-\u06ED]', '', w)) or w.endswith(('\u06E5\u0653', '\u06E6\u0653')):
            continue
        final = c['i'] == len(c['words']) - 1
        if (c['rule'] == 'arid') != final:
            continue
        out.append(c)
    return out

madd = clean_madd()

lessons = []

lessons.append(dict(
    id='noon', question='ما حكم النون الساكنة أو التنوين في الكلمة المظللة مع ما بعدها؟', title='أحكام النون الساكنة والتنوين',
    intro='النون الساكنة نونٌ لا حركة عليها، وتثبت كتابةً ولفظاً في الوصل والوقف. والتنوين نونٌ ساكنة زائدة تلحق آخر الاسم في النطق لا في الكتابة، وتسقط عند الوقف. ولهما أربعة أحكام، يحدّدها الحرف الذي يأتي بعدهما.',
    tuhfat=tuhfat_lines('أَحْكَامُ النُّونِ السَّاكِنَةِ', 20),
    rules=[
        dict(id='izhar', name='الإظهار', definition='أن تُخرج النون أو التنوين من مخرجهما واضحين، من غير غنة ظاهرة.',
             letters='ء ه ع ح غ خ', mnemonic='أخي هاك علماً حازه غير خاسر', tip='هي ستة أحرف من أحرف الحلق. في المصحف: تُعرف النون المظهَرة بالسكون فوقها.'),
        dict(id='idgham-ghunna', name='الإدغام بغنة', definition='أن تُدخل النون أو التنوين في الحرف الذي بعده فيصيرا حرفاً واحداً مشدداً، مع بقاء الغنة.',
             letters='ي ن م و', mnemonic='ينمو', tip='لا يكون إلا بين كلمتين. تذهب النون ويبقى صوت الغنة، ولهذا يسمّونه إدغاماً ناقصاً.'),
        dict(id='idgham-bila', name='الإدغام بغير غنة', definition='أن تُدخل النون أو التنوين في الحرف الذي بعده تماماً، فلا يبقى منهما حرف ولا غنة.',
             letters='ل ر', mnemonic='', tip='يسمّونه إدغاماً كاملاً، لذهاب الحرف والصفة معاً.'),
        dict(id='iqlab', name='الإقلاب', definition='أن تُقلب النون أو التنوين ميماً ساكنة مخفاة عند الباء، مع الغنة.',
             letters='ب', mnemonic='', tip='في المصحف: ميم صغيرة فوق النون أو التنوين.'),
        dict(id='ikhfa', name='الإخفاء', definition='أن تنطق بالنون أو التنوين بصفة بين الإظهار والإدغام، من غير تشديد، مع بقاء الغنة.',
             letters='ص ذ ث ك ج ش ق س د ط ز ف ت ض ظ', mnemonic='صف ذا ثنا كم جاد شخص قد سما / دم طيباً زد في تقى ضع ظالما', tip='هي خمسة عشر حرفاً، وهي بقية الحروف بعد أحرف الإظهار والإدغام والإقلاب.'),
    ],
    examples=(noon_pick('izhar', 6) + noon_pick('idgham-ghunna', 6) + noon_pick('idgham-bila', 4)
              + noon_pick('iqlab', 8) + noon_pick('ikhfa', 6)),
    notes=[dict(title='إذا اجتمعت النون وحرف الإدغام في كلمة واحدة',
                text='إذا جاء حرف من أحرف الإدغام بعد النون الساكنة في الكلمة نفسها وجب الإظهار، ويسمى إظهاراً مطلقاً. ورد ذلك في أربع كلمات من القرآن: الدنيا، بنيان، قنوان، صنوان.',
                examples=[word_example('الدنيا', 'mutlaq'), word_example('بنيان', 'mutlaq'), word_example('قنوان', 'mutlaq'), word_example('صنوان', 'mutlaq')])],
))

lessons.append(dict(
    id='meem', question='ما حكم الميم الساكنة في الكلمة المظللة؟', title='أحكام الميم الساكنة',
    intro='الميم الساكنة ميمٌ ثابتة السكون في الوصل والوقف. لها ثلاثة أحكام، وكلها تُسمّى شفوية لأن الميم تخرج من الشفتين.',
    tuhfat=tuhfat_lines('أَحْكَامُ َالمِيمِ السَّاكِنَةِ', 10),
    rules=[
        dict(id='ikhfa', name='الإخفاء الشفوي', definition='إخفاء الميم الساكنة عند الباء مع بقاء الغنة.', letters='ب', mnemonic='', tip='في المصحف: تكون الميم بلا علامة.'),
        dict(id='idgham', name='الإدغام الشفوي', definition='إدغام الميم الساكنة في ميم بعدها بغنة، فيصيران ميماً مشددة. ويسمى إدغاماً صغيراً.', letters='م', mnemonic='', tip='في المصحف: الميم الأولى بلا علامة وعلى الثانية شدة.'),
        dict(id='izhar', name='الإظهار الشفوي', definition='إظهار الميم الساكنة واضحة عند بقية الحروف، من غير غنة ظاهرة.', letters='بقية الحروف غير الميم والباء', mnemonic='', tip='احذر من إخفاء الميم إذا جاء بعدها واو أو فاء، فتُظهِرها إظهاراً واضحاً. في المصحف: السكون فوق الميم.'),
    ],
    examples=(pick(meem, 'ikhfa', 5) + pick(meem, 'idgham', 5) + pick(meem, 'izhar', 6)),
    notes=[],
))

lessons.append(dict(
    id='lam', question='ما حكم لام «أل» في الكلمة المظللة؟', title='لام «أل» التعريف',
    intro='للام «أل» حالتان بحسب الحرف الذي بعدها. وعدد حروف كل حالة أربعة عشر حرفاً، فهي معاً ثمانية وعشرون حرفاً هي حروف الهجاء كلها.',
    tuhfat=tuhfat_lines('حُكْمُ لامِ ألْ', 8),
    rules=[
        dict(id='qamari', name='اللام القمرية (الإظهار)', definition='تُنطق اللام واضحة قبل هذه الحروف، مثل «القمر».', letters=an2.QAMARI.replace('', ' ').strip(), mnemonic='ابغ حجك وخف عقيمه', tip='في المصحف: السكون فوق اللام.'),
        dict(id='shamsi', name='اللام الشمسية (الإدغام)', definition='تُدغم اللام في الحرف الذي بعدها فلا تُنطق، ويُنطق الحرف مشدداً، مثل «الشمس».', letters=an2.SHAMSI.replace('', ' ').strip(), mnemonic='طب ثم صل رحماً تفز ضف ذا نعم دع سوء ظن زر شريفاً للكرم', tip='في المصحف: لا علامة على اللام وتأتي الشدة على الحرف الذي بعدها.'),
    ],
    examples=(pick(lam, 'qamari', 6, span=lambda c: (c['i'], c['i'])) + pick(lam, 'shamsi', 6, span=lambda c: (c['i'], c['i']))),
    notes=[],
))

lessons.append(dict(
    id='madd', question='ما نوع المد في الكلمة المظللة؟ (إن كانت آخر الآية فاعتبر الوقف عليها)', title='أحكام المد',
    intro='المد إطالة الصوت بحرف من حروف المد الثلاثة: الألف الساكنة بعد فتح، والواو الساكنة بعد ضم، والياء الساكنة بعد كسر. والحركة بمقدار قبض الإصبع أو بسطه. والمد نوعان: أصلي (طبيعي) وفرعي، والفرعي سببه همزة أو سكون. الأعداد التالية على رواية حفص عن عاصم.',
    tuhfat=tuhfat_lines('أقْسَامُ المَدِّ', 7),
    rules=[
        dict(id='asli', name='المد الأصلي (الطبيعي)', definition='مد لا يتوقف على همزة ولا سكون بعد حرف المد. يمد حركتين.', letters='', mnemonic='', tip='مثاله «قال، يقول، قيل».'),
        dict(id='badal', name='مد البدل', definition='أن تأتي الهمزة قبل حرف المد في الكلمة نفسها، ولا يأتي بعد حرف المد همز ولا سكون. يمد حركتين.', letters='', mnemonic='', tip='مثاله «آمن، أوتي، إيماناً».'),
        dict(id='muttasil', name='المد المتصل', definition='أن يأتي الهمز بعد حرف المد في كلمة واحدة. يجب مده أكثر من الطبيعي: أربع أو خمس حركات عند حفص.', letters='', mnemonic='', tip='في المصحف: علامة المد (~) فوق حرف المد.'),
        dict(id='munfasil', name='المد المنفصل', definition='أن يأتي حرف المد في آخر كلمة والهمز في أول الكلمة التي بعدها. يمد أربع أو خمس حركات عند حفص، وأجاز بعض أهل الأداء قصره حركتين.', letters='', mnemonic='', tip='سُمّي منفصلاً لانفصال المد عن الهمز في كلمتين. ينبغي تسوية المدود المتشابهة في القراءة.'),
        dict(id='arid', name='المد العارض للسكون', definition='أن يأتي بعد حرف المد حرف متحرك في آخر الكلمة فيسكن للوقف. فيه ثلاثة أوجه عند الوقف: حركتان أو أربع أو ست.', letters='', mnemonic='', tip='لا يكون إلا عند الوقف، فإن وصلتَ عاد المد طبيعياً.'),
        dict(id='lazim', name='المد اللازم', definition='أن يأتي بعد حرف المد سكون أصلي ثابت وصلاً ووقفاً. يمد ست حركات باتفاق القراء.', letters='', mnemonic='', tip='منه المد في أوائل بعض السور كـ «الم».'),
    ],
    examples=(
        [word_example(b, 'asli') for b in ('قال', 'يقول', 'قيل')]
        + pick(madd, 'badal', 4, span=lambda c: (c['i'], c['i']))
        + pick(madd, 'muttasil', 5, span=lambda c: (c['i'], c['i']))
        + pick(madd, 'munfasil', 5)
        + pick(madd, 'arid', 5, span=lambda c: (c['i'], c['i']))
        + pick(madd, 'lazim', 4, span=lambda c: (c['i'], c['i']))),
    notes=[],
))

pack = dict(
    title='دروس التجويد',
    reviewer='ألاء بشير سيجري (مطوّرة التطبيق). لم يراجعها مقرئ مجاز بعد',
    reviewedOn='2026-10-29',
    license='صياغة الشروح مبنية على مقالات ويكيبيديا العربية المرخّصة CC BY-SA 4.0، وتُنشر بالرخصة نفسها. الآيات من مصحف التطبيق والأمثلة مستخرجة منه آلياً.',
    sources=[
        dict(name='تحفة الأطفال والغلمان (سليمان الجمزوري) — الأبيات في مكتبة التطبيق'),
        dict(name='ويكيبيديا العربية: أحكام النون الساكنة والتنوين', url='https://ar.wikipedia.org/wiki/أحكام_النون_الساكنة_والتنوين'),
        dict(name='ويكيبيديا العربية: أحكام الميم الساكنة', url='https://ar.wikipedia.org/wiki/أحكام_الميم_الساكنة'),
        dict(name='ويكيبيديا العربية: أحكام المد', url='https://ar.wikipedia.org/wiki/أحكام_المد'),
    ],
    lessons=lessons,
)
json.dump(pack, open('/home/user/Quran/assets/library/tajweed-lessons.json', 'w', encoding='utf8'), ensure_ascii=False, indent=1)
for l in lessons:
    from collections import Counter
    print(l['id'], dict(Counter(e['rule'] for e in l['examples'])))
