import 'package:keel_core/integrations/laya/laya.dart';
import 'package:keel_core/modules/laya_forms/model/laya_form.dart';

/// El tipo de respuesta que se le pide a Laya.
enum LayaQuestionKind {
  /// Sí o no: Laya devuelve la probabilidad de SÍ.
  yesNo('Sí / no', 'noul'),

  /// Una entre varias opciones, cada una con su descripción.
  choice('Una entre opciones', 'choice'),

  /// Un nivel en una escala ordenada. En las pruebas fue poco fiable.
  score('Escala (niveles)', 'score');

  const LayaQuestionKind(this.label, this.wire);

  final String label;

  /// Cómo lo llama el protocolo de Laya.
  final String wire;
}

/// Una opción de una pregunta «una entre opciones». Laya compara la
/// evidencia contra la DESCRIPCIÓN, no contra el nombre suelto.
class LayaOption {
  const LayaOption({required this.name, this.description = ''});

  final String name;
  final String description;

  LayaOption copyWith({String? name, String? description}) => LayaOption(
    name: name ?? this.name,
    description: description ?? this.description,
  );

  Map<String, Object?> toJson() => {'name': name, 'description': description};

  factory LayaOption.fromJson(Map<String, Object?> json) => LayaOption(
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is LayaOption &&
      other.name == name &&
      other.description == description;

  @override
  int get hashCode => Object.hash(name, description);
}

/// Un dato de la evidencia: lo que Laya mira, con nombre.
class LayaEvidence {
  const LayaEvidence({required this.name, required this.value});

  final String name;
  final String value;

  LayaEvidence copyWith({String? name, String? value}) =>
      LayaEvidence(name: name ?? this.name, value: value ?? this.value);

  Map<String, Object?> toJson() => {'name': name, 'value': value};

  factory LayaEvidence.fromJson(Map<String, Object?> json) => LayaEvidence(
    name: json['name'] as String? ?? '',
    value: json['value'] as String? ?? '',
  );

  @override
  bool operator ==(Object other) =>
      other is LayaEvidence && other.name == name && other.value == value;

  @override
  int get hashCode => Object.hash(name, value);
}

/// Una pregunta a Laya armada por partes: qué se quiere saber, qué tipo de
/// respuesta, las opciones o los niveles, y la evidencia.
class LayaQuestionDraft {
  const LayaQuestionDraft({
    this.kind = LayaQuestionKind.yesNo,
    this.question = '',
    this.options = const [],
    this.levels = const [],
    this.evidence = const [],
  });

  final LayaQuestionKind kind;

  /// Qué se quiere saber.
  final String question;

  /// Solo para [LayaQuestionKind.choice].
  final List<LayaOption> options;

  /// Solo para [LayaQuestionKind.score], de menor a mayor.
  final List<String> levels;

  final List<LayaEvidence> evidence;

  List<LayaOption> get _filledOptions => [
    for (final option in options)
      if (option.name.trim().isNotEmpty)
        LayaOption(
          name: option.name.trim(),
          description: option.description.trim(),
        ),
  ];

  List<String> get _filledLevels => [
    for (final level in levels)
      if (level.trim().isNotEmpty) level.trim(),
  ];

  /// Por qué no se puede enviar todavía, o null si está lista.
  String? get problem {
    if (question.trim().isEmpty) return 'Escribe qué quieres saber.';
    return switch (kind) {
      LayaQuestionKind.choice when _filledOptions.length < 2 =>
        'Hacen falta al menos dos opciones.',
      LayaQuestionKind.score when _filledLevels.length < 2 =>
        'Hacen falta al menos dos niveles.',
      _ => null,
    };
  }

  /// Lo que Laya mira: la evidencia con nombre, o la pregunta sola si no
  /// hay evidencia.
  Map<String, Object?> get state {
    final filled = {
      for (final item in evidence)
        if (item.name.trim().isNotEmpty && item.value.trim().isNotEmpty)
          item.name.trim(): item.value.trim(),
    };
    return filled.isEmpty ? {'text': question.trim()} : filled;
  }

  /// La pregunta en el protocolo de Laya.
  Map<String, Object?> get wireQuestion => {
    'type': kind.wire,
    'instructions': question.trim(),
    if (kind == LayaQuestionKind.choice)
      'criteria': {
        for (final option in _filledOptions)
          option.name: option.description.isEmpty
              ? option.name
              : option.description,
      },
    if (kind == LayaQuestionKind.score) 'criteria': _filledLevels,
  };

  /// El nombre de cada respuesta posible, en el orden en que Laya las
  /// numera (para leer las probabilidades de una escala).
  List<String> get answerNames => switch (kind) {
    LayaQuestionKind.yesNo => const ['sí', 'no'],
    LayaQuestionKind.choice => [
      for (final option in _filledOptions) option.name,
    ],
    LayaQuestionKind.score => _filledLevels,
  };

