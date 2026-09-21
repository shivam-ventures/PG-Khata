/// Named route paths, centralized so a path is never hand-typed twice.
abstract final class AppRoute {
  static const login = '/login';
  static const verifyOtp = '/login/verify';

  /// The invite-link entry point (`Auth.dc.html`'s `hasInvite` branch),
  /// reachable while signed out — see the redirect logic in
  /// `core/routing/app_router.dart`. The actual route is `/join/:token`.
  static const joinPrefix = '/join';

  static const ownerHome = '/owner';
  static const ownerProperties = '/owner/properties';
  static const ownerRooms = '/owner/properties/rooms';
  static const ownerTenants = '/owner/tenants';
  static const ownerPayments = '/owner/payments';
  static const ownerReports = '/owner/reports';
  static const ownerMore = '/owner/more';

  static const managerToday = '/manager';
  static const managerPayments = '/manager/payments';
  static const managerRooms = '/manager/rooms';
  static const managerTenants = '/manager/tenants';
  static const managerComplaints = '/manager/complaints';
  static const managerMore = '/manager/more';

  static const tenantHome = '/tenant';
  static const tenantPayments = '/tenant/payments';
  static const tenantComplaints = '/tenant/complaints';
  static const tenantProfile = '/tenant/profile';
}
