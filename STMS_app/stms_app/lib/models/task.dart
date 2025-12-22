import 'package:cloud_firestore/cloud_firestore.dart';

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

  // [新增] 1. 把 Firebase 的資料轉成我們的 Task 物件 (讀取用)
  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id, // 使用 Firebase 產生的亂碼 ID
      title: data['title'] ?? '',
      category: data['category'] ?? '未分類',
      priority: data['priority'] ?? 'Medium',
      status: data['status'] ?? 'Pending',
      // Firebase 的時間是 Timestamp 格式，要轉回 DateTime
      dueTime: (data['dueTime'] as Timestamp).toDate(),
      note: data['note'] ?? '',
    );
  }

  // [新增] 2. 把 Task 物件轉成 Firebase 看得懂的格式 (存檔用)
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'priority': priority,
      'status': status,
      'dueTime': Timestamp.fromDate(dueTime), // 轉成 Timestamp
      'note': note,
    };
  }
}