  /// La pregunta como formulario guardable de una sola pregunta: sus
  /// campos son los nombres de la evidencia.
  LayaForm toForm({required String name}) => LayaForm(
    id: '',
    name: name.trim(),
    updatedAt: DateTime.now(),
    fields: [
      for (final item in evidence)
        if (item.name.trim().isNotEmpty) LayaFormField(name: item.name.trim()),
    ],
    questions: [
      LayaFormQuestion(
        id: 'q1',
        text: question.trim(),
        kind: switch (kind) {
          LayaQuestionKind.yesNo => LayaAnswerKind.yesNo,
          LayaQuestionKind.choice => LayaAnswerKind.choice,
          LayaQuestionKind.score => LayaAnswerKind.score,
        },
        options: [
          for (final option in _filledOptions)
            LayaFormOption(name: option.name, description: option.description),
        ],
        levels: _filledLevels,
      ),
    ],
  );

  LayaQuestionDraft copyWith({
    LayaQuestionKind? kind,
    String? question,
    List<LayaOption>? options,
    List<String>? levels,
    List<LayaEvidence>? evidence,
  }) => LayaQuestionDraft(
    kind: kind ?? this.kind,
    question: question ?? this.question,
    options: options ?? this.options,
    levels: levels ?? this.levels,
    evidence: evidence ?? this.evidence,
  );

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'question': question,
    'options': [for (final o in options) o.toJson()],
    'levels': levels,
    'evidence': [for (final e in evidence) e.toJson()],
  };

  factory LayaQuestionDraft.fromJson(Map<String, Object?> json) =>
      LayaQuestionDraft(
        kind:
            LayaQuestionKind.values.asNameMap()[json['kind']] ??
            LayaQuestionKind.yesNo,
        question: json['question'] as String? ?? '',
        options: [
          for (final o in json['options'] as List? ?? const [])
            LayaOption.fromJson((o as Map).cast<String, Object?>()),
        ],
        levels: [for (final l in json['levels'] as List? ?? const []) '$l'],
        evidence: [
          for (final e in json['evidence'] as List? ?? const [])
            LayaEvidence.fromJson((e as Map).cast<String, Object?>()),
        ],
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayaQuestionDraft &&
          other.kind == kind &&
          other.question == question &&
          _same(other.options, options) &&
          _same(other.levels, levels) &&
          _same(other.evidence, evidence);

  @override
  int get hashCode => Object.hash(
    kind,
    question,
    Object.hashAll(options),
    Object.hashAll(levels),
    Object.hashAll(evidence),
  );
}

bool _same<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Una pregunta del mini chat y lo que contestó Laya.
class LayaExchange {
  const LayaExchange({
    required this.draft,
    required this.at,
    this.answer,
    this.probabilities = const {},
    this.confidence,
    this.error = '',
    this.pending = false,
  });

  /// Lo que se preguntó, tal cual, para poder repetirlo.
  final LayaQuestionDraft draft;
  final DateTime at;

  /// La respuesta elegida: «sí»/«no», el nombre de la opción o el nivel.
  final String? answer;

  /// Cada respuesta posible con su probabilidad, la más alta primero.
  final Map<String, double> probabilities;

  /// Qué tan segura está Laya, 0–1.
  final double? confidence;

  final String error;

  /// Todavía esperando la respuesta.
  final bool pending;

  /// Por debajo de 0.5 Laya no sabe: se dice así.
  bool get unsure => (confidence ?? 0) < 0.5;

  /// La respuesta en una línea, con la probabilidad de lo que dice.
  String get headline {
    final chosen = answer;
    if (chosen == null) return '—';
    final probability = probabilities[chosen];
    final label = '${chosen[0].toUpperCase()}${chosen.substring(1)}';
    return probability == null
        ? label
        : '$label — ${(probability * 100).round()} %';
  }

  LayaExchange copyWith({
    LayaQuestionDraft? draft,
    DateTime? at,
    String? answer,
    Map<String, double>? probabilities,
    double? confidence,
    String? error,
    bool? pending,
  }) => LayaExchange(
    draft: draft ?? this.draft,
    at: at ?? this.at,
    answer: answer ?? this.answer,
    probabilities: probabilities ?? this.probabilities,
    confidence: confidence ?? this.confidence,
    error: error ?? this.error,
    pending: pending ?? this.pending,
  );

  Map<String, Object?> toJson() => {
    'draft': draft.toJson(),
    'at': at.toIso8601String(),
    'answer': answer,
    'probabilities': probabilities,
    'confidence': confidence,
    'error': error,
    'pending': pending,
  };

