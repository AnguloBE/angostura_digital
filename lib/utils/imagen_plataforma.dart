import 'imagen_plataforma_stub.dart'
    if (dart.library.ui_web) 'imagen_plataforma_web.dart' as plataforma;

bool get esNavegadorMovil => plataforma.esNavegadorMovil;

Future<String> prepararImagenParaRecorte(String ruta, {int calidad = 82}) {
  return plataforma.prepararImagenParaRecorte(ruta, calidad: calidad);
}
