import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';
import '../services/notification_service.dart';
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
  Timer? _timer;
  final Set<String> _notifiedTasks = {};

  String get uid => FirebaseAuth.instance.currentUser!.uid;
  String? get userEmail => FirebaseAuth.instance.currentUser!.email;

  // [修改] 改用全域集合 'all_tasks'
  CollectionReference get tasksCollection =>
      FirebaseFirestore.instance.collection('all_tasks');

  @override
  void initState() {
    super.initState();
    NotificationService.requestPermissions();
    _timer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        _checkDueTasks();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkDueTasks() {
    if (userEmail == null) return;

    // [修改] 查詢包含自己 Email 的任務
    tasksCollection
        .where('members', arrayContains: userEmail)
        .where('status', isEqualTo: 'Pending')
        .get()
        .then((snapshot) {
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        Task task = Task.fromFirestore(doc);

        if (now.isAfter(task.dueTime) && !_notifiedTasks.contains(task.id)) {
          setState(() {
            _notifiedTasks.add(task.id);
          });
          _showTimeoutDialog(task);
        }
      }
    });
  }

  void _showTimeoutDialog(Task task) {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Column(
          children: [
            Icon(CupertinoIcons.alarm_fill,
                color: CupertinoColors.systemRed, size: 50),
            SizedBox(height: 10),
            Text("時間到囉！"),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "事項「${task.title}」的預定時間已經結束。\n接下來要怎麼做？",
            style: const TextStyle(fontSize: 15),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("繼續做 (延時)"),
            onPressed: () {
              Navigator.pop(context);
              _rescheduleTask(task);
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("已完成"),
            onPressed: () {
              deleteTask(task.id, completed: true);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  void _rescheduleTask(Task task) {
    DateTime newDate = task.dueTime.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(minutes: 30))
        : task.dueTime;
    showCupertinoModalPopup(
      context: context,
      builder: (context) => Container(
        height: 300,
        color: CupertinoColors.systemBackground.resolveFrom(context),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: CupertinoColors.systemGrey6.withValues(alpha: 0.5),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("選擇新的時間",
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: const Text("確定延期"),
                    onPressed: () {
                      task.dueTime = newDate;
                      updateTask(task);
                      _notifiedTasks.remove(task.id);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                initialDateTime: newDate,
                mode: CupertinoDatePickerMode.dateAndTime,
                use24hFormat: true,
                onDateTimeChanged: (val) => newDate = val,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // [修改] 支援傳入多個 Email
  Future<void> addTask(String title, String category, String priority,
      DateTime date, String recurrence, List<String> sharedEmails) async {
    if (userEmail == null) return;

    // 建立成員名單：我自己 + 邀請的人
    List<String> members = [userEmail!];
    for (String email in sharedEmails) {
      if (email.isNotEmpty && !members.contains(email)) {
        members.add(email.trim());
      }
    }

    DocumentReference docRef = await tasksCollection.add({
      'title': title,
      'category': category,
      'priority': priority,
      'status': 'Pending',
      'dueTime': Timestamp.fromDate(date),
      'note': '',
      'recurrence': recurrence,
      'members': members, // [修改]
    });

    int notificationId = docRef.id.hashCode;

    await NotificationService.scheduleNotification(
      id: notificationId,
      title: "⏰ 任務提醒：$title",
      body: "您的事項「$title」時間到了！",
      scheduledTime: date,
    );
  }

  Future<void> deleteTask(String taskId, {bool completed = false}) async {
    if (completed) {
      DocumentSnapshot doc = await tasksCollection.doc(taskId).get();
      if (doc.exists) {
        Task task = Task.fromFirestore(doc);
        if (task.recurrence != '不重複') {
          DateTime nextDueTime;
          switch (task.recurrence) {
            case '每天':
              nextDueTime = task.dueTime.add(const Duration(days: 1));
              break;
            case '每週':
              nextDueTime = task.dueTime.add(const Duration(days: 7));
              break;
            case '每月':
              nextDueTime = DateTime(task.dueTime.year, task.dueTime.month + 1,
                  task.dueTime.day, task.dueTime.hour, task.dueTime.minute);
              break;
            default:
              nextDueTime = task.dueTime;
          }

          // [修改] 遞迴建立新任務時，要繼承原本的成員
          List<String> others = List.from(task.members);
          others.remove(userEmail); // 移除自己，因為 addTask 會自動加回去

          await addTask(task.title, task.category, task.priority, nextDueTime,
              task.recurrence, others);
        }
      }

      setState(() {
        completedTaskCount++;
      });
    }

    await tasksCollection.doc(taskId).delete();
    await NotificationService.cancelNotification(taskId.hashCode);
  }

  Future<void> updateTask(Task task) async {
    await tasksCollection.doc(task.id).update(task.toMap());
    await NotificationService.cancelNotification(task.id.hashCode);
    await NotificationService.scheduleNotification(
      id: task.id.hashCode,
      title: "⏰ 任務提醒：${task.title}",
      body: "您的事項「${task.title}」時間到了！",
      scheduledTime: task.dueTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (userEmail == null) {
      return const CupertinoPageScaffold(child: Center(child: Text("請先登入")));
    }

    return StreamBuilder<QuerySnapshot>(
      // [修改] 查詢條件
      stream: tasksCollection
          .where('members', arrayContains: userEmail)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const CupertinoPageScaffold(
              child: Center(child: Text("連線錯誤")));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CupertinoPageScaffold(
              child: Center(child: CupertinoActivityIndicator()));
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
            if (index == 1) {
              return _CalendarTab(parentState: this, tasks: tasks);
            }
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
                        color:
                            CupertinoColors.systemGrey6.withValues(alpha: 0.5),
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
    // [修改] 檢查是否共用
    bool isShared = task.members.length > 1;

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
                  // 手動點擊圓圈完成
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
                    Row(
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
                        // [修改] 如果是共享任務，顯示圖示
                        if (isShared) ...[
                          const SizedBox(width: 6),
                          const Icon(CupertinoIcons.person_2_fill,
                              size: 14, color: CupertinoColors.activeBlue),
                        ]
                      ],
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
              // Overview
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 15),
              // Charts
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: categories.map((cat) {
                    int count = tasks.where((t) => t.category == cat).length;
                    double percentage =
                        tasks.isEmpty ? 0 : count / (tasks.length + 1);
                    double heightFactor = percentage == 0 ? 0.05 : percentage;
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
                            color: CupertinoColors.activeBlue
                                .withValues(alpha: 0.6),
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

  // [修改] 支援多選 Email 的彈窗
  void _showAddTaskModal(BuildContext context) {
    String currentTitle = "";
    DateTime selectedDate = DateTime.now();
    String selectedCategory = categories.isNotEmpty ? categories.first : "未分類";
    String selectedRecurrence = "不重複";

    // [新增] 多選 Email 變數
    List<String> tempSharedEmails = [];
    TextEditingController emailController = TextEditingController();

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDarkMode =
                CupertinoTheme.of(context).brightness == Brightness.dark;
            return Container(
              height: 600, // 高度調高
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
                  const Text("新增事項",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 10),
                  CupertinoTextField(
                    placeholder: "例如：每週一早上九點開會",
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    onChanged: (val) {
                      currentTitle = val;
                    },
                  ),
                  const SizedBox(height: 20),
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
                        CupertinoIcons.repeat,
                        "週期",
                        selectedRecurrence,
                        () {
                          showCupertinoModalPopup(
                            context: context,
                            builder: (c) => CupertinoActionSheet(
                              actions: ["不重複", "每天", "每週", "每月"]
                                  .map((rec) => CupertinoActionSheetAction(
                                        child: Text(rec),
                                        onPressed: () {
                                          setModalState(
                                              () => selectedRecurrence = rec);
                                          Navigator.pop(c);
                                        },
                                      ))
                                  .toList(),
                              cancelButton: CupertinoActionSheetAction(
                                isDestructiveAction: true,
                                onPressed: () => Navigator.pop(c),
                                child: const Text("取消"),
                              ),
                            ),
                          );
                        },
                        color: Colors.green,
                      ),
                    ],
                  ),

                  const Spacer(),

                  // --- [新增] 共享成員多選區塊 ---
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("共享對象",
                          style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: CupertinoTextField(
                              controller: emailController,
                              placeholder: "輸入 Gmail",
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: const Icon(CupertinoIcons.add_circled_solid,
                                size: 28),
                            onPressed: () {
                              if (emailController.text.contains('@')) {
                                setModalState(() {
                                  tempSharedEmails
                                      .add(emailController.text.trim());
                                  emailController.clear();
                                });
                              }
                            },
                          )
                        ],
                      ),
                      if (tempSharedEmails.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: tempSharedEmails.map((email) {
                              return Container(
                                padding: const EdgeInsets.fromLTRB(10, 5, 5, 5),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.activeBlue
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                      color: CupertinoColors.activeBlue
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(email,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: CupertinoColors.activeBlue)),
                                    const SizedBox(width: 5),
                                    GestureDetector(
                                      onTap: () {
                                        setModalState(() {
                                          tempSharedEmails.remove(email);
                                        });
                                      },
                                      child: const Icon(
                                          CupertinoIcons.xmark_circle_fill,
                                          size: 18,
                                          color: CupertinoColors.activeBlue),
                                    )
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  CupertinoButton.filled(
                    borderRadius: BorderRadius.circular(15),
                    child: const Text(
                      "確認新增",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      if (currentTitle.isNotEmpty) {
                        // 如果輸入框還有字沒按+，自動加進去
                        if (emailController.text.isNotEmpty &&
                            emailController.text.contains('@')) {
                          tempSharedEmails.add(emailController.text.trim());
                        }

                        addTask(
                          currentTitle,
                          selectedCategory,
                          "Medium",
                          selectedDate,
                          selectedRecurrence,
                          tempSharedEmails, // [修改] 傳入 List
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

// --- Calendar Tab ---
class _CalendarTab extends StatefulWidget {
  final _HomeScreenState parentState;
  final List<Task> tasks;

  const _CalendarTab({required this.parentState, required this.tasks});

  @override
  _CalendarTabState createState() => _CalendarTabState();
}

class _CalendarTabState extends State<_CalendarTab> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  @override
  Widget build(BuildContext context) {
    List<Task> dailyTasks =
        widget.tasks.where((t) => isSameDay(t.dueTime, _selectedDay)).toList();
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
                    return widget.tasks
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
                      ...dailyTasks
                          .map((t) => widget.parentState._buildTaskItem(t)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
