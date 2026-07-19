import 'package:flutter/widgets.dart';

import 'app.dart';
import 'core/di/injection.dart';
import 'features/profile/presentation/cubit/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();

  // Restore persisted settings before the first frame — otherwise the app
  // paints in the system theme and then snaps to the user's choice.
  await sl<SettingsCubit>().load();

  runApp(const CubeClashApp());
}
