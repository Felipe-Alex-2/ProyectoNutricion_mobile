class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://proyectonutricionbackend-production-8308.up.railway.app/api/v1',
  );
}
