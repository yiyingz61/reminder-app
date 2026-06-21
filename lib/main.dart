import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/todo_screen.dart';
import 'screens/schedule_edit_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeDateFormatting('zh'); // 初始化中文日期格式数据
  runApp(const ReminderApp());
}

class ReminderApp extends StatelessWidget {
  const ReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '日程提醒',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('zh'),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh'), Locale('en')],
      home: const RootShell(),
    );
  }
}

/// 应用外壳：底部两个页签（我的一天 / 待办），中间悬浮圆形按钮新建日程。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // 用 key 触发子页面在新建数据后刷新。
  final _homeKey = GlobalKey<HomeScreenState>();
  final _todoKey = GlobalKey<TodoScreenState>();

  late final List<Widget> _pages = [
    HomeScreen(key: _homeKey),
    TodoScreen(key: _todoKey),
  ];

  Future<void> _createSchedule() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ScheduleEditScreen(initialDate: DateTime.now()),
        fullscreenDialog: true,
      ),
    );
    if (created == true) {
      _homeKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        height: 64,
        width: 64,
        child: FloatingActionButton(
          heroTag: 'create-schedule',
          shape: const CircleBorder(),
          elevation: 4,
          onPressed: _createSchedule,
          child: const Icon(Icons.add, size: 32),
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 68,
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.today_outlined,
              activeIcon: Icons.today,
              label: '我的一天',
              selected: _index == 0,
              color: scheme.primary,
              onTap: () => setState(() => _index = 0),
            ),
            const SizedBox(width: 64), // 给中间 FAB 留出缺口
            _NavItem(
              icon: Icons.check_circle_outline,
              activeIcon: Icons.check_circle,
              label: '待办',
              selected: _index == 1,
              color: scheme.primary,
              onTap: () => setState(() => _index = 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = selected ? color : Colors.grey.shade500;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: c, size: 24),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    color: c,
                    fontSize: 11,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }
}
