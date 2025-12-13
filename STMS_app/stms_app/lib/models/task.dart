// --- 資料模型 ---
class Task {
  String id;
  String title;
  String category;
  String priority;
  String status;
  DateTime dueTime;
  String note;

  Task({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.dueTime,
    this.note = "",
  });
}
