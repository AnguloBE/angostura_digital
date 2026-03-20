import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Agregamos Firestore

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Instancia de la BD
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '984485862980-ng6j5pepgafcdeu4spkuk5pcj25ioln7.apps.googleusercontent.com',
  );

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
      
      UserCredential userCredential = await _auth.signInWithCredential(credential);
      await _guardarUsuarioEnBD(userCredential.user); // Guardamos al entrar con Google
      return userCredential;
      
    } catch (e) {
      print("Error Google: $e");
      return null;
    }
  }

  // --- TELÉFONO (SMS) ---
  Future<bool> sendCode(String phoneNumber, RecaptchaVerifier verifier) async {
    try {
      _confirmationResult = await _auth.signInWithPhoneNumber(phoneNumber, verifier);
      return true;
    } catch (e) {
      print("Error enviando SMS: $e");
      return false;
    }
  }

  Future<UserCredential?> verifyCode(String smsCode) async {
    try {
      if (_confirmationResult != null) {
        UserCredential userCredential = await _confirmationResult!.confirm(smsCode);
        
        // ¡Aquí está la magia! Una vez que el SMS es correcto, lo guardamos.
        await _guardarUsuarioEnBD(userCredential.user);
        
        return userCredential;
      }
      return null;
    } catch (e) {
      print("Error verificando código: $e");
      return null;
    }
  }

  // --- GUARDAR EN FIRESTORE ---
  Future<void> _guardarUsuarioEnBD(User? user) async {
    if (user == null) return;

    // Usamos el UID único que Firebase le da al usuario como ID del documento
    final docRef = _firestore.collection('usuarios').doc(user.uid);
    final docSnap = await docRef.get();

    // Si el documento NO existe, significa que es un usuario nuevo
    if (!docSnap.exists) {
      await docRef.set({
        'uid': user.uid,
        'telefono': user.phoneNumber ?? '',
        'email': user.email ?? '', // Por si entran con Google
        'nombre': user.displayName ?? 'Usuario', 
        'fecha_registro': FieldValue.serverTimestamp(), // Hora exacta del servidor
        'rol': 'cliente', // Por defecto todos son clientes
      });
      print("Nuevo usuario guardado en Firestore: ${user.uid}");
    } else {
      print("El usuario ya estaba registrado en la base de datos.");
    }
  }

  // --- CERRAR SESIÓN ---
  Future<void> signOut() async {
    await _auth.signOut();
    await _googleSignIn.signOut();
  }
}