/// Central, single-source-of-truth configuration for the SI BENI client.
class AppConfig {
  const AppConfig._();

  static const String appName = 'SI BENI';
  static const String appTagline = 'Siaga Bencana Dini';
  static const String organisation = 'PT Consnet Mining';

  /// B2B API host (Next.js on Render) that fronts Supabase.
  static const String apiBaseUrl = 'https://sibeni-backend.onrender.com';

  /// Identifier sent with map tile requests (OSM tile usage policy).
  static const String tileUserAgent = 'com.consnet.sibeni';

  /// Duration of the intentional SOS hold, in seconds.
  static const int sosHoldSeconds = 3;

  /// Supabase project configuration.
  static const String supabaseUrl = 'https://qgdnrsnbxwqrouigrskb.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFnZG5yc25ieHdxcm91aWdyc2tiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIxMzU4MjUsImV4cCI6MjEwNzcxMTgyNX0.GidEFVlR4sRH4babQ7sIGRDmNrWRYCOtQ5s_rXvqOH8';

  /// Network timeouts — tuned for intermittent site connectivity.
  static const Duration shortTimeout = Duration(seconds: 8);
  static const Duration longTimeout = Duration(seconds: 15);

  static String api(String path) => '$apiBaseUrl$path';
}