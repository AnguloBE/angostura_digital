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
  static bool _ingresarAlVerificar = false;
  static bool ingresoCompletadoAlEnviar = false;
  static int _suprimirInvitado = 0;
  static bool _entrandoInvitado = false;

  /// Sin cuenta, o sesión anónima para mirar negocios sin registrarse.
  static bool get esInvitado {
    final user = FirebaseAuth.instance.currentUser;
    return user == null || user.isAnonymous;
  }

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

  /// Entra sin cuenta para poder ver negocios. Si ya hay sesión, no hace nada.
  Future<void> asegurarInvitado() async {
    if (_suprimirInvitado > 0) return;
    if (_auth.currentUser != null) return;
    if (_entrandoInvitado) return;
    _entrandoInvitado = true;
    try {
      if (_auth.currentUser != null) return;
      await _auth.signInAnonymously();
      debugPrint('Sesión de invitado lista');
    } catch (e) {
      debugPrint('No se pudo entrar como invitado: $e');
    } finally {
      _entrandoInvitado = false;
    }
  }

  // --- TELÉFONO: entrar, registrarse o cambiar número ---

  /// Envía el SMS. Null si el código va en camino (o la sesión ya quedó lista).
  Future<String?> enviarCodigoTelefono(
    String phoneNumber, {
    bool ingresar = false,
  }) async {
    final completer = Completer<String?>();
    ingresoCompletadoAlEnviar = false;
    _ingresarAlVerificar = ingresar;

    try {
      if (kIsWeb) {
        try {
          await _auth.initializeRecaptchaConfig().timeout(
            const Duration(seconds: 20),
          );
        } catch (e) {
          debugPrint('reCAPTCHA: $e');
        }
      }
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (PhoneAuthCredential credential) async {
          if (completer.isCompleted) return;
          final error = await _aplicarCredencialTelefono(
            credential,
            ingresar: _ingresarAlVerificar,
          );
          ingresoCompletadoAlEnviar = error == null;
          if (!completer.isCompleted) completer.complete(error);
        },
        verificationFailed: (FirebaseAuthException e) {
          debugPrint('SMS: ${e.code} ${e.message}');
          if (!completer.isCompleted) completer.complete(_mensajeAuth(e));
        },
        codeSent: (String verificationId, int? resendToken) {
          _phoneLinkVerificationId = verificationId;
          if (!completer.isCompleted) completer.complete(null);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _phoneLinkVerificationId = verificationId;
        },
      );
      return completer.future.timeout(
        const Duration(seconds: 90),
        onTimeout: () => 'El SMS tardó demasiado. Intenta de nuevo.',
      );
    } catch (e) {
      debugPrint('Error enviando SMS: $e');
      return 'No se pudo enviar el SMS. Revisa el número e intenta de nuevo.';
    }
  }

  /// Confirma el código SMS.
  /// Con [ingresar], crea la cuenta o entra a la que ya tenga ese número.
  Future<String?> confirmarCodigoTelefono(
    String smsCode, {
    bool ingresar = false,
  }) async {
    if (_phoneLinkVerificationId == null) {
      return 'Primero envía el SMS.';
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _phoneLinkVerificationId!,
      smsCode: smsCode,
    );
    return _aplicarCredencialTelefono(credential, ingresar: ingresar);
  }

  Future<String?> _aplicarCredencialTelefono(
    PhoneAuthCredential credential, {
    required bool ingresar,
  }) async {
    _suprimirInvitado++;
    try {
      final user = _auth.currentUser;
      final comoInvitado = user == null || user.isAnonymous;

      if (ingresar || comoInvitado) {
        if (user != null && user.isAnonymous) {
          try {
            final linked = await user.linkWithCredential(credential);
            await _guardarUsuarioEnBD(linked.user, proveedor: 'telefono');
            _phoneLinkVerificationId = null;
            return null;
          } on FirebaseAuthException catch (e) {
            if (e.code == 'credential-already-in-use' ||
                e.code == 'email-already-in-use') {
              return _entrarConCredencialExistente(e.credential ?? credential);
            }
            if (e.code != 'provider-already-linked') {
              return _mensajeAuth(e);
            }
          }
        }

        final signed = await _auth.signInWithCredential(credential);
        await _guardarUsuarioEnBD(signed.user, proveedor: 'telefono');
        _phoneLinkVerificationId = null;
        return null;
      }

      if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
        await user.updatePhoneNumber(credential);
      } else {
        await user.linkWithCredential(credential);
      }

      await user.reload();
      final tel = _auth.currentUser?.phoneNumber ?? '';
      await _firestore.collection('usuarios').doc(user.uid).set(
        {'telefono': tel},
        SetOptions(merge: true),
      );
      _phoneLinkVerificationId = null;
      return null;
    } on FirebaseAuthException catch (e) {
      if (ingresar &&
          (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use')) {
        final alternativa = e.credential;
        if (alternativa != null) {
          return _entrarConCredencialExistente(alternativa);
        }
      }
      return _mensajeAuth(e);
    } catch (e) {
      return 'No se pudo confirmar el teléfono.';
    } finally {
      _suprimirInvitado--;
      if (_auth.currentUser == null) {
        await asegurarInvitado();
      }
    }
  }

  Future<String?> _entrarConCredencialExistente(AuthCredential credential) async {
    try {
      final signed = await _auth.signInWithCredential(credential);
      await _guardarUsuarioEnBD(signed.user, proveedor: 'telefono');
      _phoneLinkVerificationId = null;
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeAuth(e);
    }
  }

  String _mensajeAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-phone-number':
        return 'El número no es válido. Revisa la lada y los 10 dígitos.';
      case 'too-many-requests':
        return 'Firebase pausó los SMS de esta red y de este número por varios intentos fallidos. Espera cerca de una hora y prueba una sola vez. No hay forma de quitar el bloqueo antes.';
      case 'invalid-verification-code':
        return 'Código incorrecto.';
      case 'session-expired':
      case 'code-expired':
        return 'El código expiró. Envía el SMS de nuevo.';
      case 'credential-already-in-use':
        return 'Ese número ya está en otra cuenta.';
      case 'operation-not-allowed':
      case 'admin-restricted-operation':
        return 'El ingreso con teléfono no está activado en Firebase.';
      case 'captcha-check-failed':
      case 'missing-client-identifier':
      case 'invalid-app-credential':
        return 'No se pudo comprobar el navegador. Recarga la página e intenta de nuevo.';
      case 'quota-exceeded':
        return 'Se alcanzó el límite de SMS. Intenta más tarde.';
      case 'network-request-failed':
        return 'Sin conexión. Revisa tu internet.';
      case 'requires-recent-login':
        return 'Por seguridad, cierra sesión y vuelve a entrar.';
      default:
        final detalle = e.message?.trim();
        if (detalle != null && detalle.isNotEmpty) return detalle;
        return 'No se pudo completar. Intenta de nuevo.';
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
        {
          'nombre': nombre,
          'nombre_elegido': true,
        },
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
    await asegurarInvitado();
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
