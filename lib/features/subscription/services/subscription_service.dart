import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../domain/subscription_model.dart';
import '../../../core/premium/plan_permissions.dart';

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<SubscriptionModel> watchSubscription() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value(SubscriptionModel.freeTrial(DateTime.now()));
    }

    return _db.collection('subscriptions').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) {
        // Provisioning is performed by the authenticated backend, never here.
        return SubscriptionModel.freeTrial(DateTime.now());
      }
      return SubscriptionModel.fromMap(doc.data()!);
    });
  }

  Future<SubscriptionModel> getSubscription() async {
    final user = _auth.currentUser;
    if (user == null) {
      return SubscriptionModel.freeTrial(DateTime.now());
    }

    final doc = await _db.collection('subscriptions').doc(user.uid).get();
    if (!doc.exists) {
      return SubscriptionModel.freeTrial(DateTime.now());
    }
    return SubscriptionModel.fromMap(doc.data()!);
  }

  Future<void> updateSubscription(SubscriptionModel sub) async {
    // Kept for legacy UI flows. The server webhook is the only entitlement writer.
  }

  Future<void> recordPayment(Map<String, dynamic> paymentDetails) async {
    // Payment receipts are created only from a verified provider webhook.
  }

  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    final user = _auth.currentUser;
    if (user == null) return [];

    final q = await _db
        .collection('subscriptions')
        .doc(user.uid)
        .collection('payments')
        .orderBy('timestamp', descending: true)
        .get();

    return q.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
  }

  Future<void> cancelSubscription() async {
    final now = DateTime.now();
    final updated = SubscriptionModel(
      plan: 'free',
      status: 'cancelled',
      billingCycle: 'none',
      startDate: now,
      endDate: now,
      trialUsed: true,
      childrenLimit: 1,
      devicesLimit: 1,
      features: PlanPermissions.plans[SubscriptionPlan.free]!.features,
    );
    await updateSubscription(updated);
  }

  Future<void> restoreSubscription() async {
    final sub = await getSubscription();
    final updated = SubscriptionModel(
      plan: sub.plan,
      status: 'active',
      billingCycle: sub.billingCycle,
      startDate: sub.startDate,
      endDate: sub.endDate,
      trialUsed: sub.trialUsed,
      childrenLimit: sub.childrenLimit,
      devicesLimit: sub.devicesLimit,
      features: sub.features,
    );
    await updateSubscription(updated);
  }
}
