const Map<String, String> kBuiltInAdminAccounts = {
  'admin@psm.com': 'System Admin',
};

bool isBuiltInAdminEmail(String email) {
  return kBuiltInAdminAccounts.containsKey(email.trim().toLowerCase());
}

String? builtInAdminName(String email) {
  return kBuiltInAdminAccounts[email.trim().toLowerCase()];
}
