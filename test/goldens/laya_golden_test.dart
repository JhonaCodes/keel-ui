import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:keel_core/integrations/laya/laya.dart';
import 'package:keel_core/modules/laya_forms/model/laya_form.dart';
import 'package:keel_ui/src/core/ui/app_theme.dart';
import 'package:keel_ui/src/modules/laya/model/laya_state.dart';
import 'package:keel_ui/src/modules/laya/model/laya_templates.dart';
import 'package:keel_ui/src/modules/laya/ui/screen/laya_chat_panel.dart';
import 'package:keel_ui/src/modules/laya/ui/widget/laya_task_review.dart';

/// Cómo se ve Laya: una tarea demorada con sus opciones, y el mini chat
/// con una respuesta segura y una dudosa.
final _productFont = File('/System/Library/Fonts/Supplemental/Arial.ttf');
final _pubCache =
    Platform.environment['PUB_CACHE'] ??
    '${Platform.environment['HOME']}/.pub-cache';
final _materialIconsFont = File(
  '$_pubCache/hosted/pub.dev/provider-6.1.2/'
  'extension/devtools/build/assets/fonts/MaterialIcons-Regular.otf',
);

void main() {
  setUpAll(() async {
    if (!await _productFont.exists()) return;
    final bytes = ByteData.sublistView(await _productFont.readAsBytes());
    for (final family in ['GoldenArial', 'monospace']) {
      await (FontLoader(family)..addFont(Future.value(bytes))).load();
    }
    if (await _materialIconsFont.exists()) {
      final icons = ByteData.sublistView(
        await _materialIconsFont.readAsBytes(),
      );
      await (FontLoader('MaterialIcons')..addFont(Future.value(icons))).load();
    }
  });

  testWidgets('laya golden', (tester) async {
    tester.view.physicalSize = const Size(560, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = buildAppTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'GoldenArial'),
        ),
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const LayaTaskVerdictRow(
                verdict: LayaTaskVerdict(
                  taskPath: '02-auth/03-oauth-pkce.md',
                  title: 'Migrar el login a OAuth2 PKCE',
                  state: 'En curso',
                  daysIdle: 19,
                  delayed: 0.94,
                  action: 'unblock',
                  actionConfidence: 0.71,
                  options: {
                    'unblock': 0.9,
                    'continue': 0.06,
                    'close': 0.03,
                    'split': 0.01,
                    'reprioritize': 0.0,
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/laya.png'),
    );
  }, skip: !_productFont.existsSync());

  Future<void> panel(
    WidgetTester tester,
    Widget child, {
    Size size = const Size(520, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final theme = buildAppTheme();
    await tester.pumpWidget(
      MaterialApp(
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(fontFamily: 'GoldenArial'),
        ),
        home: child,
      ),
    );
  }

  Future<String?> noAsk(LayaQuestionDraft draft) async => null;
  Future<LayaFormRun> noAskForm(LayaForm form, Map<String, String> v) async =>
      LayaFormRun(formId: form.id, at: DateTime(2026, 10, 13));

  final at = DateTime(2026, 9, 1, 10, 42);
  final ticketForm = LayaForm(
    id: 'f1',
    name: '¿Qué tipo de ticket es?',
    description: 'Clasifica un ticket de soporte antes de asignarlo.',
    createdBy: 'keel-ai',
    updatedAt: at,
    fields: const [
      LayaFormField(name: 'ticket', hint: 'pega el texto del ticket'),
      LayaFormField(name: 'customer_plan', hint: 'free, pro, enterprise'),
    ],
    questions: const [
      LayaFormQuestion(
        id: 'kind',
        kind: LayaAnswerKind.choice,
        text: 'What kind of ticket is this?',
        options: [
          LayaFormOption(
            name: 'bug',
            description: 'something that worked is broken',
          ),
          LayaFormOption(
            name: 'feature',
            description: 'asks for something new',
          ),
          LayaFormOption(
            name: 'question',
            description: 'asks how something works',
          ),
        ],
      ),
      LayaFormQuestion(id: 'urgent', text: 'Does it block the customer?'),
    ],
  );
  final forms = [
    ticketForm,
    LayaForm(
      id: 'f2',
      name: 'Is this an authentication failure?',
      updatedAt: at,
      fields: const [LayaFormField(name: 'log')],
      questions: const [
        LayaFormQuestion(id: 'q1', text: 'Is this an authentication failure?'),
      ],
    ),
  ];
  final runs = {
    'f1': LayaFormRun(
      formId: 'f1',
      at: at,
      values: const {
        'ticket': 'cannot login, getting 500 error since this morning',
        'customer_plan': 'pro',
      },
      answers: const [
        LayaFormAnswer(
          questionId: 'kind',
          answer: 'bug',
          probabilities: {'bug': 0.81, 'question': 0.12, 'feature': 0.07},
          confidence: 0.74,
        ),
        LayaFormAnswer(
          questionId: 'urgent',
          answer: 'yes',
          probabilities: {'yes': 0.88, 'no': 0.12},
          confidence: 0.88,
        ),
      ],
    ),
  };

  Widget view({
    List<LayaExchange> chat = const [],
    bool asking = false,
    LayaQuestionDraft? draft,
    int tab = 0,
    String? focus,
  }) => LayaPanelView(
    chat: chat,
    asking: asking,
    forms: forms,
    runs: runs,
    onAsk: noAsk,
    onSaveForm: (_) => null,
    onClear: () {},
    onAskForm: noAskForm,
    onDuplicateForm: (_) {},
    onDeleteForm: (_) {},
    initialDraft: draft,
    initialTab: tab,
    focusFormId: focus,
  );

  testWidgets('laya chat empty golden', (tester) async {
    await panel(tester, view(), size: const Size(560, 800));
    await expectLater(
      find.byType(LayaPanelView),
      matchesGoldenFile('goldens/laya_chat_empty.png'),
    );
  }, skip: !_productFont.existsSync());

  testWidgets('laya chat choice form golden', (tester) async {
    await panel(
      tester,
      view(
        draft: LayaTemplates.all
            .firstWhere((t) => t.label.startsWith('¿Qué tipo'))
            .draft
            .copyWith(
              evidence: const [
                LayaEvidence(
                  name: 'ticket',
                  value: 'cannot login, getting 500 error since this morning',
                ),
              ],
            ),
      ),
      size: const Size(560, 1060),
    );
    await expectLater(
      find.byType(LayaPanelView),
      matchesGoldenFile('goldens/laya_chat_choice.png'),
    );
  }, skip: !_productFont.existsSync());

  testWidgets('laya forms list golden', (tester) async {
    await panel(tester, view(tab: 1), size: const Size(560, 420));
    await expectLater(
      find.byType(LayaPanelView),
      matchesGoldenFile('goldens/laya_forms.png'),
    );
  }, skip: !_productFont.existsSync());

  testWidgets('laya form fill golden', (tester) async {
    await panel(tester, view(focus: 'f1'), size: const Size(560, 900));
    await tester.pump();
    await expectLater(
      find.byType(LayaPanelView),
      matchesGoldenFile('goldens/laya_form_fill.png'),
    );
  }, skip: !_productFont.existsSync());

  testWidgets('laya chat conversation golden', (tester) async {
    const ticket = LayaQuestionDraft(
      kind: LayaQuestionKind.choice,
      question: 'What kind of ticket is this?',
      options: [
        LayaOption(name: 'bug', description: 'something that worked is broken'),
        LayaOption(name: 'feature', description: 'asks for something new'),
        LayaOption(name: 'question', description: 'asks how something works'),
      ],
      evidence: [
        LayaEvidence(name: 'ticket', value: 'cannot login, getting 500 error'),
      ],
    );
    await panel(
      tester,
      view(
        asking: true,
        chat: [
          LayaExchange(
            draft: const LayaQuestionDraft(
              question: 'Is this an authentication failure?',
              evidence: [
                LayaEvidence(name: 'log', value: '401 invalid token at /auth'),
              ],
            ),
            at: at,
            answer: 'sí',
            probabilities: const {'sí': 0.93, 'no': 0.07},
            confidence: 0.93,
          ),
          LayaExchange(
            draft: ticket,
            at: at,
            answer: 'bug',
            probabilities: const {
              'bug': 0.81,
              'question': 0.12,
              'feature': 0.07,
            },
            confidence: 0.74,
          ),
          LayaExchange(
            draft: const LayaQuestionDraft(
              question: 'Is this task blocked by something external?',
            ),
            at: at,
            pending: true,
          ),
        ],
      ),
    );
    await expectLater(
      find.byType(LayaPanelView),
      matchesGoldenFile('goldens/laya_chat.png'),
    );
  }, skip: !_productFont.existsSync());
}
