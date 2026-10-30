import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:angostura_digital/services/notificaciones_service.dart';
import 'package:angostura_digital/utils/auth_plataforma.dart';
import 'package:angostura_digital/utils/red_timeout.dart';
import 'package:angostura_digital/utils/app_check_config.dart';
import 'package:angostura_digital/utils/auth_red_precalentar.dart';
import 'dart:async';

typedef ProgresoAuthCallback = void Function(String mensaje);

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
    try {
      await GoogleSignIn.instance
          .initialize(serverClientId: _serverClientId)
          .timeout(const Duration(seconds: 20));
      _googleSignInReady = true;
    } catch (e) {
      debugPrint('Google Sign-In init: $e');
    }
  }

  // --- GOOGLE (Android) ---
  Future<UserCredential?> signInWithGoogle({ProgresoAuthCallback? onProgreso}) async {
    try {
      onProgreso?.call('Preparando...');
      await ensureGoogleSignInInitialized();

      precalentarAppCheckEnSegundoPlano();
      final precalentamiento = Future.wait([
        asegurarAppCheckParaAuth(
          onProgreso: onProgreso,
          esperaMaxima: const Duration(seconds: 45),
        ),
        precalentarRedFirebase(),
      ]);

      if (!GoogleSignIn.instance.supportsAuthenticate()) {
        debugPrint('Google Sign-In no disponible en esta plataforma.');
        return null;
      }

      onProgreso?.call('Abriendo Google...');
      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;
      final idToken = googleAuth.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw Exception('Google no devolvió un token válido. Intenta de nuevo.');
      }

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: idToken,
      );

      debugPrint('Google OK, conectando con Firebase Auth...');
      await precalentamiento;
      await asegurarAppCheckParaAuth(
        onProgreso: onProgreso,
        esperaMaxima: const Duration(seconds: 30),
      );

      onProgreso?.call('Validando con Firebase...');
      final signInFuture = _auth.signInWithCredential(credential);
      final userCredential = await esperarMismaPeticion(
        signInFuture,
        tramos: 6,
        duracionTramo: const Duration(seconds: 30),
        onProgreso: (tramo, total) {
          onProgreso?.call('Validando con Firebase ($tramo/$total)...');
        },
      );
      debugPrint('Firebase Auth OK');
      enSegundoPlano(_guardarUsuarioEnBD(
        userCredential.user,
        proveedor: 'google',
        nombreOverride: googleUser.displayName,
      ));
      return userCredential;
    } on TimeoutException catch (e) {
      debugPrint('Timeout login: $e');
      rethrow;
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
  Future<UserCredential?> signInWithApple({ProgresoAuthCallback? onProgreso}) async {
    try {
      onProgreso?.call('Preparando...');
      precalentarAppCheckEnSegundoPlano();
      await Future.wait([
        asegurarAppCheckParaAuth(
          onProgreso: onProgreso,
          esperaMaxima: const Duration(seconds: 45),
        ),
        precalentarRedFirebase(),
      ]);

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

      await asegurarAppCheckParaAuth(
        onProgreso: onProgreso,
        esperaMaxima: const Duration(seconds: 30),
      );

      onProgreso?.call('Validando con Firebase...');
      final signInFuture = _auth.signInWithCredential(oauthCredential);
      final userCredential = await esperarMismaPeticion(
        signInFuture,
        tramos: 6,
        duracionTramo: const Duration(seconds: 30),
        onProgreso: (tramo, total) {
          onProgreso?.call('Validando con Firebase ($tramo/$total)...');
        },
      );

      String? nombreApple;
      if (appleCredential.givenName != null) {
        nombreApple =
            '${appleCredential.givenName ?? ''} ${appleCredential.familyName ?? ''}'
                .trim();
        if (nombreApple.isNotEmpty) {
          await userCredential.user?.updateDisplayName(nombreApple);
        }
      }

      enSegundoPlano(_guardarUsuarioEnBD(
        userCredential.user,
        proveedor: 'apple',
        nombreOverride: nombreApple,
      ));
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
  Future<UserCredential?> signInSegunPlataforma({ProgresoAuthCallback? onProgreso}) async {
    if (AuthPlataforma.usaApple) return signInWithApple(onProgreso: onProgreso);
    return signInWithGoogle(onProgreso: onProgreso);
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

    final nombre = (nombreOverride?.isNotEmpty == true)
        ? nombreOverride!
        : (user.displayName?.isNotEmpty == true)
            ? user.displayName!
            : 'Usuario';

    final payload = <String, dynamic>{
      'uid': user.uid,
      'email': user.email ?? '',
      'ultimo_acceso': FieldValue.serverTimestamp(),
    };

    if (proveedor != null) payload['proveedor'] = proveedor;
    if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      payload['telefono'] = user.phoneNumber;
    }
    if (nombreOverride?.isNotEmpty == true || user.displayName?.isNotEmpty == true) {
      payload['nombre'] = nombre;
    }

    try {
      await docRef
          .set(payload, SetOptions(merge: true))
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      debugPrint('Perfil en caché; se sincronizará después: $e');
    }

    try {
      await _completarRegistroUsuario(docRef, user, nombre)
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  Future<void> _completarRegistroUsuario(
    DocumentReference<Map<String, dynamic>> docRef,
    User user,
    String nombre,
  ) async {
    final docSnap = await docRef.get();
    if (!docSnap.exists) {
      await docRef.set({
        'nombre': nombre,
        'telefono': user.phoneNumber ?? '',
        'fecha_registro': FieldValue.serverTimestamp(),
        'rol': 'cliente',
      }, SetOptions(merge: true));
      debugPrint('Nuevo usuario en Firestore: ${user.uid}');
      return;
    }

    final dataActual = docSnap.data() ?? {};
    final faltantes = <String, dynamic>{};
    if (dataActual['nombre'] == null ||
        dataActual['nombre'].toString().trim().isEmpty) {
      faltantes['nombre'] = nombre;
    }
    if (dataActual['rol'] == null) {
      faltantes['rol'] = 'cliente';
    }
    if (dataActual['fecha_registro'] == null) {
      faltantes['fecha_registro'] = FieldValue.serverTimestamp();
    }
    if (faltantes.isNotEmpty) {
      await docRef.set(faltantes, SetOptions(merge: true));
    }
  }

  Future<void> signOut() async {
    _phoneLinkVerificationId = null;
    await _auth.signOut();
    enSegundoPlano(_limpiarSesionEnSegundoPlano());
  }

  Future<void> _limpiarSesionEnSegundoPlano() async {
    try {
      await NotificacionesService.cerrarSesion()
          .timeout(const Duration(seconds: 6));
    } catch (_) {}
    if (_googleSignInReady) {
      try {
        await GoogleSignIn.instance.signOut().timeout(const Duration(seconds: 6));
      } catch (_) {}
    }
  }
}
