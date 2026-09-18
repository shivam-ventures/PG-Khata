/// Named route paths, centralized so a path is never hand-typed twice.
abstract final class AppRoute {
  static const login = '/login';
  static const verifyOtp = '/login/verify';

  static const ownerHome = '/owner';
  static const ownerProperties = '/owner/properties';
  static const ownerRooms = '/owner/properties/rooms';
  static const ownerTenants = '/owner/tenants';
  static const ownerMore = '/owner/more';

  static const managerToday = '/manager';
  static const managerPayments = '/manager/payments';
  static const managerRooms = '/manager/rooms';
  static const managerTenants = '/manager/tenants';
  static const managerMore = '/manager/more';

  static const tenantHome = '/tenant';
  static const tenantPayments = '/tenant/payments';
  static const tenantComplaints = '/tenant/complaints';
  static const tenantProfile = '/tenant/profile';
}
