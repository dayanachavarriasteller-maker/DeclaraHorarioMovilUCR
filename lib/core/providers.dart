import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:declara_horario/domain/workflow/declaration_workflow.dart';
import 'package:declara_horario/features/pdf/state/pdf_state.dart';
import 'package:declara_horario/repositories/declaration_repository.dart';
import 'package:declara_horario/repositories/firestore_declaration_repository.dart';
import 'package:declara_horario/repositories/firebase_pdf_storage_repository.dart';
import 'package:declara_horario/repositories/firestore_oath_config_repository.dart';
import 'package:declara_horario/repositories/firestore_period_repository.dart';
import 'package:declara_horario/repositories/firestore_signature_repository.dart';
import 'package:declara_horario/repositories/firestore_user_repository.dart';
import 'package:declara_horario/repositories/firestore_version_content_repository.dart';
import 'package:declara_horario/repositories/oath_config_repository.dart';
import 'package:declara_horario/repositories/pdf_storage_repository.dart';
import 'package:declara_horario/repositories/period_repository.dart';
import 'package:declara_horario/repositories/signature_repository.dart';
import 'package:declara_horario/repositories/user_repository.dart';
import 'package:declara_horario/repositories/version_content_repository.dart';
import 'package:declara_horario/services/auth_service.dart';
import 'package:declara_horario/services/content_hash_service.dart';
import 'package:declara_horario/services/file_download_service.dart';
import 'package:declara_horario/services/firebase_auth_service.dart';
import 'package:declara_horario/services/firestore_workflow_service.dart';
import 'package:declara_horario/services/oath_text_service.dart';
import 'package:declara_horario/services/pdf_builder_service.dart';
import 'package:declara_horario/services/workflow_service.dart';
import 'package:declara_horario_movil/features/auth/session_state.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
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
    create: (_) => FirestoreDeclarationRepository(FirebaseFirestore.instance),
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
  // PDF de la declaración: el mismo generador y la misma descarga del
  // original (`pdf_providers.dart` y `signatures_providers.dart`).
  Provider<OathConfigRepository>(
    create: (_) => FirestoreOathConfigRepository(FirebaseFirestore.instance),
  ),
  Provider<OathTextService>(
    create: (context) => OathTextService(
      oathConfigRepository: context.read<OathConfigRepository>(),
      periodRepository: context.read<PeriodRepository>(),
    ),
  ),
  Provider<SignatureRepository>(
    create: (_) => FirestoreSignatureRepository(FirebaseFirestore.instance),
  ),
  Provider<PdfBuilderService>(create: (_) => const PdfBuilderService()),
  Provider<FileDownloadService>(
    create: (_) => const BrowserFileDownloadService(),
  ),
  Provider<PdfStorageRepository>(
    create: (_) => FirebasePdfStorageRepository(FirebaseStorage.instance),
  ),
  ChangeNotifierProvider<PdfState>(
    create: (context) => PdfState(
      pdfBuilderService: context.read<PdfBuilderService>(),
      pdfStorageRepository: context.read<PdfStorageRepository>(),
      declarationRepository: context.read<DeclarationRepository>(),
      versionContentRepository: context.read<VersionContentRepository>(),
      signatureRepository: context.read<SignatureRepository>(),
      oathTextService: context.read<OathTextService>(),
    ),
  ),
  ChangeNotifierProvider<SessionState>(
    create: (context) => SessionState(
      auth: context.read<AuthService>(),
      users: context.read<UserRepository>(),
    ),
  ),
];
