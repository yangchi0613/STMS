import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;
  final VoidCallback onDelete;
  final VoidCallback onUpdate; // [新增] 更新回呼函式

  const TaskDetailPage({
    super.key, 
    required this.task, 
    required this.onDelete,
    required this.onUpdate, // [新增]
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

  // [新增] 當頁面關閉時，自動儲存修改
  @override
  void deactivate() {
    // 檢查是否有變更
    if (widget.task.title != _titleController.text || 
        widget.task.note != _noteController.text ||
        widget.task.dueTime != _currentDueTime) {
          
      widget.task.title = _titleController.text;
      widget.task.note = _noteController.text;
      widget.task.dueTime = _currentDueTime;
      
      // 呼叫更新
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

  void _checkIfTimeUp() {
    if (_timeLeft.isNegative && !_hasAlerted) {
      _hasAlerted = true; 
      // 這裡暫時不彈窗，避免編輯時一直被打斷，只在列表頁彈窗就好
    }
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

  // 格式化數字
  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  // 為了簡化，UI 部分保持大同小異，主要是邏輯增加
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
        // [新增] 儲存按鈕，讓使用者明確知道可以存檔 (雖然我們有做自動存檔)
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
                                horizontal: 10, vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeBlue.withOpacity(0.1),
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
                                  const Icon(CupertinoIcons.calendar, size: 18, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(
                                    DateFormat('yyyy/MM/dd HH:mm').format(_currentDueTime),
                                    style: const TextStyle(
                                      color: CupertinoColors.activeBlue, 
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 5),
                                  const Icon(CupertinoIcons.pencil, size: 14, color: Colors.grey),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 25),
                        const Text("距離結束還有", style: TextStyle(color: Colors.grey, fontSize: 12)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: _timeLeft.isNegative 
                                  ? CupertinoColors.systemRed.withOpacity(0.3) 
                                  : Colors.transparent
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
                              _buildTimeBox(seconds, "秒", isDarkMode, isRed: _timeLeft.inMinutes < 5 && !_timeLeft.isNegative),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text("  備註", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: isDarkMode ? CupertinoColors.darkBackgroundGray : CupertinoColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: CupertinoTextField(
                      controller: _noteController,
                      placeholder: "在這裡輸入心得或細節...",
                      maxLines: null,
                      decoration: null,
                      padding: const EdgeInsets.all(20),
                      style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
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
                  color: CupertinoColors.systemRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  child: const Text("刪除此事項", style: TextStyle(color: CupertinoColors.systemRed, fontWeight: FontWeight.bold)),
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

  Widget _buildTimeBox(String value, String label, bool isDark, {bool isRed = false}) {
    Color textColor = isRed 
        ? CupertinoColors.systemRed 
        : (isDark ? Colors.white : Colors.black87);
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, fontFamily: "Courier", color: textColor)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSeparator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(":", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white54 : Colors.black26)),
    );
  }
}