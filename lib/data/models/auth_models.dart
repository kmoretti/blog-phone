class LoginResponse {
  const LoginResponse({required this.token, required this.expiresAt});

  final String token;
  final String expiresAt;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? json;
    return LoginResponse(
      token: data['token']?.toString() ?? '',
      expiresAt: data['expires_at']?.toString() ?? '',
    );
  }
}

class TurnstileConfig {
  const TurnstileConfig({required this.enabled, required this.siteKey});

  final bool enabled;
  final String siteKey;

  factory TurnstileConfig.fromJson(Map<String, dynamic> json) {
    return TurnstileConfig(
      enabled: json['enable'] == true,
      siteKey: json['site_key']?.toString() ?? '',
    );
  }
}

class VerifyConfig {
  const VerifyConfig({required this.turnstile});

  final TurnstileConfig turnstile;

  factory VerifyConfig.fromJson(Map<String, dynamic> json) {
    final data = (json['data'] as Map?)?.cast<String, dynamic>() ?? json;
    return VerifyConfig(
      turnstile: TurnstileConfig.fromJson(
        (data['turnstile'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.token,
    required this.baseUrl,
    required this.expiresAt,
  });

  final String token;
  final String baseUrl;
  final String expiresAt;
}
