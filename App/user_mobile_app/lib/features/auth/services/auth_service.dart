import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;

  // =========================================================
  // GOOGLE SIGN-IN
  // =========================================================

  Future<UserCredential> signInWithGoogle() async {
    // Initialize Google Sign-In.
    await _googleSignIn.initialize();

    // Open Google account picker.
    final GoogleSignInAccount googleUser =
        await _googleSignIn.authenticate();

    // Get Google auth token.
    final GoogleSignInAuthentication googleAuth =
        googleUser.authentication;

    // Create Firebase credential.
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    // Sign in to Firebase.
    final userCredential = await _auth.signInWithCredential(credential);

    final user = userCredential.user;

    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'google-user-invalid',
        message: 'Cannot get Google user information.',
      );
    }

    final normalizedEmail = user.email!.trim().toLowerCase();

    final userRef = _db.collection('users').doc(user.uid);
    final userSnapshot = await userRef.get();

    // If profile already exists, keep old data.
    if (userSnapshot.exists) {
      return userCredential;
    }

    // Create username from Google email.
    // Example: nqkit@gmail.com -> nqkit
    String baseUsername = normalizedEmail.split('@').first;

    // Keep only letters, numbers and underscore.
    baseUsername = baseUsername.replaceAll(
      RegExp(r'[^a-zA-Z0-9_]'),
      '_',
    );

    // Make username longer if it is too short.
    if (baseUsername.length < 4) {
      baseUsername = '${baseUsername}_user';
    }

    String finalUsername = baseUsername;

    final usernameRef = _db.collection('usernames').doc(finalUsername);
    final usernameSnapshot = await usernameRef.get();

    // If username is used by another user, add UID suffix.
    if (usernameSnapshot.exists) {
      final data = usernameSnapshot.data();

      if (data == null || data['uid'] != user.uid) {
        final suffix = user.uid.substring(0, 6).toLowerCase();
        finalUsername = '${baseUsername}_$suffix';
      }
    }

    final finalUsernameRef = _db.collection('usernames').doc(finalUsername);

    // Save Google user profile.
    // displayName is empty, ProfilePage will show username instead.
    await userRef.set({
      'uid': user.uid,
      'email': normalizedEmail,
      'username': finalUsername,
      'displayName': finalUsername,
      'photoURL': user.photoURL,
      'provider': user.providerData.map((p) => p.providerId).toList(),
      'emailVerified': user.emailVerified,
      'profileCompleted': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Save username mapping.
    await finalUsernameRef.set({
      'uid': user.uid,
      'email': normalizedEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  // =========================================================
  // EMAIL / PASSWORD ACCOUNT CREATION
  // =========================================================

  Future<UserCredential> createAccountWithEmailPassword({
    required String username,
    required String email,
    required String password,
  }) async {
    final normalizedUsername = username.trim().toLowerCase();
    final normalizedEmail = email.trim().toLowerCase();

    final usernameRef = _db.collection('usernames').doc(normalizedUsername);

    final usernameSnapshot = await usernameRef.get();

    if (usernameSnapshot.exists) {
      throw FirebaseAuthException(
        code: 'username-already-used',
        message: 'This username is already used.',
      );
    }

    // Create temporary Firebase Auth account.
    final credential = await _auth.createUserWithEmailAndPassword(
      email: normalizedEmail,
      password: password.trim(),
    );

    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-create-failed',
        message: 'Cannot create user.',
      );
    }

    // Store username temporarily.
    await user.updateDisplayName(normalizedUsername);

    // Send email verification link.
    await user.sendEmailVerification();

    // Do not save Firestore here.
    return credential;
  }

  Future<void> saveVerifiedEmailPasswordAccount({
    required String username,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No current user is signed in.',
      );
    }

    await user.reload();

    final refreshedUser = _auth.currentUser;

    if (refreshedUser == null || !refreshedUser.emailVerified) {
      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email before creating the account.',
      );
    }

    final normalizedUsername = username.trim().toLowerCase();
    final normalizedEmail = refreshedUser.email?.trim().toLowerCase();

    if (normalizedEmail == null || normalizedEmail.isEmpty) {
      throw FirebaseAuthException(
        code: 'missing-email',
        message: 'This account does not have an email.',
      );
    }

    final usernameRef = _db.collection('usernames').doc(normalizedUsername);

    final usernameSnapshot = await usernameRef.get();

    if (usernameSnapshot.exists) {
      throw FirebaseAuthException(
        code: 'username-already-used',
        message: 'This username is already used.',
      );
    }

    await refreshedUser.updateDisplayName(normalizedUsername);

    await _db.collection('users').doc(refreshedUser.uid).set({
      'uid': refreshedUser.uid,
      'email': normalizedEmail,
      'username': normalizedUsername,
      'displayName': normalizedUsername,
      'photoURL': refreshedUser.photoURL,
      'provider': 'password',
      'emailVerified': true,
      'profileCompleted': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await usernameRef.set({
      'uid': refreshedUser.uid,
      'email': normalizedEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteUnverifiedCurrentUser() async {
    final user = _auth.currentUser;

    if (user == null) return;

    await user.reload();

    final refreshedUser = _auth.currentUser;

    if (refreshedUser != null && !refreshedUser.emailVerified) {
      await refreshedUser.delete();
    } else {
      await _auth.signOut();
    }
  }

  // =========================================================
  // LINK PASSWORD TO GOOGLE ACCOUNT
  // =========================================================

  Future<void> linkPasswordToCurrentUser({
    required String password,
  }) async {
    final user = _auth.currentUser;

    if (user == null || user.email == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No current user is signed in.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: password.trim(),
    );

    await user.linkWithCredential(credential);
  }

  Future<void> saveCurrentUserProfile({
    required String username,
  }) async {
    final user = _auth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No current user is signed in.',
      );
    }

    final normalizedUsername = username.trim().toLowerCase();
    final usernameRef = _db.collection('usernames').doc(normalizedUsername);

    final usernameSnapshot = await usernameRef.get();

    if (usernameSnapshot.exists) {
      final data = usernameSnapshot.data();

      if (data == null || data['uid'] != user.uid) {
        throw FirebaseAuthException(
          code: 'username-already-used',
          message: 'This username is already used.',
        );
      }
    }

    await _db.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'username': normalizedUsername,
      'displayName': '',
      'photoURL': user.photoURL,
      'provider': user.providerData.map((p) => p.providerId).toList(),
      'emailVerified': user.emailVerified,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await usernameRef.set({
      'uid': user.uid,
      'email': user.email,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // =========================================================
  // USERNAME OR EMAIL LOGIN
  // =========================================================

  Future<String> getEmailFromUsernameOrEmail(String input) async {
    final value = input.trim().toLowerCase();

    if (value.contains('@')) {
      return value;
    }

    final doc = await _db.collection('usernames').doc(value).get();

    if (!doc.exists) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'Username does not exist.',
      );
    }

    final data = doc.data();

    if (data == null || data['email'] == null) {
      throw FirebaseAuthException(
        code: 'invalid-username-data',
        message: 'Cannot find email for this username.',
      );
    }

    return data['email'] as String;
  }

  Future<UserCredential> signInWithUsernameOrEmailPassword({
    required String usernameOrEmail,
    required String password,
  }) async {
    final email = await getEmailFromUsernameOrEmail(usernameOrEmail);

    final credential = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password.trim(),
    );

    final user = credential.user;

    if (user != null && !user.emailVerified) {
      await _auth.signOut();

      throw FirebaseAuthException(
        code: 'email-not-verified',
        message: 'Please verify your email before signing in.',
      );
    }

    return credential;
  }

  // =========================================================
  // PASSWORD RESET
  // =========================================================

  Future<void> sendPasswordResetEmail(String usernameOrEmail) async {
    final email = await getEmailFromUsernameOrEmail(usernameOrEmail);

    await _auth.sendPasswordResetEmail(
      email: email,
    );
  }

  // =========================================================
  // SIGN OUT
  // =========================================================

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}