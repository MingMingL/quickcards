import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'repos.dart';
import 'state.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DecksScreen(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.style), label: '卡组'),
          NavigationDestination(icon: Icon(Icons.insights), label: '统计'),
          NavigationDestination(icon: Icon(Icons.settings), label: '设置'),
        ],
      ),
    );
  }
}

class DecksScreen extends StatelessWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DecksModel>();
    final settings = context.watch<SettingsModel>().settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QuickCards'),
      ),
      body: RefreshIndicator(
        onRefresh: model.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('今日待复习'),
                        Text(
                          '${model.globalDueCount}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    FilledButton(
                      onPressed: settings == null
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChangeNotifierProvider(
                                    create: (ctx) => ReviewSessionModel(
                                      repos: ctx.read<AppRepositories>(),
                                      settings: settings,
                                      initialDeckId: null,
                                    )..load(),
                                    child: const ReviewScreen(),
                                  ),
                                ),
                              );
                            },
                      child: const Text('开始复习'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('卡组', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...model.deckStats.map(
              (d) => ListTile(
                title: Text(d.deck.name),
                subtitle: Text('待复习 ${d.dueCards} · 总数 ${d.totalCards}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider(
                        create: (ctx) => DeckDetailModel(
                          repos: ctx.read<AppRepositories>(),
                          deck: d.deck,
                        )..refresh(),
                        child: const DeckDetailScreen(),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (model.deckStats.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: Text('还没有卡组，点右下角创建一个')),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final repos = context.read<AppRepositories>();
          final decksModel = context.read<DecksModel>();
          final name = await _askText(
            context: context,
            title: '新建卡组',
            hintText: '卡组名称',
          );
          if (name == null) return;
          final trimmed = name.trim();
          if (trimmed.isEmpty) return;
          await repos.decks.createDeck(name: trimmed);
          await decksModel.refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class DeckDetailScreen extends StatefulWidget {
  const DeckDetailScreen({super.key});

  @override
  State<DeckDetailScreen> createState() => _DeckDetailScreenState();
}

class _DeckDetailScreenState extends State<DeckDetailScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<DeckDetailModel>();
    final settings = context.watch<SettingsModel>().settings;

    return Scaffold(
      appBar: AppBar(
        title: Text(model.deck.name),
        actions: [
          IconButton(
            onPressed: () async {
              final decksModel = context.read<DecksModel>();
              final messenger = ScaffoldMessenger.of(context);
              final res = await FilePicker.platform.pickFiles(
                type: FileType.custom,
                allowedExtensions: const ['csv'],
                withData: true,
              );
              final bytes = res?.files.single.bytes;
              if (bytes == null) return;
              try {
                final count = await model.importCsv(bytes);
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('导入成功：$count 条')));
                await decksModel.refresh();
              } catch (e) {
                if (!mounted) return;
                messenger.showSnackBar(SnackBar(content: Text('导入失败：$e')));
              }
            },
            icon: const Icon(Icons.upload_file),
            tooltip: '导入 CSV',
          ),
          IconButton(
            onPressed: settings == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChangeNotifierProvider(
                          create: (ctx) => ReviewSessionModel(
                            repos: ctx.read<AppRepositories>(),
                            settings: settings,
                            initialDeckId: model.deck.id,
                          )..load(),
                          child: const ReviewScreen(),
                        ),
                      ),
                    );
                  },
            icon: const Icon(Icons.play_arrow),
            tooltip: '复习本卡组',
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              final repos = context.read<AppRepositories>();
              final decksModel = context.read<DecksModel>();
              final nav = Navigator.of(context);
              if (value == 'rename') {
                final name = await _askText(
                  context: context,
                  title: '重命名卡组',
                  initialText: model.deck.name,
                  hintText: '卡组名称',
                );
                if (name == null) return;
                final trimmed = name.trim();
                if (trimmed.isEmpty) return;
                await repos.decks.renameDeck(deckId: model.deck.id, name: trimmed);
                await decksModel.refresh();
                if (!context.mounted) return;
                nav.pop();
              }
              if (value == 'delete') {
                final ok = await _confirm(
                  context: context,
                  title: '删除卡组？',
                  content: '将同时删除该卡组内所有卡片',
                );
                if (!ok) return;
                await repos.decks.deleteDeck(model.deck.id);
                await decksModel.refresh();
                if (!context.mounted) return;
                nav.pop();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'rename', child: Text('重命名')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索单词或释义',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => model.setQuery(v),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                final decksModel = context.read<DecksModel>();
                await model.refresh();
                await decksModel.refresh();
              },
              child: ListView.builder(
                itemCount: model.cards.length,
                itemBuilder: (context, index) {
                  final c = model.cards[index];
                  return ListTile(
                    title: Text(c.front),
                    subtitle: Text(
                      c.back,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      final decksModel = context.read<DecksModel>();
                      final res = await Navigator.of(context).push<_CardEditResult>(
                        MaterialPageRoute(
                          builder: (_) => CardEditScreen(
                            title: '编辑卡片',
                            initialFront: c.front,
                            initialBack: c.back,
                            initialTags: c.tags ?? '',
                          ),
                        ),
                      );
                      if (res == null) return;
                      await model.updateCard(
                        cardId: c.id,
                        front: res.front,
                        back: res.back,
                        tags: res.tags,
                      );
                      if (!mounted) return;
                      await decksModel.refresh();
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final decksModel = context.read<DecksModel>();
                        final ok = await _confirm(
                          context: context,
                          title: '删除这张卡片？',
                          content: c.front,
                        );
                        if (!ok) return;
                        await model.deleteCard(c.id);
                        if (!mounted) return;
                        await decksModel.refresh();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final decksModel = context.read<DecksModel>();
          final res = await Navigator.of(context).push<_CardEditResult>(
            MaterialPageRoute(
              builder: (_) => const CardEditScreen(title: '新建卡片'),
            ),
          );
          if (res == null) return;
          await model.addCard(front: res.front, back: res.back, tags: res.tags);
          if (!mounted) return;
          await decksModel.refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CardEditScreen extends StatefulWidget {
  const CardEditScreen({
    super.key,
    required this.title,
    this.initialFront,
    this.initialBack,
    this.initialTags,
  });

  final String title;
  final String? initialFront;
  final String? initialBack;
  final String? initialTags;

  @override
  State<CardEditScreen> createState() => _CardEditScreenState();
}

class _CardEditScreenState extends State<CardEditScreen> {
  late final TextEditingController _front;
  late final TextEditingController _back;
  late final TextEditingController _tags;

  @override
  void initState() {
    super.initState();
    _front = TextEditingController(text: widget.initialFront ?? '');
    _back = TextEditingController(text: widget.initialBack ?? '');
    _tags = TextEditingController(text: widget.initialTags ?? '');
  }

  @override
  void dispose() {
    _front.dispose();
    _back.dispose();
    _tags.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: () {
              final front = _front.text.trim();
              final back = _back.text.trim();
              final tags = _tags.text.trim();
              if (front.isEmpty || back.isEmpty) return;
              Navigator.of(context).pop(
                _CardEditResult(front: front, back: back, tags: tags.isEmpty ? null : tags),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _front,
            decoration: const InputDecoration(
              labelText: '正面（单词）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _back,
            decoration: const InputDecoration(
              labelText: '背面（释义/例句）',
              border: OutlineInputBorder(),
            ),
            minLines: 3,
            maxLines: 6,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tags,
            decoration: const InputDecoration(
              labelText: '标签（可选，用 ; 分隔）',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardEditResult {
  const _CardEditResult({required this.front, required this.back, required this.tags});

  final String front;
  final String back;
  final String? tags;
}

class ReviewScreen extends StatelessWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<ReviewSessionModel>();
    final cur = model.current;
    final total = model.queue.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(total == 0 ? '复习' : '复习 ${model.index + 1}/$total'),
        actions: [
          if (model.decks.isNotEmpty)
            DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: model.deckId,
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('全部卡组'),
                  ),
                  ...model.decks.map(
                    (d) => DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(d.name),
                    ),
                  ),
                ],
                onChanged: (v) => model.setDeck(v),
              ),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: total == 0
          ? const Center(child: Text('今天没有待复习卡片'))
          : cur == null
              ? _ReviewSummary(
                  again: model.againCount,
                  hard: model.hardCount,
                  good: model.goodCount,
                  easy: model.easyCount,
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Expanded(
                        child: Card(
                          child: InkWell(
                            onTap: model.toggleAnswer,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      cur.front,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context).textTheme.headlineMedium,
                                    ),
                                    if (model.showAnswer) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        cur.back,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.titleLarge,
                                      ),
                                      if ((cur.tags ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          cur.tags ?? '',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (!model.showAnswer)
                        FilledButton(
                          onPressed: model.toggleAnswer,
                          child: const Text('显示答案'),
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => model.grade(1),
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                ),
                                child: const Text('Again'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => model.grade(3),
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.orange.shade800,
                                ),
                                child: const Text('Hard'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => model.grade(4),
                                child: const Text('Good'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: () => model.grade(5),
                                style: FilledButton.styleFrom(
                                  foregroundColor: Colors.green.shade800,
                                ),
                                child: const Text('Easy'),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
    );
  }
}

class _ReviewSummary extends StatelessWidget {
  const _ReviewSummary({
    required this.again,
    required this.hard,
    required this.good,
    required this.easy,
  });

  final int again;
  final int hard;
  final int good;
  final int easy;

  @override
  Widget build(BuildContext context) {
    final total = again + hard + good + easy;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('完成', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text('本次复习 $total 张'),
            const SizedBox(height: 12),
            Text('Again $again · Hard $hard · Good $good · Easy $easy'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                context.read<DecksModel>().refresh();
                context.read<StatsModel>().refresh();
                Navigator.of(context).pop();
              },
              child: const Text('返回'),
            ),
          ],
        ),
      ),
    );
  }
}

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<StatsModel>();
    final max = model.last7Days.fold<int>(1, (m, d) => d.count > m ? d.count : m);

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
        actions: [
          IconButton(
            onPressed: model.refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('今日复习'),
                        Text(
                          '${model.todayReviews}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('连续天数'),
                        Text(
                          '${model.streakDays}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Good/Easy 比例'),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: model.todayGoodEasyRate),
                  const SizedBox(height: 8),
                  Text('${(model.todayGoodEasyRate * 100).toStringAsFixed(0)}%'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text('近 7 天', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...model.last7Days.map((d) {
            final date = DateTime.fromMillisecondsSinceEpoch(d.dayStartMs);
            final label = '${date.month}/${date.day}';
            final value = d.count / max;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(width: 56, child: Text(label)),
                  Expanded(child: LinearProgressIndicator(value: value)),
                  const SizedBox(width: 12),
                  SizedBox(width: 32, child: Text('${d.count}')),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final model = context.watch<SettingsModel>();
    final settings = model.settings;
    final dailyGoal = settings?.dailyGoal ?? 20;
    final newCardsPerDay = settings?.newCardsPerDay ?? 10;
    final decksModel = context.read<DecksModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('今日目标'),
            subtitle: Text('$dailyGoal 张'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final v = await _askNumber(
                context: context,
                title: '今日目标',
                initialValue: dailyGoal,
                min: 1,
                max: 500,
              );
              if (v == null) return;
              await model.setDailyGoal(v);
              await decksModel.refresh();
            },
          ),
          ListTile(
            title: const Text('每日新卡上限'),
            subtitle: Text('$newCardsPerDay 张'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final v = await _askNumber(
                context: context,
                title: '每日新卡上限',
                initialValue: newCardsPerDay,
                min: 0,
                max: 200,
              );
              if (v == null) return;
              await model.setNewCardsPerDay(v);
              await decksModel.refresh();
            },
          ),
          const SizedBox(height: 12),
          const ListTile(
            title: Text('隐私说明'),
            subtitle: Text('本应用离线使用，不收集个人信息'),
          ),
        ],
      ),
    );
  }
}

Future<String?> _askText({
  required BuildContext context,
  required String title,
  required String hintText,
  String? initialText,
}) async {
  final controller = TextEditingController(text: initialText ?? '');
  final res = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: hintText),
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  return res;
}

Future<int?> _askNumber({
  required BuildContext context,
  required String title,
  required int initialValue,
  required int min,
  required int max,
}) async {
  final controller = TextEditingController(text: '$initialValue');
  final res = await showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final v = int.tryParse(controller.text.trim());
            if (v == null) return;
            if (v < min || v > max) return;
            Navigator.of(context).pop(v);
          },
          child: const Text('确定'),
        ),
      ],
    ),
  );
  return res;
}

Future<bool> _confirm({
  required BuildContext context,
  required String title,
  required String content,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('确定'),
        ),
      ],
    ),
  );
  return res ?? false;
}
