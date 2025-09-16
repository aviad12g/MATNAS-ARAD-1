class UserAccount {
  UserAccount({
    required this.id,
    required this.displayName,
    required this.email,
    required this.passwordHash,
  });

  final String id;
  final String displayName;
  final String email;
  final String passwordHash;

  UserAccount copyWith({
    String? id,
    String? displayName,
    String? email,
    String? passwordHash,
  }) {
    return UserAccount(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'email': email,
      'passwordHash': passwordHash,
    };
  }

  factory UserAccount.fromJson(Map<String, dynamic> json) {
    return UserAccount(
      id: json['id'] as String,
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      passwordHash: json['passwordHash'] as String? ?? '',
    );
  }
}
