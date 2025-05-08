import 'package:flutter/material.dart';


class AnalyticsObserver extends RouteObserver<PageRoute<dynamic>> {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PageRoute) {
      //UmengCommonSdk.onPageStart(route.settings.name ?? 'UnknownPage');
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (route is PageRoute) {
      //UmengCommonSdk.onPageEnd(route.settings.name ?? 'UnknownPage');
    }
    if (previousRoute is PageRoute) {
      //UmengCommonSdk.onPageStart(previousRoute.settings.name ?? 'UnknownPage');
    }
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    if (route is PageRoute) {
      //UmengCommonSdk.onPageEnd(route.settings.name ?? 'UnknownPage');
    }
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute is PageRoute) {
      //UmengCommonSdk.onPageEnd(oldRoute.settings.name ?? 'UnknownPage');
    }
    if (newRoute is PageRoute) {
      //UmengCommonSdk.onPageStart(newRoute.settings.name ?? 'UnknownPage');
    }
  }
}
