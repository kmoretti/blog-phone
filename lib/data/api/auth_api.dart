import '../models/auth_models.dart';
import 'api_client.dart';

class AuthApi {
  const AuthApi(this.client);

  final ApiClient client;

  Future<LoginResponse> login({
    required String username,
    required String password,
    String? turnstileToken,
  }) async {
    final data = <String, dynamic>{'username': username, 'password': password};
    if (turnstileToken != null && turnstileToken.isNotEmpty) {
      data['turnstile_token'] = turnstileToken;
    }
    final response = await client.post('verify/passwd', data: data);
    return LoginResponse.fromJson((response as Map).cast<String, dynamic>());
  }

  Future<VerifyConfig> getVerifyConfig() async {
    final response = await client.get('public/verify_conf');
    return VerifyConfig.fromJson((response as Map).cast<String, dynamic>());
  }
}
