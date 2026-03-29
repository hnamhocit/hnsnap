import 'package:go_router/go_router.dart';
import 'package:hnsnap/app/router/app_route_extras.dart';
import 'package:hnsnap/app/router/app_routes.dart';
import 'package:hnsnap/features/notes/presentation/screens/index.dart';

final GoRouter router = GoRouter(
  routes: [
    GoRoute(
      path: AppRoutes.homePath,
      name: AppRoutes.home,
      builder: (context, state) => const HomeScreen(),
      routes: [
        GoRoute(
          path: AppRoutes.galleryPath.substring(1),
          name: AppRoutes.gallery,
          builder: (context, state) => const GalleryMediaPickerScreen(),
        ),
        GoRoute(
          path: AppRoutes.noteCatalogPath.substring(1),
          name: AppRoutes.noteCatalog,
          builder: (context, state) {
            final extra = state.extra as NoteCatalogRouteExtra;
            return NoteCatalogScreen(
              notesRepository: extra.notesRepository,
              initialSelectedNoteId: extra.initialSelectedNoteId,
            );
          },
        ),
        GoRoute(
          path: AppRoutes.settingsPath.substring(1),
          name: AppRoutes.settings,
          builder: (context, state) {
            final extra = state.extra as SettingsRouteExtra;
            return SettingsScreen(notesRepository: extra.notesRepository);
          },
        ),
      ],
    ),
  ],
);
