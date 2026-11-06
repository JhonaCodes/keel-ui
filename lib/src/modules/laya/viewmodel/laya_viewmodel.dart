import 'dart:async';

import 'package:logger_rs/logger_rs.dart';
import 'package:reactive_notifier/reactive_notifier.dart';

import 'package:keel_core/integrations/laya/laya.dart';
import 'package:keel_ui/src/integrations/llm/llm_keel_ui_wiring.dart';
import 'package:keel_ui/src/modules/laya/model/laya_state.dart';
import 'package:keel_ui/src/modules/laya/viewmodel/laya_forms_viewmodel.dart';
import 'package:keel_ui/src/modules/roadmap/viewmodel/task_claims_viewmodel.dart';

/// Laya para el usuario: revisar las tareas de un proyecto y el mini chat.
/// Siempre disponible si la bóveda la tiene, sin importar el interruptor de
/// los agentes.
class LayaViewModel extends ViewModel<LayaState> {
  LayaViewModel() : super(const LayaState());

  /// Se relee si la bóveda tiene Laya: un secret se carga mientras la app
  /// está abierta.
  static const _recheck = Duration(minutes: 1);

  Timer? _timer;

  @override
  void init() {
    updateSilently(const LayaState());
    unawaited(checkConfigured());
    _timer = Timer.periodic(_recheck, (_) => unawaited(checkConfigured()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<LayaConfig?> _config() => LayaConfig.resolve(resolveLlmSecret);

  Future<void> checkConfigured() async {
    final configured = await _config() != null;
    if (configured != data.configured) {
      updateState(data.copyWith(configured: configured));
    }
  }

  /// Le pregunta a Laya por cada tarea abierta del proyecto en
  /// [projectPath]: si está demorada y qué conviene hacer.
  Future<void> reviewTasks(String projectPath) async {
    if (data.reviewOf(projectPath).loading) return;
    _setReview(projectPath, data.reviewOf(projectPath).copyWith(loading: true));
    final config = await _config();
    if (config == null) {
      _setReview(
        projectPath,
        LayaReview(
          error: 'Faltan LAYA_URL y LAYA_API_KEY en la bóveda.',
          at: DateTime.now(),
        ),
      );
      return;
    }
    try {
      final verdicts = await reviewRoadmapWithLaya(
        config,
        projectPath: projectPath,
        claims: TaskClaimsService.instance.notifier.activeClaimsFor(
          projectPath,
        ),
      );
      _setReview(
        projectPath,
        LayaReview(verdicts: verdicts, at: DateTime.now()),
      );
    } catch (error) {
      Log.w('Laya no pudo revisar las tareas: $error');
      _setReview(projectPath, LayaReview(error: '$error', at: DateTime.now()));
    }
  }

  void _setReview(String projectPath, LayaReview review) {
    updateState(data.copyWith(reviews: {...data.reviews, projectPath: review}));
  }

  /// El mini chat: le manda a Laya [draft] —la pregunta, su tipo de
  /// respuesta, las opciones o los niveles y la evidencia— y guarda lo que
  /// contestó. Devuelve por qué no se envió, o null.
  Future<String?> ask(LayaQuestionDraft draft) async {
    final problem = draft.problem;
    if (problem != null) return problem;
    final exchange = LayaExchange(
      draft: draft,
      at: DateTime.now(),
      pending: true,
    );
    _append(exchange);

    final config = await _config();
    if (config == null) {
      _replace(
        exchange,
        exchange.copyWith(
          pending: false,
          error: 'Faltan LAYA_URL y LAYA_API_KEY en la bóveda.',
        ),
      );
      return null;
    }
    try {
      final answers = await LayaClient.ask(
        config,
        state: draft.state,
        questions: {'q': draft.wireQuestion},
      );
      final answer = answers['q'];
      _replace(
        exchange,
        _read(exchange, answer is Map ? answer.cast<String, Object?>() : {}),
      );
    } catch (error) {
      _replace(exchange, exchange.copyWith(pending: false, error: '$error'));
    }
    return null;
  }

  /// Lo que contestó Laya, con nombres: sí/no, la opción o el nivel.
  static LayaExchange _read(LayaExchange exchange, Map<String, Object?> raw) {
    final names = exchange.draft.answerNames;
    final confidence = (raw['confidence'] as num?)?.toDouble();
    final Map<String, double> probabilities;
    final String? answer;
    switch (exchange.draft.kind) {
      case LayaQuestionKind.yesNo:
        final yes = (raw['noul'] as num?)?.toDouble() ?? 0;
        probabilities = {'sí': yes, 'no': 1 - yes};
        answer = yes >= 0.5 ? 'sí' : 'no';
      case LayaQuestionKind.choice:
        probabilities = _probabilities(raw['probabilities'], names);
        answer = raw['choice'] as String?;
      case LayaQuestionKind.score:
        // Laya numera los niveles desde 0; se muestran con su nombre.
        probabilities = _probabilities(raw['probabilities'], names);
        final best = probabilities.entries.firstOrNull;
        answer = best?.key;
    }
    return exchange.copyWith(
      pending: false,
      answer: answer,
      probabilities: probabilities,
      confidence: confidence,
    );
  }

  /// Las probabilidades por nombre, la más alta primero. Una clave numérica
  /// (los niveles de una escala) se traduce al nombre de ese nivel.
  static Map<String, double> _probabilities(Object? raw, List<String> names) {
    if (raw is! Map) return const {};
    final entries = <MapEntry<String, double>>[
      for (final MapEntry(:key, :value) in raw.entries)
        if (value is num)
          MapEntry(switch (int.tryParse('$key')) {
            final int index when index >= 0 && index < names.length =>
              names[index],
            _ => '$key',
          }, value.toDouble()),
    ]..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries);
  }

  /// Guarda la pregunta armada como formulario de una pregunta, con la
  /// pregunta como nombre, y lo enfoca. Devuelve el motivo si no se pudo.
  String? saveDraftAsForm(LayaQuestionDraft draft) {
    final problem = draft.problem;
    if (problem != null) return problem;
    final question = draft.question.trim();
    final name = question.length > 60
        ? '${question.substring(0, 60)}…'
        : question;
    final forms = LayaFormsService.instance.notifier;
    final saved = forms.save(draft.toForm(name: name));
    if (saved != null) return saved;
    final form = forms.formNamed(name);
    if (form != null) focusForm(form.id);
    return null;
  }

  /// Que el panel abra [formId]. Lo pide Keel AI al crear uno.
  void focusForm(String formId) =>
      updateState(data.copyWith(focusFormId: formId));

  void clearFocus() => updateState(data.copyWith(clearFocus: true));

  void clearChat() => updateState(data.copyWith(chat: const []));

  void _append(LayaExchange exchange) =>
      updateState(data.copyWith(chat: [...data.chat, exchange]));

  void _replace(LayaExchange old, LayaExchange next) => updateState(
    data.copyWith(
      chat: [
        for (final exchange in data.chat)
          if (identical(exchange, old)) next else exchange,
      ],
    ),
  );
}

mixin LayaService {
  static final ReactiveNotifier<LayaViewModel> instance =
      ReactiveNotifier<LayaViewModel>(() => LayaViewModel());
}
