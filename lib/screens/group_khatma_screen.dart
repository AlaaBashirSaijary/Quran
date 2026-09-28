import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/index.dart';
import '../khatma/group_khatma.dart';
import '../quran/quran.dart';
import 'index_screen.dart';

/// Group khatmas this phone has created or joined.
class GroupKhatmaListScreen extends StatelessWidget {
  const GroupKhatmaListScreen({super.key});

  static void open(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const GroupKhatmaListScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = Provider.of<GroupKhatmaProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('الختمة الجماعية', 'Group Khatma')),
        actions: [
          IconButton(
            tooltip: tr('لصق رسالة ختمة', 'Paste a khatma message'),
            icon: const Icon(Icons.content_paste_rounded),
            onPressed: () => pasteKhatmaMessage(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const _CreateKhatmaScreen()),
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(tr('ختمة جديدة', 'New khatma')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            tr(
              'وزّعوا أجزاء القرآن الثلاثين بينكم وأتمّوا ختمة معاً. أنشئ ختمة '
                  'وشارك رسالتها في مجموعة واتساب، ومن يلصقها في التطبيق يرى '
                  'جزأه. ومن أتمّ جزأه يرسل رسالة الإنجاز ليلصقها المنظّم.',
              'Split the thirty juz among you and finish a khatma together. '
                  'Create one and share its message in a WhatsApp group; '
                  'whoever pastes it into the app sees their juz. When '
                  'someone finishes, they send back a message for the '
                  'organizer to paste.',
            ),
            style: TextStyle(color: colorScheme.pageNumber),
          ),
          const SizedBox(height: 16),
          for (final k in groups.khatmas)
            Card(
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: Icon(
                  k.finished ? Icons.verified_rounded : Icons.groups_rounded,
                  color: colorScheme.gold,
                  size: 32,
                ),
                title: Text(
                  k.title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(
                        value: k.done.length / juzCount,
                        color: colorScheme.gold,
                        backgroundColor: colorScheme.div,
                      ),
                      const SizedBox(height: 4),
                      Text(_progress(k)),
                    ],
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_left_rounded,
                  color: colorScheme.gold,
                ),
                onTap: () => GroupKhatmaScreen.open(context, k.id),
              ),
            ),
        ],
      ),
    );
  }
}

String _progress(GroupKhatma k) => tr(
  'أُنجز ${k.done.length} من $juzCount جزءاً · ${k.names.length} مشاركين',
  '${k.done.length} of $juzCount juz done · ${k.names.length} participants',
);

/// Asks for a copied khatma message and imports it.
Future<void> pasteKhatmaMessage(BuildContext context) async {
  final clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (!context.mounted) return;
  final controller = TextEditingController(text: clip?.text ?? '');
  final text = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(tr('لصق رسالة ختمة', 'Paste a khatma message')),
      content: TextField(
        controller: controller,
        minLines: 3,
        maxLines: 8,
        decoration: InputDecoration(
          hintText: tr(
            'الصق رسالة الختمة أو رسالة الإنجاز هنا',
            'Paste the khatma or progress message here',
          ),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppConstant.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: Text(tr('إضافة', 'Add')),
        ),
      ],
    ),
  );
  disposeAfterDialog([controller]);
  if (text == null || !context.mounted) return;

  final groups = Provider.of<GroupKhatmaProvider>(context, listen: false);
  final message = parseKhatmaMessage(text);
  final result = groups.import(text);
  final feedback = switch (result) {
    ImportResult.joined => tr('انضممت إلى الختمة', 'You joined the khatma'),
    ImportResult.updated => tr('حُدّثت الختمة', 'Khatma updated'),
    ImportResult.progress => tr('سُجّل الإنجاز', 'Progress recorded'),
    ImportResult.unknownKhatma => tr(
      'هذه الرسالة لختمة غير موجودة على هاتفك',
      'This message is for a khatma that is not on your phone',
    ),
    ImportResult.invalid => tr(
      'لم يُعثر على رمز ختمة في النص',
      'No khatma code was found in the text',
    ),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(feedback)));
  if (message case KhatmaShared(
    :final khatma,
  ) when result == ImportResult.joined) {
    GroupKhatmaScreen.open(context, khatma.id);
  }
}

