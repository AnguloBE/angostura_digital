import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '984485862980-ng6j5pepgafcdeu4spkuk5pcj25ioln7.apps.googleusercontent.com',
  );

  // Guardamos el resultado de la confirmación
  static ConfirmationResult? _confirmationResult;

  // --- GOOGLE ---
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Error Google: $e");
      return null;
    }
  }

  // --- TELÉFONO (SMS) ---
  Future<bool> sendCode(String phoneNumber, RecaptchaVerifier verifier) async {
    try {
      _confirmationResult = await _auth.signInWithPhoneNumber(
        phoneNumber, 
        verifier
      );
      return true;
    } catch (e) {
      print("Error enviando SMS: $e");
      return false;
    }
  }

  Future<UserCredential?> verifyCode(String smsCode) async {
    try {
      if (_confirmationResult != null) {
        return await _confirmationResult!.confirm(smsCode);
      }
      return null;
    } catch (e) {
      print("Error verificando código: $e");
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}