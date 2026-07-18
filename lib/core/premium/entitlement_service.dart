import 'dart:async';
import 'package:flutter/material.dart';
import '../../features/subscription/domain/subscription_model.dart';
import '../../features/subscription/services/subscription_service.dart';
import 'plan_permissions.dart';

class EntitlementService extends ChangeNotifier {
  static final EntitlementService _instance = EntitlementService._internal();
  factory EntitlementService() => _instance;

  SubscriptionModel? _currentSubscription;
  StreamSubscription<SubscriptionModel>? _subSubscription;

  EntitlementService._internal() {
    _init();
  }

  void _init() {
    _subSubscription = SubscriptionService().watchSubscription().listen((sub) {
      _currentSubscription = sub;
      notifyListeners();
    });
  }

  void disposeService() {
    _subSubscription?.cancel();
  }

  SubscriptionModel get currentSubscription =>
      _currentSubscription ?? SubscriptionModel.freeTrial(DateTime.now());

  SubscriptionPlan get activePlan => currentSubscription.planEnum;

  bool isFeatureEnabled(String featureKey) {
    // If the subscription is expired or cancelled AND the current date is past the end date
    if (currentSubscription.status == 'expired' ||
        (currentSubscription.status == 'cancelled' &&
            DateTime.now().isAfter(currentSubscription.endDate))) {
      return false;
    }

    // Explicitly fallback to local plan permissions to ensure features are unlocked
    // based on the active plan type, even if Firestore features map is empty or misconfigured.
    final planDef = PlanPermissions.plans[activePlan];
    if (planDef != null && (planDef.features[featureKey] ?? false)) {
      return true;
    }

    return currentSubscription.features[featureKey] ?? false;
  }

  int getLimit(String limitType) {
    final planDef = PlanPermissions.plans[activePlan];
    if (limitType == 'children') {
      return planDef != null
          ? planDef.childrenLimit
          : currentSubscription.childrenLimit;
    } else if (limitType == 'devices') {
      return planDef != null
          ? planDef.devicesLimit
          : currentSubscription.devicesLimit;
    }
    return 1;
  }

  bool canAddChild(int currentChildCount) {
    return currentChildCount < getLimit('children');
  }

  bool canAddDevice(int currentDeviceCount) {
    return currentDeviceCount < getLimit('devices');
  }
}
