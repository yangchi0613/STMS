import 'dart:async'; // [新增] 用於計時器
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';

class TaskDetailPage extends StatefulWidget {
  final Task task;
  final VoidCallback onDelete; // 這裡我們當作「刪除」或「完成」都呼叫這個

  const TaskDetailPage({
    super.key, 
    required this.task, 
    required this.onDelete
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
  bool _hasAlerted = false; // 防止彈窗重複跳出

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _noteController = TextEditingController(text: widget.task.note);
    _currentDueTime = widget.task.dueTime;
    
    // 初始化倒數時間
    _updateTimeLeft();
    
    // 啟動計時器，每秒更新倒數
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _updateTimeLeft();
        });
        _checkIfTimeUp();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // 計算剩餘時間
  void _updateTimeLeft() {
    final now = DateTime.now();
    _timeLeft = _currentDueTime.difference(now);
  }

  // 檢查是否時間到
  void _checkIfTimeUp() {
    // 如果時間到了(變成負數)，且還沒彈過窗
    if (_timeLeft.isNegative && !_hasAlerted) {
      _hasAlerted = true; // 標記已彈窗
      _showTimeUpDialog();
    }
  }

  // 顯示時間選擇器
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
                      widget.task.dueTime = newDateTime; // 更新原始資料
                      _hasAlerted = false; // 重設彈窗狀態，因為時間延長了
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

  // 時間到的彈窗
  void _showTimeUpDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("⏰ 時間到囉！"),
        content: Text("事項「${widget.task.title}」的時間已經到了。\n接下來要怎麼做？"),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("繼續做 (延時)"),
            onPressed: () {
              Navigator.pop(context);
              _showDatePicker(); // 直接打開時間選擇器
            },
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text("已完成"),
            onPressed: () {
              widget.onDelete(); // 呼叫刪除/完成邏輯
              Navigator.pop(context); // 關閉 Dialog
              Navigator.pop(context); // 退出詳情頁回到首頁
            },
          ),
        ],
      ),
    );
  }

  // 格式化數字 (補0)
  String _twoDigits(int n) {
    if (n >= 10) return "$n";
    return "0$n";
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = CupertinoTheme.of(context).brightness == Brightness.dark;
    
    // 計算倒數顯示字串
    String days = _timeLeft.inDays > 0 ? _twoDigits(_timeLeft.inDays) : "00";
    String hours = _twoDigits(_timeLeft.inHours.remainder(24));
    String minutes = _twoDigits(_timeLeft.inMinutes.remainder(60));
    String seconds = _twoDigits(_timeLeft.inSeconds.remainder(60));
    
    // 如果過期，顯示紅色00
    if (_timeLeft.isNegative) {
      days = hours = minutes = seconds = "00";
    }

    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text("事項詳情")),
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
                        // [修改] 可編輯標題
                        CupertinoTextField(
                          controller: _titleController,
                          placeholder: "事項名稱",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          decoration: null, // 去除邊框看起來像純文字
                          padding: EdgeInsets.zero,
                          onChanged: (val) {
                            widget.task.title = val; // 即時存回資料
                          },
                        ),
                        const SizedBox(height: 15),
                        
                        // [修改] 類別 + 可點擊修改的時間
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
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
                            // 點擊這裡可以修改時間
                            GestureDetector(
                              onTap: _showDatePicker,
                              child: Row(
                                children: [
                                  const Icon(CupertinoIcons.calendar, size: 18, color: Colors.grey),
                                  const SizedBox(width: 5),
                                  Text(
                                    DateFormat('yyyy/MM/dd HH:mm').format(_currentDueTime),
                                    style: const TextStyle(
                                      color: CupertinoColors.activeBlue, // 改成藍色提示可點擊
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
                        // [新增] 倒數計時面板
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
                  
                  // 備註區域
                  const Text(
                    "  備註",
                    style: TextStyle(
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                      onChanged: (val) => widget.task.note = val,
                    ),
                  ),
                ],
              ),
            ),
            
            // 刪除按鈕
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                child: CupertinoButton(
                  color: CupertinoColors.systemRed.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  child: const Text(
                    "刪除此事項",
                    style: TextStyle(
                      color: CupertinoColors.systemRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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

  // 小組件：時間數字方塊
  Widget _buildTimeBox(String value, String label, bool isDark, {bool isRed = false}) {
    Color textColor = isRed 
        ? CupertinoColors.systemRed 
        : (isDark ? Colors.white : Colors.black87);
        
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            fontFamily: "Courier", // 等寬字體比較好看
            color: textColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }

  // 小組件：冒號分隔符
  Widget _buildSeparator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Text(
        ":",
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white54 : Colors.black26,
        ),
      ),
    );
  }
}