import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../services/notification_service.dart'; // [新增]
import 'task_detail_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int completedTaskCount = 0;
  List<String> categories = ["學校", "生活", "日常"];
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  Timer? _timer;
  final Set<String> _notifiedTasks = {};

  String get uid => FirebaseAuth.instance.currentUser!.uid;
  CollectionReference get tasksCollection => FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .collection('tasks');

  @override
  void initState() {
    super.initState();
    // [新增] 進入首頁時，請求通知權限
    NotificationService.requestPermissions();

    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      // 本地計時器保留
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // [修改] 新增任務 + 設定通知
  Future<void> addTask(String title, String category, String priority, DateTime date) async {
    // 1. 存入 Firebase
    DocumentReference docRef = await tasksCollection.add({
      'title': title,
      'category': category,
      'priority': priority,
      'status': 'Pending',
      'dueTime': Timestamp.fromDate(date),
      'note': '',
    });

    // 2. [新增] 設定排程通知
    // 使用 hashCode 將 String ID 轉為 int ID
    int notificationId = docRef.id.hashCode; 
    
    await NotificationService.scheduleNotification(
      id: notificationId,
      title: "⏰ 任務提醒：$title",
      body: "您的事項「$title」時間到了！",
      scheduledTime: date,
    );
  }

  // [修改] 刪除任務 + 取消通知
  Future<void> deleteTask(String taskId, {bool completed = false}) async {
    if (completed) {
      setState(() {
        completedTaskCount++;
      });
    }
    
    await tasksCollection.doc(taskId).delete();

    // [新增] 取消該任務的通知
    await NotificationService.cancelNotification(taskId.hashCode);
  }

  // [修改] 更新任務 + 重設通知
  Future<void> updateTask(Task task) async {
    await tasksCollection.doc(task.id).update(task.toMap());

    // [新增] 重設通知 (先取消舊的，再設新的)
    await NotificationService.cancelNotification(task.id.hashCode);
    await NotificationService.scheduleNotification(
      id: task.id.hashCode,
      title: "⏰ 任務提醒：${task.title}",
      body: "您的事項「${task.title}」時間到了！",
      scheduledTime: task.dueTime,
    );
  }

  void _rescheduleTask(Task task) {
    DateTime newDate = task.dueTime;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: CupertinoDatePicker(
                initialDateTime: newDate.add(const Duration(minutes: 30)),
                mode: CupertinoDatePickerMode.dateAndTime,
                onDateTimeChanged: (val) => newDate = val,
              ),
            ),
            CupertinoButton(
              child: const Text("確定延期"),
              onPressed: () {
                task.dueTime = newDate;
                updateTask(task); // 更新時會自動重設通知
                _notifiedTasks.remove(task.id);
                Navigator.pop(context);
              },
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: tasksCollection.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const CupertinoPageScaffold(child: Center(child: Text("連線錯誤")));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoPageScaffold(child: Center(child: CupertinoActivityIndicator()));
        }

        final List<Task> tasks = snapshot.data!.docs.map((doc) {
          return Task.fromFirestore(doc);
        }).toList();

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
            if (index == 0) return _buildHomeTab(tasks);
            if (index == 1) return _buildCalendarTab(tasks);
            return _buildMoreTab(tasks);
          },
        );
      },
    );
  }

  Widget _buildHomeTab(List<Task> tasks) {
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
            onReorder: (int oldIndex, int newIndex) {
              setState(() {
                if (oldIndex < newIndex) newIndex -= 1;
                final String item = categories.removeAt(oldIndex);
                categories.insert(newIndex, item);
              });
            },
            children: categories.map((cat) {
              List<Task> catTasks =
                  tasks.where((t) => t.category == cat).toList();
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
                        color: CupertinoColors.systemGrey6.withValues(alpha: 0.5),
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
                      ...catTasks.map((task) => _buildTaskItem(task)),
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
                onUpdate: () => updateTask(task),
              ),
            ),
          );
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
                            deleteTask(task.id, completed: true);
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
              _buildCountdownBadge(task.dueTime),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountdownBadge(DateTime dueTime) {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(minutes: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final diff = dueTime.difference(now);
        String text;
        Color color;

        if (diff.isNegative) {
          text = "已過期";
          color = CupertinoColors.destructiveRed;
        } else if (diff.inDays > 0) {
          text = "${diff.inDays}天";
          color = CupertinoColors.systemGreen;
        } else if (diff.inHours > 0) {
          text = "${diff.inHours}時";
          color = CupertinoColors.activeOrange;
        } else {
          text = "${diff.inMinutes}分";
          color = CupertinoColors.systemRed;
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(CupertinoIcons.time, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarTab(List<Task> tasks) {
    List<Task> dailyTasks =
        tasks.where((t) => isSameDay(t.dueTime, _selectedDay)).toList();

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
                      ...dailyTasks.map((t) => _buildTaskItem(t)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMoreTab(List<Task> tasks) {
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
                    () {
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
                    },
                  ),
                  const Divider(height: 1, indent: 50),
                  _buildMoreItem(
                    CupertinoIcons.chart_bar_alt_fill,
                    "生產力數據分析",
                    Colors.indigo,
                    true,
                    () {
                      _showProductivityCharts(context, tasks);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductivityCharts(BuildContext context, List<Task> tasks) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) {
        final isDarkMode =
            CupertinoTheme.of(context).brightness == Brightness.dark;
        return Container(
          height: 600,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDarkMode
                ? CupertinoColors.darkBackgroundGray
                : CupertinoColors.systemBackground,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "生產力儀表板",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text(
                          "累積完成",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          "$completedTaskCount",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Column(
                      children: [
                        const Text(
                          "待辦總數",
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        Text(
                          "${tasks.length}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              const Text("待辦類別分佈",
                  style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 15),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: categories.map((cat) {
                    int count =
                        tasks.where((t) => t.category == cat).length;
                    double percentage =
                        tasks.isEmpty ? 0 : count / (tasks.length + 1);
                    double heightFactor =
                        percentage == 0 ? 0.05 : percentage;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text("$count",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.activeBlue)),
                        const SizedBox(height: 5),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 40,
                          height: 150 * heightFactor + 20,
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeBlue.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(cat, style: const TextStyle(fontSize: 12)),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              CupertinoButton.filled(
                child: const Text("關閉"),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMoreItem(
    IconData icon,
    String title,
    Color color,
    bool isEnabled,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
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
              const Icon(CupertinoIcons.lock_fill,
                  size: 14, color: Colors.grey)
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

  // --- Add Task Modal (邏輯完全保留) ---
  void _showAddTaskModal(BuildContext context) {
    String currentTitle = "";
    DateTime selectedDate = DateTime.now(); 
    String selectedCategory =
        categories.isNotEmpty ? categories.first : "未分類";

    bool isAnalyzing = false;

    // AI 分析邏輯
    void analyzeAndSet(String input, StateSetter setModalState) {
      String lowerInput = input.toLowerCase();
      DateTime now = DateTime.now();
      DateTime newDate = selectedDate; 
      String? newCategory = selectedCategory;
      bool dateFound = false;

      if (lowerInput.contains("tomorrow")) {
        newDate = now.add(const Duration(days: 1));
        dateFound = true;
      }

      if (lowerInput.contains("tonight")) {
        newDate = DateTime(now.year, now.month, now.day, 19, 0);
        dateFound = true;
      }

      int? hour;
      if (lowerInput.contains("morning")) hour = 9;
      if (lowerInput.contains("afternoon")) hour = 14;
      if (lowerInput.contains("evening")) hour = 19;
      if (lowerInput.contains("noon")) hour = 12;

      RegExp timeReg = RegExp(r"(\d{1,2})[:.]?(\d{2})?\s*(am|pm)?");
      var matches = timeReg.allMatches(lowerInput);

      for (var match in matches) {
        int h = int.parse(match.group(1)!);
        if (h >= 0 && h <= 24) {
          int m = match.group(2) != null ? int.parse(match.group(2)!) : 0;
          String? period = match.group(3);
          if (period == "pm" && h < 12) h += 12;
          if (period == "am" && h == 12) h = 0;
          if (period == null &&
              (lowerInput.contains("evening") ||
                  lowerInput.contains("tonight"))) {
            if (h < 12) h += 12;
          }
          hour = h;
          dateFound = true;
          newDate = DateTime(newDate.year, newDate.month, newDate.day, h, m);
        }
      }
      if (dateFound && hour != null) {
        newDate = DateTime(newDate.year, newDate.month, newDate.day, hour, 0);
      } else if (dateFound && hour == null && lowerInput.contains("tomorrow")) {
        newDate = DateTime(newDate.year, newDate.month, newDate.day,
            DateTime.now().hour, DateTime.now().minute);
      } else if (!dateFound && hour != null) {
        newDate = DateTime(now.year, now.month, now.day, hour, 0);
      }

      // 類別偵測
      if (lowerInput.contains("school") ||
          lowerInput.contains("exam") ||
          lowerInput.contains("class") ||
          lowerInput.contains("study") ||
          lowerInput.contains("homework") ||
          lowerInput.contains("project")) {
        newCategory = "學校";
      } else if (lowerInput.contains("life") ||
          lowerInput.contains("movie") ||
          lowerInput.contains("game") ||
          lowerInput.contains("dinner") ||
          lowerInput.contains("party") ||
          lowerInput.contains("sleep") ||
          lowerInput.contains("date")) {
        newCategory = "生活";
      } else if (lowerInput.contains("buy") ||
          lowerInput.contains("shop") ||
          lowerInput.contains("clean") ||
          lowerInput.contains("wash") ||
          lowerInput.contains("cook") ||
          lowerInput.contains("daily")) {
        newCategory = "日常";
      }

      setModalState(() {
        selectedDate = newDate;
        if (newCategory != null) selectedCategory = newCategory;
      });
    }

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDarkMode =
                CupertinoTheme.of(context).brightness == Brightness.dark;
            return Container(
              height: 480, 
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
                  Row(
                    children: [
                      const Text("新增事項",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                      const Spacer(),
                      if (isAnalyzing) ...[
                        Icon(CupertinoIcons.sparkles,
                            size: 14, color: Colors.purple.withOpacity(0.6)),
                        Text(" 智慧分析偵測中...",
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple.withOpacity(0.8))),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),

                  CupertinoTextField(
                    placeholder: "", 
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    onChanged: (val) {
                      currentTitle = val;
                    },
                  ),
                  const SizedBox(height: 30),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildCircleBtn(
                        CupertinoIcons.calendar,
                        "時間",
                        DateFormat('MM/dd HH:mm').format(selectedDate),
                        () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (BuildContext builderContext) {
                              return Container(
                                height: 250,
                                color: isDarkMode
                                    ? CupertinoColors.black
                                    : CupertinoColors.white,
                                child: CupertinoDatePicker(
                                  mode: CupertinoDatePickerMode.dateAndTime,
                                  initialDateTime: selectedDate,
                                  use24hFormat: true,
                                  onDateTimeChanged: (DateTime newDateTime) {
                                    setModalState(() {
                                      selectedDate = newDateTime;
                                    });
                                  },
                                ),
                              );
                            },
                          );
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
                                  ...categories.map(
                                    (cat) => CupertinoActionSheetAction(
                                      child: Text(cat),
                                      onPressed: () {
                                        setModalState(
                                          () => selectedCategory = cat,
                                        );
                                        Navigator.pop(c);
                                      },
                                    ),
                                  ),
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
                                  isDestructiveAction: true,
                                  onPressed: () => Navigator.pop(c),
                                  child: const Text("取消"),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      
                      _buildCircleBtn(
                        CupertinoIcons.wand_stars,
                        "AI 功能",
                        "智慧分析",
                        () async {
                          if (currentTitle.isEmpty) return;

                          setModalState(() {
                            isAnalyzing = true;
                          });

                          await Future.delayed(
                              const Duration(milliseconds: 1500));

                          if (context.mounted) {
                            analyzeAndSet(currentTitle, setModalState);
                            setModalState(() {
                              isAnalyzing = false;
                            });
                          }
                        },
                        color: Colors.purple,
                      ),
                    ],
                  ),
                  const Spacer(),
                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(15),
                    child: const Text(
                      "確認新增",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (currentTitle.isNotEmpty) {
                        addTask(
                          currentTitle,
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
          Text(title,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
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