class _CreateKhatmaScreen extends StatefulWidget {
  const _CreateKhatmaScreen();

  @override
  State<_CreateKhatmaScreen> createState() => _CreateKhatmaScreenState();
}

class _CreateKhatmaScreenState extends State<_CreateKhatmaScreen> {
  final _title = TextEditingController();
  final _name = TextEditingController();
  final _names = <String>[];
  String? _me;

  @override
  void dispose() {
    _title.dispose();
    _name.dispose();
    super.dispose();
  }

  void _addName() {
    final name = _name.text.trim();
    if (name.isEmpty || _names.contains(name) || _names.length >= juzCount) {
      return;
    }
    setState(() {
      _names.add(name);
      _me ??= name;
    });
    _name.clear();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final assignments = distributeJuz(_names.length);

    return Scaffold(
      appBar: AppBar(title: Text(tr('ختمة جديدة', 'New khatma'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            decoration: InputDecoration(
              labelText: tr('اسم الختمة', 'Khatma name'),
              hintText: tr('مثال: ختمة العائلة في رمضان', 'e.g. Family khatma'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addName(),
            decoration: InputDecoration(
              labelText: tr('اسم مشارك', 'Participant name'),
              helperText: tr(
                'أضف نفسك وكل المشاركين',
                'Add yourself and everyone taking part',
              ),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: tr('إضافة', 'Add'),
                icon: Icon(Icons.person_add_rounded, color: colorScheme.gold),
                onPressed: _addName,
              ),
            ),
          ),
          const SizedBox(height: 12),
          RadioGroup<String>(
            groupValue: _me,
            onChanged: (v) => setState(() => _me = v),
            child: Column(
              children: [
                for (var i = 0; i < _names.length; i++)
                  Card(
                    child: ListTile(
                      leading: Radio<String>(value: _names[i]),
                      title: Text(_names[i]),
                      subtitle: Text(_juzRange(assignments, i)),
                      trailing: IconButton(
                        tooltip: tr('حذف', 'Delete'),
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() {
                          if (_me == _names[i]) _me = null;
                          _names.removeAt(i);
                          _me ??= _names.firstOrNull;
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_names.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr(
                  'الدائرة بجانب الاسم تحدد اسمك أنت. يمكنك تغيير توزيع أي جزء لاحقاً بالضغط المطوّل عليه.',
                  'The circle marks your own name. You can reassign any juz later by long-pressing it.',
                ),
                style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.check_rounded),
            label: Text(tr('إنشاء الختمة', 'Create khatma')),
          ),
        ],
      ),
    );
  }

  void _create() {
    if (_names.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('أضف مشاركاً واحداً على الأقل', 'Add at least one participant'),
          ),
        ),
      );
      return;
    }
    final title = _title.text.trim().isEmpty
        ? tr('ختمة جماعية', 'Group khatma')
        : _title.text.trim();
    final k = Provider.of<GroupKhatmaProvider>(
      context,
      listen: false,
    ).create(title, _names, myName: _me);
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => GroupKhatmaScreen(id: k.id)),
    );
  }
}

String _juzRange(List<int> assignments, int person) {
  final juz = [
    for (var j = 0; j < juzCount; j++)
      if (assignments[j] == person) j + 1,
  ];
  if (juz.isEmpty) return '';
  final range = juz.length == 1 ? '${juz.first}' : '${juz.first}–${juz.last}';
  return '${AppConstant.juz} $range';
}

class GroupKhatmaScreen extends StatelessWidget {
  const GroupKhatmaScreen({super.key, required this.id});

  final String id;

