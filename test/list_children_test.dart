import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:the_guardian_child/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('FIREBASE_QUERY: Firebase initialized!');
    
    // Sign in anonymously
    final userCredential = await FirebaseAuth.instance.signInAnonymously();
    print('FIREBASE_QUERY: Signed in anonymously: ${userCredential.user?.uid}');
    
    // Query collection group "children"
    final querySnapshot = await FirebaseFirestore.instance
        .collectionGroup('children')
        .get();
        
    print('FIREBASE_QUERY: Found ${querySnapshot.docs.length} children docs:');
    for (var doc in querySnapshot.docs) {
      print('FIREBASE_QUERY: Child path: ${doc.reference.path}');
      print('FIREBASE_QUERY: Data: ${doc.data()}');
      
      try {
        final rulesDoc = await doc.reference.collection('rules').doc('active').get();
        print('FIREBASE_QUERY: Rules for ${doc.id}: ${rulesDoc.data()}');
      } catch (e) {
        print('FIREBASE_QUERY: Failed to read rules for ${doc.id}: $e');
      }
    }
  } catch (e, stack) {
    print('FIREBASE_QUERY: Error: $e');
    print('FIREBASE_QUERY: Stack: $stack');
  }
  
  runApp(
    const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Query finished!'),
        ),
      ),
    ),
  );
}
