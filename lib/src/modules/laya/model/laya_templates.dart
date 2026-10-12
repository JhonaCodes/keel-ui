import 'package:keel_core/integrations/laya/laya.dart';
import 'package:keel_ui/src/modules/laya/model/laya_state.dart';

/// Preguntas ya armadas: se eligen, se completa la evidencia y se pregunta.
/// En inglés, como todo lo que se le manda a Laya.
class LayaTemplate {
  const LayaTemplate({required this.label, required this.draft});

  /// Cómo se ve en el desplegable, en el idioma de la app.
  final String label;
  final LayaQuestionDraft draft;

  @override
  bool operator ==(Object other) =>
      other is LayaTemplate && other.label == label && other.draft == draft;

  @override
  int get hashCode => Object.hash(label, draft);
}

abstract final class LayaTemplates {
  static final all = <LayaTemplate>[
    const LayaTemplate(
      label: '¿Está demorada esta tarea?',
      draft: LayaQuestionDraft(
        question:
            'Is this task delayed? Consider the days without changes, its '
            'state and its notes.',
        evidence: [
          LayaEvidence(name: 'task', value: ''),
          LayaEvidence(name: 'state', value: 'in progress'),
          LayaEvidence(name: 'last_change', value: ''),
          LayaEvidence(name: 'today', value: ''),
          LayaEvidence(name: 'notes', value: ''),
        ],
      ),
    ),
    LayaTemplate(
      label: '¿Qué hacer con esta tarea?',
      draft: LayaQuestionDraft(
        kind: LayaQuestionKind.choice,
        question: 'What is the best thing to do with this task now?',
        options: [
          for (final MapEntry(:key, :value) in kLayaTaskActions.entries)
            LayaOption(name: key, description: value),
        ],
        evidence: const [
          LayaEvidence(name: 'task', value: ''),
          LayaEvidence(name: 'state', value: ''),
          LayaEvidence(name: 'notes', value: ''),
        ],
      ),
    ),
    const LayaTemplate(
      label: '¿Este log es un fallo de autenticación?',
      draft: LayaQuestionDraft(
        question: 'Is this an authentication failure?',
        evidence: [LayaEvidence(name: 'log', value: '')],
      ),
    ),
    const LayaTemplate(
      label: '¿Este diff cambia la API pública?',
      draft: LayaQuestionDraft(
        question:
            'Does this diff change the public API (signatures, endpoints or '
            'payloads that callers depend on)?',
        evidence: [LayaEvidence(name: 'diff', value: '')],
      ),
    ),
    const LayaTemplate(
      label: '¿Qué tipo de ticket es?',
      draft: LayaQuestionDraft(
        kind: LayaQuestionKind.choice,
        question: 'What kind of ticket is this?',
        options: [
          LayaOption(
            name: 'bug',
            description: 'something that worked is broken',
          ),
          LayaOption(name: 'feature', description: 'asks for something new'),
          LayaOption(name: 'question', description: 'asks how something works'),
          LayaOption(
            name: 'billing',
            description: 'about payments or invoices',
          ),
        ],
        evidence: [LayaEvidence(name: 'ticket', value: '')],
      ),
    ),
    const LayaTemplate(
      label: '¿Qué tan grave es este error? (escala)',
      draft: LayaQuestionDraft(
        kind: LayaQuestionKind.score,
        question: 'How severe is this error for the people using the app?',
        levels: [
          'cosmetic',
          'annoying but has a workaround',
          'blocks one feature',
          'blocks the whole app',
        ],
        evidence: [LayaEvidence(name: 'error', value: '')],
      ),
    ),
  ];
}
