import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:angostura_digital/services/notificaciones_service.dart';
import 'package:angostura_digital/utils/auth_plataforma.dart';
import 'dart:async';

class AuthService {
  static const _serverClientId =
      '984485862980-ng6j5pepgafcdeu4spkuk5pcj25ioln7.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool _googleSignInReady = false;
  static String? _phoneLinkVerificationId;

  /// Solo Android: inicializa Google Sign-In.
  static Future<void> ensureGoogleSignInInitialized() async {
    if (!AuthPlataforma.usaGoogle) return;
    if (_googleSignInReady) return;
    await GoogleSignIn.instance.initialize(serverClientId: _serverClientId);
    _googleSignInReady = true;
  }

  // --- GOOGLE (Android) ---
  Future<UserCredential?> signInWithGoogle() async {
    try {
      await ensureGoogleSignInInitialized();

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        debugPrint('Google Sign-In no disponible en esta plataforma.');
        return null;
      }

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      await _guardarUsuarioEnBD(
        userCredential.user,
        proveedor: 'google',
        nombreOverride: googleUser.displayName,
      );
      return userCredential;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      debugPrint('Error Google: $e');
      rethrow;
    } catch (e) {
      debugPrint('Error Google: $e');
      rethrow;
    }
  }

  // --- APPLE (iOS / macOS) ---
  Future<UserCredential?> signInWithApple() async {
    try {
      final disponible = await SignInWithApple.isAvailable();
      if (!disponible) {
        debugPrint('Sign in with Apple no disponible.');
        return null;
      }

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(oauthCredential);

      String? nombreApple;
      if (appleCredential.givenName != null) {
        nombreApple =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (nombreApple.isNotEmpty) {
          await userCredential.user?.updateDisplayName(nombreApple);
        }
      }

      await _guardarUsuarioEnBD(
        userCredential.user,
        proveedor: 'apple',
        nombreOverride: nombreApple,
      );
      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      debugPrint('Error Apple: $e');
      rethrow;
    } catch (e) {
      debugPrint('Error Apple: $e');
      rethrow;
    }
  }

  /// Inicio de sesión según plataforma.
  Future<UserCredential?> signInSegunPlataforma() async {
    if (AuthPlataforma.usaApple) return signInWithApple();
    return signInWithGoogle();
  }

  // --- VINCULAR / CAMBIAR TELÉFONO (perfil) ---
  Future<bool> enviarCodigoVincularTelefono(String phoneNumber) async {
    if (_auth.currentUser == null) return false;
    final completer = Completer<bool>();

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {
          if (!completer.isCompleted) completer.complete(false);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('SMS vincular: ${e.message}');
          if (!completer.isCompleted) completer.complete(false);
        },
        codeSent: (String verificationId, int? resendToken) {
          _phoneLinkVerificationId = verificationId;
          if (!completer.isCompleted) completer.complete(true);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _phoneLinkVerificationId = verificationId;
        },
      );
      return completer.future.timeout(
        const Duration(seconds: 70),
        onTimeout: () => false,
      );
    } catch (e) {
      debugPrint('Error enviando SMS vincular: $e');
      return false;
    }
  }

  /// Vincula o actualiza el teléfono. Retorna null si OK, o mensaje de error.
  Future<String?> confirmarVincularTelefono(String smsCode) async {
    final user = _auth.currentUser;
    if (user == null) return 'Sesión expirada. Vuelve a entrar.';
    if (_phoneLinkVerificationId == null) {
      return 'Primero envía el SMS al nuevo número.';
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _phoneLinkVerificationId!,
        smsCode: smsCode,
      );

      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        await user.updatePhoneNumber(credential);
      } else {
        await user.linkWithCredential(credential);
      }

      await user.reload();
      final actualizado = _auth.currentUser;
      final tel = actualizado?.phoneNumber ?? '';

      await _firestore.collection('usuarios').doc(user.uid).set(
        {'telefono': tel},
        SetOptions(merge: true),
      );

      _phoneLinkVerificationId = null;
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'credential-already-in-use':
          return 'Ese número ya está en otra cuenta.';
        case 'invalid-verification-code':
          return 'Código incorrecto.';
        case 'session-expired':
          return 'El código expiró. Envía el SMS de nuevo.';
        case 'requires-recent-login':
          return 'Por seguridad, cierra sesión y vuelve a entrar.';
        default:
          return e.message ?? 'No se pudo confirmar el teléfono.';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String?> actualizarNombre(String nuevoNombre) async {
    final user = _auth.currentUser;
    if (user == null) return 'Sesión expirada.';
    final nombre = nuevoNombre.trim();
    if (nombre.isEmpty) return 'Escribe un nombre.';

    try {
      await user.updateDisplayName(nombre);
      await _firestore.collection('usuarios').doc(user.uid).set(
        {'nombre': nombre},
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      return 'No se pudo guardar el nombre.';
    }
  }

  Future<void> _guardarUsuarioEnBD(
    User? user, {
    String? proveedor,
    String? nombreOverride,
  }) async {
    if (user == null) return;

    final docRef = _firestore.collection('usuarios').doc(user.uid);
    final docSnap = await docRef.get();
    final existe = docSnap.exists;
    final dataActual = docSnap.data() ?? {};

    final nombre = (nombreOverride?.isNotEmpty == true)
        ? nombreOverride
        : (user.displayName?.isNotEmpty == true)
            ? user.displayName
            : (dataActual['nombre']?.toString().isNotEmpty == true)
                ? dataActual['nombre']
                : 'Usuario';

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? dataActual['email'] ?? '',
      'ultimo_acceso': FieldValue.serverTimestamp(),
    };

    if (proveedor != null) payload['proveedor'] = proveedor;
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      payload['telefono'] = user.phoneNumber;
    }

    if (!existe) {
      payload['nombre'] = nombre;
      payload['telefono'] = user.phoneNumber ?? '';
      payload['fecha_registro'] = FieldValue.serverTimestamp();
      payload['rol'] = 'cliente';
      await docRef.set(payload);
      debugPrint('Nuevo usuario en Firestore: ${user.uid}');
    } else {
      if (dataActual['nombre'] == null ||
          dataActual['nombre'].toString().trim().isEmpty) {
        payload['nombre'] = nombre;
      }
      await docRef.set(payload, SetOptions(merge: true));
    }
  }

  Future<void> signOut() async {
    await NotificacionesService.cerrarSesion();
    await _auth.signOut();
    if (_googleSignInReady) {
      await GoogleSignIn.instance.signOut();
    }
  }
}
