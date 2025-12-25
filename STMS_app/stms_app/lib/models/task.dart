import 'package:cloud_firestore/cloud_firestore.dart';

class Task {
  String id;
  String title;
  String category;
  String priority;
  String status;
  DateTime dueTime;
  String note;
  String recurrence;
  List<String> members; // [修改] 儲存所有共享成員的 Email

  Task({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    required this.status,
    required this.dueTime,
    this.note = "",
    this.recurrence = "不重複",
    required this.members, // [修改]
  });

  factory Task.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Task(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? '未分類',
      priority: data['priority'] ?? 'Medium',
      status: data['status'] ?? 'Pending',
      dueTime: (data['dueTime'] as Timestamp).toDate(),
      note: data['note'] ?? '',
      recurrence: data['recurrence'] ?? '不重複',
      // [修改] 安全地轉換 List<dynamic> 為 List<String>
      members: List<String>.from(data['members'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      'priority': priority,
      'status': status,
      'dueTime': Timestamp.fromDate(dueTime),
      'note': note,
      'recurrence': recurrence,
      'members': members, // [修改]
    };
  }
}
