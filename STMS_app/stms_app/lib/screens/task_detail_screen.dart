import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;
  final VoidCallback onDelete;
  final VoidCallback onUpdate;

  const TaskDetailPage({
    super.key,
    required this.task,
    required this.onDelete,
    required this.onUpdate,
  });

  @override
  State<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends State<TaskDetailPage> {
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  late DateTime _currentDueTime;

  Timer? _timer;
  Duration _timeLeft = Duration.zero;
  bool _hasAlerted = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _noteController = TextEditingController(text: widget.task.note);
    _currentDueTime = widget.task.dueTime;
    _updateTimeLeft();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateTimeLeft();
        });
        _checkIfTimeUp();
      }
    });
  }

  void _checkIfTimeUp() {
    if (_timeLeft.isNegative && !_hasAlerted) {
      _hasAlerted = true;
      _showDetailTimeoutDialog();
    }
  }

  void _showDetailTimeoutDialog() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: const Column(
          children: [
            Icon(CupertinoIcons.exclamationmark_circle_fill,
                color: CupertinoColors.systemRed, size: 50),
            SizedBox(height: 10),
            Text("倒數結束"),
          ],
        ),
        content: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            "事項「${widget.task.title}」的時間到了！",
            style: const TextStyle(fontSize: 16),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("延長時間"),
            onPressed: () {
              Navigator.pop(context);
              _showDatePicker();
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("標記完成"),
            onPressed: () {
              widget.onDelete();
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  @override
  void deactivate() {
    if (widget.task.title != _titleController.text ||
        widget.task.note != _noteController.text ||
        widget.task.dueTime != _currentDueTime) {
      widget.task.title = _titleController.text;
      widget.task.note = _noteController.text;
      widget.task.dueTime = _currentDueTime;

      widget.onUpdate();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _updateTimeLeft() {
    final now = DateTime.now();
    _timeLeft = _currentDueTime.difference(now);
  }

  void _showDatePicker() {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext builderContext) {
        return Container(
          height: 250,
          color: CupertinoTheme.of(context).brightness == Brightness.dark
              ? CupertinoColors.black
              : CupertinoColors.white,
          child: Column(
            children: [
              SizedBox(
                height: 190,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _currentDueTime,
                  use24hFormat: true,
                  onDateTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      _currentDueTime = newDateTime;
                      _hasAlerted = false;
                    });
                  },
                ),
              ),
              CupertinoButton(
                child: const Text("確定"),
                onPressed: () => Navigator.pop(builderContext),
              )
            ],
          ),
        );
      },
    );
  }

  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  // [修改] 新增顯示共享成員的 Widget
  Widget _buildMemberSection(bool isDarkMode) {
    if (widget.task.members.length <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            const Icon(CupertinoIcons.person_2_fill,
                size: 16, color: CupertinoColors.activeBlue),
            const SizedBox(width: 6),
            Text(
              "共享成員",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: widget.task.members.map((email) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? CupertinoColors.systemGrey.withOpacity(0.3)
                    : CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDarkMode ? Colors.white12 : Colors.black12,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: CupertinoColors.activeBlue,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      email.isNotEmpty ? email[0].toUpperCase() : "?",
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    email,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = CupertinoTheme.of(context).brightness == Brightness.dark;

    String days = _timeLeft.inDays > 0 ? _twoDigits(_timeLeft.inDays) : "00";
    String hours = _twoDigits(_timeLeft.inHours.remainder(24));
    String minutes = _twoDigits(_timeLeft.inMinutes.remainder(60));
    String seconds = _twoDigits(_timeLeft.inSeconds.remainder(60));

    if (_timeLeft.isNegative) {
      days = hours = minutes = seconds = "00";
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("事項詳情"),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Text("儲存"),
          onPressed: () {
            widget.task.title = _titleController.text;
            widget.task.note = _noteController.text;
            widget.task.dueTime = _currentDueTime;
            widget.onUpdate();
            Navigator.pop(context);
          },
        ),
      ),
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? CupertinoColors.darkBackgroundGray
                          : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CupertinoTextField(
                          controller: _titleController,
                          placeholder: "事項名稱",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          decoration: null,
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 15),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeBlue
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                widget.task.category,
                                style: const TextStyle(
                                  color: CupertinoColors.activeBlue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: _showDatePicker,
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.calendar,
                                      size: 18, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(
                                    DateFormat('yyyy/MM/dd HH:mm')
                                        .format(_currentDueTime),
                                    style: const TextStyle(
                                      color: CupertinoColors.activeBlue,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(CupertinoIcons.pencil,
                                      size: 14, color: Colors.grey),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // [修改] 插入共享成員顯示區塊
                        _buildMemberSection(isDarkMode),

                        const SizedBox(height: 25),
                        const Text("距離結束還有",
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _timeLeft.isNegative
                                  ? CupertinoColors.systemRed
                                      .withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildTimeBox(days, "天", isDarkMode),
                              _buildSeparator(isDarkMode),
                              _buildTimeBox(hours, "時", isDarkMode),
                              _buildSeparator(isDarkMode),
                              _buildTimeBox(minutes, "分", isDarkMode),
                              _buildSeparator(isDarkMode),
                              _buildTimeBox(seconds, "秒", isDarkMode,
                                  isRed: _timeLeft.inMinutes < 5 &&
                                      !_timeLeft.isNegative),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("  備註",
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? CupertinoColors.darkBackgroundGray
                          : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CupertinoTextField(
                      controller: _noteController,
                      placeholder: "在這裡輸入心得或細節...",
                      maxLines: null,
                      decoration: null,
                      padding: const EdgeInsets.all(20),
                      style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  child: const Text("刪除此事項",
                      style: TextStyle(
                          color: CupertinoColors.systemRed,
                          fontWeight: FontWeight.bold)),
                  onPressed: () {
                    showCupertinoDialog(
                      context: context,
                      builder: (context) => CupertinoAlertDialog(
                        title: const Text("確認刪除"),
                        content: const Text("刪除後無法復原，確定嗎？"),
                        actions: [
                          CupertinoDialogAction(
                            child: const Text("取消"),
                            onPressed: () => Navigator.pop(context),
                          ),
                          CupertinoDialogAction(
                            isDestructiveAction: true,
                            child: const Text("刪除"),
                            onPressed: () {
                              widget.onDelete();
                              Navigator.pop(context);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBox(String value, String label, bool isDark,
      {bool isRed = false}) {
    Color textColor = isRed
        ? CupertinoColors.systemRed
        : (isDark ? Colors.white : Colors.black87);
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                fontFamily: "Courier",
                color: textColor)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSeparator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(":",
          style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.black26)),
    );
  }
}
