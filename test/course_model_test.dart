// Course 課程模型序列化與邏輯單元測試
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unitrack_app_2/models/course.dart';

void main() {
  group('Course Model 序列化與反序列化測試', () {
    test('Course toFirestore 與 fromMap 往返轉換保持一致', () {
      const originalCourse = Course(
        id: 'course_123',
        name: '作業系統',
        classroom: '工401',
        professor: '李教授',
        weekday: 2,
        startSection: 3,
        endSection: 5,
        credits: 3,
        type: CourseType.required,
        color: Color(0xFF3F51B5),
      );

      final firestoreMap = originalCourse.toFirestore();
      expect(firestoreMap['name'], '作業系統');
      expect(firestoreMap['classroom'], '工401');
      expect(firestoreMap['professor'], '李教授');
      expect(firestoreMap['weekday'], 2);
      expect(firestoreMap['startSection'], 3);
      expect(firestoreMap['endSection'], 5);
      expect(firestoreMap['credits'], 3);
      expect(firestoreMap['type'], 'required');

      final reconstructed = Course.fromMap(firestoreMap, id: 'course_123');
      expect(reconstructed.id, originalCourse.id);
      expect(reconstructed.name, originalCourse.name);
      expect(reconstructed.classroom, originalCourse.classroom);
      expect(reconstructed.professor, originalCourse.professor);
      expect(reconstructed.weekday, originalCourse.weekday);
      expect(reconstructed.startSection, originalCourse.startSection);
      expect(reconstructed.endSection, originalCourse.endSection);
      expect(reconstructed.credits, originalCourse.credits);
      expect(reconstructed.type, originalCourse.type);
      expect(reconstructed.color.toARGB32(), originalCourse.color.toARGB32());
    });

    test('Course 衝堂檢查 (conflictsWith)', () {
      const course = Course(
        id: 'test_1',
        name: '微積分',
        classroom: '理101',
        weekday: 1,
        startSection: 2,
        endSection: 4,
      );

      // 同星期且節次重疊 -> 衝堂
      expect(
        course.conflictsWith(
          targetWeekday: 1,
          targetStartSection: 3,
          targetEndSection: 5,
        ),
        isTrue,
      );

      // 同星期但節次無重疊 -> 不衝堂
      expect(
        course.conflictsWith(
          targetWeekday: 1,
          targetStartSection: 5,
          targetEndSection: 7,
        ),
        isFalse,
      );

      // 不同星期 -> 不衝堂
      expect(
        course.conflictsWith(
          targetWeekday: 2,
          targetStartSection: 2,
          targetEndSection: 4,
        ),
        isFalse,
      );
    });
  });
}