  factory LayaExchange.fromJson(Map<String, Object?> json) => LayaExchange(
    draft: LayaQuestionDraft.fromJson(
      (json['draft'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
    at: DateTime.tryParse(json['at'] as String? ?? '') ?? DateTime.now(),
    answer: json['answer'] as String?,
    probabilities: {
      for (final MapEntry(:key, :value)
          in ((json['probabilities'] as Map?) ?? const {}).entries)
        '$key': (value as num).toDouble(),
    },
    confidence: (json['confidence'] as num?)?.toDouble(),
    error: json['error'] as String? ?? '',
    pending: json['pending'] as bool? ?? false,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayaExchange &&
          other.draft == draft &&
          other.at == at &&
          other.answer == answer &&
          other.confidence == confidence &&
          other.error == error &&
          other.pending == pending;

  @override
  int get hashCode =>
      Object.hash(draft, at, answer, confidence, error, pending);
}

/// La última revisión de tareas de un proyecto.
class LayaReview {
  const LayaReview({
    this.loading = false,
    this.verdicts = const [],
    this.error = '',
    this.at,
  });

  final bool loading;

  /// La más probablemente demorada primero.
  final List<LayaTaskVerdict> verdicts;
  final String error;
  final DateTime? at;

  List<LayaTaskVerdict> get delayed => [
    for (final verdict in verdicts)
      if (verdict.isDelayed) verdict,
  ];

  int get onTrack => verdicts.length - delayed.length;

  LayaReview copyWith({
    bool? loading,
    List<LayaTaskVerdict>? verdicts,
    String? error,
    DateTime? at,
  }) => LayaReview(
    loading: loading ?? this.loading,
    verdicts: verdicts ?? this.verdicts,
    error: error ?? this.error,
    at: at ?? this.at,
  );

  Map<String, Object?> toJson() => {
    'loading': loading,
    'verdicts': [for (final v in verdicts) v.toJson()],
    'error': error,
    'at': at?.toIso8601String(),
  };

  factory LayaReview.fromJson(Map<String, Object?> json) => LayaReview(
    loading: json['loading'] as bool? ?? false,
    verdicts: [
      for (final v in json['verdicts'] as List? ?? const [])
        LayaTaskVerdict.fromJson((v as Map).cast<String, Object?>()),
    ],
    error: json['error'] as String? ?? '',
    at: DateTime.tryParse(json['at'] as String? ?? ''),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayaReview &&
          other.loading == loading &&
          identical(other.verdicts, verdicts) &&
          other.error == error &&
          other.at == at;

  @override
  int get hashCode => Object.hash(loading, verdicts.length, error, at);
}

/// Laya en la app: si está configurada, las revisiones de tareas por
/// proyecto y el mini chat.
class LayaState {
  const LayaState({
    this.configured = false,
    this.reviews = const {},
    this.chat = const [],
    this.focusFormId,
  });

  /// La bóveda tiene LAYA_URL y LAYA_API_KEY. Sin eso, Laya no aparece.
  final bool configured;

  /// Por carpeta de proyecto.
  final Map<String, LayaReview> reviews;

  /// Lo preguntado en esta corrida de la app, el más viejo primero.
  final List<LayaExchange> chat;

  /// El formulario que el panel tiene que abrir: el que Keel AI acaba de
  /// crear, o el que el usuario eligió en la lista.
  final String? focusFormId;

  LayaReview reviewOf(String projectPath) =>
      reviews[projectPath] ?? const LayaReview();

  bool get asking => chat.any((exchange) => exchange.pending);

  LayaState copyWith({
    bool? configured,
    Map<String, LayaReview>? reviews,
    List<LayaExchange>? chat,
    String? focusFormId,
    bool clearFocus = false,
  }) => LayaState(
    configured: configured ?? this.configured,
    reviews: reviews ?? this.reviews,
    chat: chat ?? this.chat,
    focusFormId: clearFocus ? null : focusFormId ?? this.focusFormId,
  );

  Map<String, Object?> toJson() => {
    'configured': configured,
    'reviews': {for (final e in reviews.entries) e.key: e.value.toJson()},
    'chat': [for (final e in chat) e.toJson()],
    'focusFormId': focusFormId,
  };

  factory LayaState.fromJson(Map<String, Object?> json) => LayaState(
    configured: json['configured'] as bool? ?? false,
    reviews: {
      for (final MapEntry(:key, :value)
          in ((json['reviews'] as Map?) ?? const {}).entries)
        '$key': LayaReview.fromJson((value as Map).cast<String, Object?>()),
    },
    chat: [
      for (final e in json['chat'] as List? ?? const [])
        LayaExchange.fromJson((e as Map).cast<String, Object?>()),
    ],
    focusFormId: json['focusFormId'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LayaState &&
          other.configured == configured &&
          identical(other.reviews, reviews) &&
          identical(other.chat, chat) &&
          other.focusFormId == focusFormId;

  @override
  int get hashCode =>
      Object.hash(configured, reviews.length, chat.length, focusFormId);
}
