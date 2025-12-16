import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/task.dart';
import 'task_detail_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // [修改] 這裡改成空的，一開始什麼都沒有
  List<Task> tasks = [];

  // 類別清單
  List<String> categories = ["學校", "生活", "日常"];

  // 行事曆相關
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  // 1. 新增事項
  void addTask(String title, String category, String priority, DateTime date) {
    setState(() {
      tasks.add(
        Task(
          id: DateTime.now().toString(), // 用時間當 ID
          title: title,
          category: category,
          priority: priority,
          status: "Pending",
          dueTime: date,
          note: "",
        ),
      );
    });
  }

  // 2. 刪除事項
  void deleteTask(String taskId) {
    setState(() {
      tasks.removeWhere((t) => t.id == taskId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.list_bullet),
            label: '待辦',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: '行事曆',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_grid_2x2),
            label: '更多',
          ),
        ],
      ),
      tabBuilder: (context, index) {
        if (index == 0) return _buildHomeTab();
        if (index == 1) return _buildCalendarTab();
        return _buildMoreTab();
      },
    );
  }

  // [分頁 1] 主畫面
  Widget _buildHomeTab() {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('我的事項'),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const CircleAvatar(child: Icon(CupertinoIcons.person)),
          onPressed: () {
            Navigator.of(context).push(
              CupertinoPageRoute(builder: (context) => const ProfileScreen()),
            );
          },
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  CupertinoPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
            CupertinoButton(
              padding: EdgeInsets.zero,
              child: const Icon(CupertinoIcons.add),
              onPressed: () => _showAddTaskModal(context),
            ),
          ],
        ),
      ),
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: ReorderableListView(
            padding: const EdgeInsets.all(16),
            // [修改] 這裡原本有的 header: Text("長按...") 已經刪除了
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final String item = categories.removeAt(oldIndex);
                categories.insert(newIndex, item);
              });
            },
            children: categories.map((cat) {
              List<Task> catTasks = tasks
                  .where((t) => t.category == cat)
                  .toList();
              catTasks.sort((a, b) => a.dueTime.compareTo(b.dueTime));

              final isDarkMode =
                  CupertinoTheme.of(context).brightness == Brightness.dark;

              return Container(
                key: ValueKey(cat),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? CupertinoColors.darkBackgroundGray
                      : CupertinoColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode
                          ? Colors.white.withOpacity(0.05)
                          : Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.systemGrey6.withOpacity(0.5),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            cat,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Icon(
                            Icons.drag_handle,
                            color: CupertinoColors.systemGrey,
                          ),
                        ],
                      ),
                    ),
                    if (catTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          "暫無事項",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...catTasks.map((task) => _buildTaskItem(task)).toList(),
                    const SizedBox(height: 10),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskItem(Task task) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.startToEnd,
      onDismissed: (direction) {
        deleteTask(task.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${task.title} 已刪除"),
            action: SnackBarAction(
              label: "復原",
              onPressed: () {
                // This is a simplified undo. For a real app, you'd need to
                // re-insert the task at its original position.
                setState(() {
                  tasks.add(task);
                });
              },
            ),
          ),
        );
      },
      background: Container(
        color: CupertinoColors.destructiveRed,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        child: const Icon(CupertinoIcons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () async {
          await Navigator.of(context).push(
            CupertinoPageRoute(
              builder: (context) => TaskDetailPage(
                task: task,
                onDelete: () => deleteTask(task.id),
              ),
            ),
          );
          setState(() {});
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: CupertinoColors.systemGrey6),
            ),
            color: Colors.transparent,
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () {
                  showCupertinoDialog(
                    context: context,
                    builder: (context) => CupertinoAlertDialog(
                      title: const Text("完成事項"),
                      content: const Text("確定事項已完成？"),
                      actions: [
                        CupertinoDialogAction(
                          child: const Text("取消"),
                          onPressed: () => Navigator.pop(context),
                        ),
                        CupertinoDialogAction(
                          isDestructiveAction: true,
                          child: const Text("確定"),
                          onPressed: () {
                            deleteTask(task.id);
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  );
                },
                child: const Icon(
                  CupertinoIcons.circle,
                  color: CupertinoColors.systemGrey,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 16,
                        color: CupertinoTheme.of(
                          context,
                        ).textTheme.textStyle.color,
                      ),
                    ),
                    Text(
                      DateFormat('M月d日 HH:mm', 'zh_TW').format(task.dueTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: task.priority == 'High'
                            ? CupertinoColors.systemRed
                            : CupertinoColors.systemGrey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // [分頁 2] 行事曆
  Widget _buildCalendarTab() {
    List<Task> dailyTasks = tasks
        .where((t) => isSameDay(t.dueTime, _selectedDay))
        .toList();

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('行事曆')),
      child: SafeArea(
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CupertinoTheme.of(context).brightness == Brightness.dark
                    ? CupertinoColors.darkBackgroundGray
                    : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color:
                        CupertinoTheme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: TableCalendar(
                  locale: 'zh_TW',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: (day) {
                    return tasks
                        .where((task) => isSameDay(task.dueTime, day))
                        .toList();
                  },
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: CupertinoColors.activeBlue,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: CupertinoColors.systemRed,
                      shape: BoxShape.circle,
                    ),
                    markerDecoration: BoxDecoration(
                      color: CupertinoColors.systemGrey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color:
                      CupertinoTheme.of(context).brightness == Brightness.dark
                      ? CupertinoColors.darkBackgroundGray
                      : CupertinoColors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      "${DateFormat('M月d日', 'zh_TW').format(_selectedDay)} 待辦事項",
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (dailyTasks.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text(
                          "今天沒有事項！",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    else
                      ...dailyTasks.map((t) => _buildTaskItem(t)).toList(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // [分頁 3] 更多功能
  Widget _buildMoreTab() {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('更多功能')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              decoration: BoxDecoration(
                color: CupertinoTheme.of(context).brightness == Brightness.dark
                    ? CupertinoColors.darkBackgroundGray
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildMoreItem(
                    CupertinoIcons.timer,
                    "番茄鐘專注模式",
                    Colors.red,
                    true,
                  ),
                  const Divider(height: 1, indent: 50),
                  _buildMoreItem(
                    CupertinoIcons.chart_bar_alt_fill,
                    "生產力數據分析",
                    Colors.indigo,
                    false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreItem(
    IconData icon,
    String title,
    Color color,
    bool isEnabled,
  ) {
    return GestureDetector(
      onTap: () {
        if (isEnabled) {
          showCupertinoDialog(
            context: context,
            builder: (c) => CupertinoAlertDialog(
              title: const Text("番茄鐘"),
              content: const Text("開始 25 分鐘專注模式？\n(模擬功能)"),
              actions: [
                CupertinoDialogAction(
                  child: const Text("開始"),
                  onPressed: () => Navigator.pop(c),
                ),
              ],
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 15),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isEnabled
                    ? CupertinoTheme.of(context).textTheme.textStyle.color
                    : Colors.grey,
              ),
            ),
            const Spacer(),
            if (!isEnabled)
              const Icon(CupertinoIcons.lock_fill, size: 14, color: Colors.grey)
            else
              const Icon(
                CupertinoIcons.chevron_right,
                size: 14,
                color: Colors.grey,
              ),
          ],
        ),
      ),
    );
  }

  // 新增事項
  void _showAddTaskModal(BuildContext context) {
    String newTitle = "";
    DateTime selectedDate = DateTime.now();
    String selectedCategory = categories.isNotEmpty ? categories.first : "未分類";

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDarkMode =
                CupertinoTheme.of(context).brightness == Brightness.dark;
            return Container(
              height: 380,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? CupertinoColors.darkBackgroundGray
                    : CupertinoColors.systemBackground,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 160,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey4,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    placeholder: "輸入事項名稱...",
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    onChanged: (val) => newTitle = val,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCircleBtn(
                        CupertinoIcons.calendar,
                        "時間",
                        selectedDate.year == DateTime.now().year &&
                                selectedDate.day == DateTime.now().day
                            ? "今天"
                            : DateFormat('M月d日', 'zh_TW').format(selectedDate),
                        () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null && picked != selectedDate) {
                            setModalState(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                      _buildCircleBtn(
                        CupertinoIcons.tag,
                        "類別",
                        selectedCategory,
                        () {
                          if (categories.isEmpty) {
                            _showAddCat(context, (c) {
                              setState(() => categories.add(c));
                              setModalState(() => selectedCategory = c);
                            });
                          } else {
                            showCupertinoModalPopup(
                              context: context,
                              builder: (c) => CupertinoActionSheet(
                                actions: [
                                  ...categories
                                      .map(
                                        (cat) => CupertinoActionSheetAction(
                                          child: Text(cat),
                                          onPressed: () {
                                            setModalState(
                                              () => selectedCategory = cat,
                                            );
                                            Navigator.pop(c);
                                          },
                                        ),
                                      )
                                      .toList(),
                                  CupertinoActionSheetAction(
                                    child: const Text("新增類別..."),
                                    onPressed: () {
                                      Navigator.pop(c);
                                      _showAddCat(context, (c) {
                                        setState(() => categories.add(c));
                                        setModalState(
                                          () => selectedCategory = c,
                                        );
                                      });
                                    },
                                  ),
                                ],
                                cancelButton: CupertinoActionSheetAction(
                                  child: const Text("取消"),
                                  isDestructiveAction: true,
                                  onPressed: () => Navigator.pop(c),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      _buildCircleBtn(
                        CupertinoIcons.sparkles,
                        "AI 排序",
                        "分析",
                        () {
                          showCupertinoDialog(
                            context: context,
                            builder: (c) => CupertinoAlertDialog(
                              title: const Text("AI 分析中..."),
                              content: const Text("已自動優化排程權重 (模擬)"),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text("OK"),
                                  onPressed: () => Navigator.pop(c),
                                ),
                              ],
                            ),
                          );
                        },
                        color: Colors.purple,
                      ),
                    ],
                  ),
                  const Spacer(),
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(15),
                    child: const Text(
                      "儲存事項",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (newTitle.isNotEmpty) {
                        addTask(
                          newTitle,
                          selectedCategory,
                          "Medium",
                          selectedDate,
                        );
                        Navigator.pop(context);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCircleBtn(
    IconData icon,
    String title,
    String sub,
    VoidCallback onTap, {
    Color color = CupertinoColors.activeBlue,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            sub,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCat(BuildContext context, Function(String) cb) {
    String t = "";
    showCupertinoDialog(
      context: context,
      builder: (c) => CupertinoAlertDialog(
        title: const Text("新增類別"),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            onChanged: (v) => t = v,
            placeholder: "例如: 社團",
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("取消"),
            onPressed: () => Navigator.pop(c),
          ),
          CupertinoDialogAction(
            child: const Text("新增"),
            onPressed: () {
              if (t.isNotEmpty) {
                cb(t);
                Navigator.pop(c);
              }
            },
          ),
        ],
      ),
    );
  }
}