  static void open(BuildContext context, String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => GroupKhatmaScreen(id: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final groups = Provider.of<GroupKhatmaProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;
    final k = groups.byId(id);
    if (k == null) return const Scaffold();
    final mine = k.myName == null ? const <int>[] : k.juzOf(k.myName!);
    final myDone = [
      for (final j in mine)
        if (k.done.contains(j)) j,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(k.title),
        actions: [
          IconButton(
            tooltip: tr('مشاركة الختمة', 'Share the khatma'),
            icon: const Icon(Icons.share_rounded),
            onPressed: () =>
                SharePlus.instance.share(ShareParams(text: khatmaMessage(k))),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'paste') pasteKhatmaMessage(context);
              if (v == 'delete' && await _confirmDelete(context)) {
                groups.remove(k);
                if (context.mounted) Navigator.pop(context);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'paste',
                child: Text(tr('لصق رسالة إنجاز', 'Paste a progress message')),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Text(tr('حذف الختمة', 'Delete khatma')),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    k.finished
                        ? tr(
                            'تمّت الختمة، تقبّل الله منكم',
                            'The khatma is complete. May Allah accept it from you all.',
                          )
                        : _progress(k),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: k.done.length / juzCount,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    color: colorScheme.gold,
                    backgroundColor: colorScheme.div,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: k.myName,
                    decoration: InputDecoration(
                      labelText: tr('أنا', 'I am'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(tr('لم أختر بعد', 'Not chosen')),
                      ),
                      for (final name in k.names)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (name) => groups.setMyName(k, name),
                  ),
                  if (myDone.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => SharePlus.instance.share(
                        ShareParams(text: doneMessage(k, myDone)),
                      ),
                      icon: const Icon(Icons.send_rounded),
                      label: Text(
                        tr('أرسل إنجازي للمجموعة', 'Send my progress'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var juz = 1; juz <= juzCount; juz++)
            _JuzTile(khatma: k, juz: juz, isMine: mine.contains(juz)),
          const SizedBox(height: 8),
          Text(
            tr(
              'اضغط على الجزء لفتحه في المصحف، وضع علامة عند إتمامه. اضغط مطوّلاً لتغيير قارئه.',
              'Tap a juz to open it in the mushaf and tick it when finished. Long-press to change who reads it.',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colorScheme.pageNumber),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr('حذف الختمة؟', 'Delete this khatma?')),
          content: Text(
            tr(
              'تُحذف من هذا الهاتف فقط.',
              'It is removed from this phone only.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppConstant.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr('حذف', 'Delete')),
            ),
          ],
        ),
      ) ??
      false;
}

class _JuzTile extends StatelessWidget {
  const _JuzTile({
    required this.khatma,
    required this.juz,
    required this.isMine,
  });

  final GroupKhatma khatma;
  final int juz;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final groups = Provider.of<GroupKhatmaProvider>(context, listen: false);
    final colorScheme = Theme.of(context).colorScheme;
    final done = khatma.done.contains(juz);

    return Card(
      color: isMine ? colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done ? colorScheme.gold : colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          child: Text('$juz'),
        ),
        title: Text('${AppConstant.juz} $juz'),
        subtitle: Text(
          isMine
              ? '${khatma.nameOf(juz)} · ${tr('جزئي', 'mine')}'
              : khatma.nameOf(juz),
        ),
        trailing: Checkbox(
          value: done,
          activeColor: colorScheme.gold,
          onChanged: (v) => groups.setDone(khatma, juz, v ?? false),
        ),
        onTap: () => openQuranPage(context, getJuzPage(juz), isTab: true),
        onLongPress: () => _reassign(context, groups),
      ),
    );
  }

  Future<void> _reassign(
    BuildContext context,
    GroupKhatmaProvider groups,
  ) async {
    final person = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(tr('من يقرأ الجزء $juz؟', 'Who reads juz $juz?')),
        children: [
          for (var i = 0; i < khatma.names.length; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, i),
              child: Text(khatma.names[i]),
            ),
        ],
      ),
    );
    if (person != null) groups.reassign(khatma, juz, person);
  }
}
