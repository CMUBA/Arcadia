import 'package:bonfire_multiplayer/pages/game/game_page.dart';
import 'package:bonfire_multiplayer/pages/game/game_route.dart';
import 'package:get/get.dart';
import '../../pages/home/home_page.dart';
import '../pages/account/login_page.dart';
import '../pages/account/register_page.dart';
import '../theme/change_language_page.dart';
import '../theme/change_theme_page.dart';

final routes = <GetPage>[
  GetPage(name: LoginPage.routeName, page: () => LoginPage()),
  GetPage(name: RegisterPage.routeName, page: () => RegisterPage()),
  // GetPage(name: MainPage.routeName, page: () => MainPage(), middlewares: [
  //   GlobalAuthMiddleware()
  // ]),
  GetPage(name: GamePage.routeName, page: () => GamePage()),
  GetPage(name: HomePage.routeName, page: () => HomePage()),
  GetPage(name: ChangeThemePage.routeName, page: () => ChangeThemePage()),
  GetPage(name: ChangeLanguagePage.routeName, page: () => ChangeLanguagePage())
];