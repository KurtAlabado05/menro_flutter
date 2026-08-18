import '../../firebase_service.dart';

/// Remote API endpoints used by the EcoMap client.
class ApiConfig {
  ApiConfig._();

  static const String _region = 'us-central1';

  /// identifySpecies endpoint.
  ///
  /// By default, it points to the legacy Firebase Cloud Function.
  /// If you deploy the Cloudflare Worker, override this to:
  ///   https://<your-worker-subdomain>.<your-zone>/identifySpecies
  static String get identifySpeciesUrl {
    // Prefer explicit runtime override.
    const runtimeUrl = String.fromEnvironment(
      'IDENTIFY_SPECIES_URL',
      defaultValue: '',
    );

    if (runtimeUrl.trim().isNotEmpty) return runtimeUrl.trim();

    // Fallback: packaged app config (so Flutter Web works locally too).
    return ApiRuntimeConfig.identifySpeciesUrl;
  }
}
