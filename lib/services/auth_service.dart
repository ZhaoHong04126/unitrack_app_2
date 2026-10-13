// Firebase Authentication 服務層封裝
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// 自訂驗證例外錯誤物件，提供格式化的繁體中文訊息
class AuthException implements Exception {
  final String message;
  final String? code;

  const AuthException(this.message, [this.code]);

  @override
  String toString() => message;
}

/// Firebase 身分驗證核心服務
class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  /// 監聽身分驗證狀態變更的 Stream
  Stream<User?> get authStateChanges {
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// 取得當前已登入的使用者資訊（未登入則為 null）
  User? get currentUser {
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  /// 使用電子信箱與密碼進行註冊
  /// 可額外傳入 [displayName] 於 Firebase Auth 及 Firestore 儲存個人資訊
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      final trimmedName = displayName?.trim();

      if (user != null && trimmedName != null && trimmedName.isNotEmpty) {
        await user.updateDisplayName(trimmedName);
      }

      // 儲存額外的使用者資訊至 Cloud Firestore（若安全規則或連線允許）
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'displayName': trimmedName ?? '',
            'createdAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          debugPrint('✅ 成功儲存使用者資料至 Cloud Firestore: ${user.uid}');
        } catch (e) {
          debugPrint('⚠️ [Firestore 儲存失敗] 請檢查 Firebase Console 是否已建立 Firestore Database 或安全規則 (Security Rules) 是否允許寫入: $e');
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e), e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('註冊發生未預期的錯誤，請稍後再試。($e)');
    }
  }

  /// 使用電子信箱與密碼進行登入
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // 更新最後登入時間
      final user = credential.user;
      if (user != null) {
        try {
          await _firestore.collection('users').doc(user.uid).set({
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (_) {}
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e), e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('登入發生未預期的錯誤，請稍後再試。($e)');
    }
  }

  /// 發送忘記密碼重設信件
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_handleAuthException(e), e.code);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('重設密碼發送失敗，請稍後再試。($e)');
    }
  }

  /// 登出帳號
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('登出程序失敗，請稍後再試。($e)');
    }
  }

  /// 將常見的 Firebase Auth 錯誤代碼轉換為使用者易讀的繁體中文提示
  static String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '找不到此電子信箱註冊的帳號，請確認後再試。';
      case 'wrong-password':
        return '密碼輸入錯誤，請重新確認。';
      case 'invalid-credential':
        return '電子信箱或密碼錯誤，請重新確認。';
      case 'email-already-in-use':
        return '此電子信箱已被註冊，請直接登入或使用其他信箱。';
      case 'weak-password':
        return '密碼強度不足，請設定至少 6 個字元以上的密碼。';
      case 'invalid-email':
        return '電子信箱格式不正確，請輸入有效的電子信箱。';
      case 'user-disabled':
        return '此帳號已被停用，請聯絡系統管理員。';
      case 'too-many-requests':
        return '嘗試次數過多，系統已暫時限制登入，請稍後再試。';
      case 'operation-not-allowed':
        return '系統尚未啟用此登入方式，請聯絡管理員確認 Firebase 設定。';
      case 'network-request-failed':
        return '網路連線失敗，請檢查網路連線狀態後重試。';
      case 'channel-error':
        return '請完整填寫電子信箱與密碼。';
      case 'requires-recent-login':
        return '此操作具機敏性，請重新登入後再試。';
      default:
        return e.message ?? '驗證程序發生錯誤，請稍後再試。（錯誤代碼：${e.code}）';
    }
  }
}
