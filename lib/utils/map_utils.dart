import 'package:url_launcher/url_launcher.dart';

class MapUtils {
  /// Abre Google Maps o la app de mapas por defecto con un Pin en las coordenadas dadas.
  static Future<void> abrirMapa(double latitud, double longitud) async {
    // URL universal para abrir mapas con un marcador exacto
    final String urlMapa = "https://www.google.com/maps/search/?api=1&query=$latitud,$longitud";
    final Uri url = Uri.parse(urlMapa);
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      throw 'No se pudo abrir la aplicación de mapas.';
    }
  }
}