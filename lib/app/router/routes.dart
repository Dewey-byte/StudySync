/// Every navigable location in the app.
///
/// Paths are declared once here so route strings are never re-typed at call
/// sites and cannot drift apart.
enum AppRoute {
  splash('/splash', 'splash'),
  signIn('/sign-in', 'signIn'),
  signUp('/sign-up', 'signUp'),
  lock('/lock', 'lock'),
  dashboard('/dashboard', 'dashboard'),
  assignments('/assignments', 'assignments'),
  schedule('/schedule', 'schedule'),
  groups('/groups', 'groups'),
  groupDetail('/groups/:groupId', 'groupDetail'),
  settings('/settings', 'settings');

  const AppRoute(this.path, this.name);

  final String path;
  final String name;
}
