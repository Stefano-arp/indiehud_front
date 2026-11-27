import 'package:flutter_test/flutter_test.dart';
import 'package:indiehud/services/descargas_web.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  test('marca, consulta y elimina una descarga simulada', () async {
    expect(await DescargasWebService.estaDescargado(7), isFalse);

    await DescargasWebService.marcarDescargado(7);
    expect(await DescargasWebService.estaDescargado(7), isTrue);

    await DescargasWebService.quitarDescarga(7);
    expect(await DescargasWebService.estaDescargado(7), isFalse);
  });

  test('alterna favoritos web sin afectar las descargas', () async {
    await DescargasWebService.marcarDescargado(3);

    await DescargasWebService.alternarFavorito(3, valor: true);
    expect(await DescargasWebService.esFavorito(3), isTrue);
    expect(await DescargasWebService.estaDescargado(3), isTrue);

    await DescargasWebService.alternarFavorito(3, valor: false);
    expect(await DescargasWebService.esFavorito(3), isFalse);
    expect(await DescargasWebService.estaDescargado(3), isTrue);
  });
}
