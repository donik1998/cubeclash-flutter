import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'core/network/auth_interceptor.dart';
import 'features/profile/presentation/cubit/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  // Both restores happen before the first frame:
  //  * settings, or the app paints in the system theme then snaps to the
  //    user's choice;
  //  * tokens, or the router's guard sees "no session" and flashes the
  //    welcome screen at someone who is already signed in.
  await Future.wait<void>(<Future<void>>[
    sl<SettingsCubit>().load(),
    sl<TokenStore>().restore(),
  ]);

  runApp(const CubeClashApp());
}
