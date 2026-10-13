// 雲端課表服務層（串接 Cloud Firestore: users/{uid}/courses）
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/course.dart';

class CourseService {
  static final CourseService _instance = CourseService._internal();
  factory CourseService() => _instance;
  CourseService._internal();

  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  /// 取得當前登入使用者的 UID（若未登入則為 null）
  String? get currentUserId {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  /// 取得當前使用者的 courses 集合參照（路徑：users/{uid}/courses）
  CollectionReference<Course>? get _coursesRef {
    final uid = currentUserId;
    if (uid == null) return null;
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('courses')
        .withConverter<Course>(
          fromFirestore: Course.fromFirestore,
          toFirestore: (course, _) => course.toFirestore(),
        );
  }

  /// 即時監聽使用者的課表快照串流（即時同步）
  Stream<List<Course>> getCoursesStream() {
    final ref = _coursesRef;
    if (ref == null) {
      debugPrint('⚠️ [CourseService] 使用者尚未登入，回傳空課表串流');
      return Stream.value(const <Course>[]);
    }

    return ref.snapshots().map((snapshot) {
      final courses = snapshot.docs.map((doc) => doc.data()).toList();
      // 依星期與開始節次依序排列
      courses.sort((a, b) {
        if (a.weekday != b.weekday) {
          return a.weekday.compareTo(b.weekday);
        }
        return a.startSection.compareTo(b.startSection);
      });
      return courses;
    });
  }

  /// 單次非同步讀取使用者課表
  Future<List<Course>> getCoursesOnce() async {
    final ref = _coursesRef;
    if (ref == null) return const [];

    try {
      final snapshot = await ref.get();
      final courses = snapshot.docs.map((doc) => doc.data()).toList();
      courses.sort((a, b) {
        if (a.weekday != b.weekday) {
          return a.weekday.compareTo(b.weekday);
        }
        return a.startSection.compareTo(b.startSection);
      });
      return courses;
    } catch (e) {
      debugPrint('⚠️ [CourseService] 讀取課表失敗: $e');
      rethrow;
    }
  }

  /// 新增或儲存課程至雲端 Firestore
  /// 若 [course.id] 為空，會自動產生文件 ID 並儲存
  Future<String> saveCourse(Course course) async {
    final ref = _coursesRef;
    if (ref == null) {
      throw Exception('使用者尚未登入，無法同步儲存至雲端。');
    }

    try {
      if (course.id.trim().isEmpty) {
        final newDoc = ref.doc();
        final finalCourse = course.copyWith(id: newDoc.id);
        await newDoc.set(finalCourse);
        debugPrint('✅ [CourseService] 成功新增雲端課程: ${newDoc.id} (${course.name})');
        return newDoc.id;
      } else {
        await ref.doc(course.id).set(course);
        debugPrint('✅ [CourseService] 成功更新雲端課程: ${course.id} (${course.name})');
        return course.id;
      }
    } catch (e) {
      debugPrint('❌ [CourseService] 儲存課程失敗: $e');
      rethrow;
    }
  }

  /// 依據文件 ID 刪除課程
  Future<void> deleteCourse(String courseId) async {
    final ref = _coursesRef;
    if (ref == null) {
      throw Exception('使用者尚未登入，無法刪除雲端課程。');
    }

    try {
      await ref.doc(courseId).delete();
      debugPrint('✅ [CourseService] 成功刪除雲端課程: $courseId');
    } catch (e) {
      debugPrint('❌ [CourseService] 刪除課程失敗: $e');
      rethrow;
    }
  }

  /// 清空目前使用者的所有雲端課程
  Future<void> clearAllCourses() async {
    final ref = _coursesRef;
    if (ref == null) return;

    try {
      final snapshot = await ref.get();
      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      debugPrint('✅ [CourseService] 成功清空所有雲端課程 (共 ${snapshot.docs.length} 門)');
    } catch (e) {
      debugPrint('❌ [CourseService] 清空課表失敗: $e');
      rethrow;
    }
  }
}
