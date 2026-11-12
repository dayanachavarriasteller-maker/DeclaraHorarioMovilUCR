import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:declara_horario/domain/workflow/declaration_workflow.dart';
import 'package:declara_horario/repositories/declaration_repository.dart';
import 'package:declara_horario/repositories/firestore_declaration_repository.dart';
import 'package:declara_horario/repositories/firestore_period_repository.dart';
import 'package:declara_horario/repositories/firestore_user_repository.dart';
import 'package:declara_horario/repositories/firestore_version_content_repository.dart';
import 'package:declara_horario/repositories/period_repository.dart';
import 'package:declara_horario/repositories/user_repository.dart';
import 'package:declara_horario/repositories/version_content_repository.dart';
import 'package:declara_horario/services/auth_service.dart';
import 'package:declara_horario/services/content_hash_service.dart';
import 'package:declara_horario/services/firebase_auth_service.dart';
import 'package:declara_horario/services/firestore_workflow_service.dart';
import 'package:declara_horario/services/workflow_service.dart';
import 'package:declara_horario_movil/features/auth/session_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

/// Dependencias del módulo móvil. TODOS los servicios y repositorios son las
/// implementaciones del sistema original (paquete `declara_horario`); aquí
/// solo se registran, igual que en su `app_providers.dart`.
List<SingleChildWidget> buildProviders() => <SingleChildWidget>[
      Provider<AuthService>(
        create: (_) => FirebaseAuthService(FirebaseAuth.instance),
      ),
      Provider<UserRepository>(
        create: (_) => FirestoreUserRepository(FirebaseFirestore.instance),
      ),
      Provider<PeriodRepository>(
        create: (_) => FirestorePeriodRepository(FirebaseFirestore.instance),
      ),
      Provider<DeclarationRepository>(
        create: (_) =>
            FirestoreDeclarationRepository(FirebaseFirestore.instance),
      ),
      Provider<VersionContentRepository>(
        create: (_) =>
            FirestoreVersionContentRepository(FirebaseFirestore.instance),
      ),
      Provider<WorkflowService>(
        create: (context) => FirestoreWorkflowService(
          firestore: FirebaseFirestore.instance,
          versionContentRepository: context.read<VersionContentRepository>(),
          contentHashService: const ContentHashService(),
          declarationWorkflow: const DeclarationWorkflow(),
        ),
      ),
      ChangeNotifierProvider<SessionState>(
        create: (context) => SessionState(
          auth: context.read<AuthService>(),
          users: context.read<UserRepository>(),
        ),
      ),
    ];
