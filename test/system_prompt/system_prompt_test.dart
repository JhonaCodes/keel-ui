import 'package:flutter_test/flutter_test.dart';

import 'package:keel_ui/src/integrations/system_prompt/system_prompt.dart';
import 'package:keel_ui/src/modules/mcp_servers/model/mcp_server_config.dart';

McpServerConfig _server({String name = 'algo', String catalogId = ''}) {
  return McpServerConfig(
    id: 'id-$name',
    name: name,
    transport: McpTransport.http,
    url: 'https://example.test/mcp',
    catalogId: catalogId,
    createdAt: DateTime.utc(2026, 1, 1),
  );
}

void main() {
  group('el corpus está completo', () {
    test('ninguna sección quedó vacía al mudarse', () {
      for (final prompt in [
        kKeelAiSystemPrompt,
        kKeelAiSkillContent,
        kRoadmapFormatSkillContent,
        kCliSystemHints,
        kAskVsWorkPrompt,
        kDeliveryPrompt,
        kGithubDeliveryPrompt,
        kGithubMcpPrompt,
        kReadOnlyProjectPrompt,
        kBoardsMcpInstructions,
        kRoadmapMcpInstructions,
        kRequirementsMcpInstructions,
        kSessionPlanMcpInstructions,
        kUserToolsMcpInstructions,
        kKeelAiMcpInstructions,
      ]) {
        expect(prompt.trim(), isNotEmpty);
      }
    });

    test('las dos pistas de CLI viajan juntas y en ese orden', () {
      expect(kCliSystemHints, contains('```mermaid'));
      expect(kCliSystemHints, contains('Write/Edit'));
      expect(
        kCliSystemHints.indexOf('```mermaid'),
        lessThan(kCliSystemHints.indexOf('Write/Edit')),
      );
    });
  });

  group('identidad y compañeros', () {
    test('la identidad nombra handle, rol y proyecto', () {
      final prompt = identityPrompt(
        handle: 'flutter-experto',
        role: 'desarrollo',
        projectName: 'keel-ui',
        projectPurpose: 'la app',
      );
      expect(prompt, contains('SOS @flutter-experto (desarrollo)'));
      expect(prompt, contains('"keel-ui"'));
      expect(prompt, contains('— la app'));
    });

    test('sin propósito no queda el guion suelto', () {
      final prompt = identityPrompt(
        handle: 'a',
        role: 'b',
        projectName: 'c',
        projectPurpose: '',
      );
      expect(prompt, contains('"c". '));
      expect(prompt, isNot(contains('— .')));
    });

    test('la lista de compañeros sale completa y con arroba', () {
      final prompt = companionsPrompt([
        (handle: 'qa', role: 'pruebas'),
        (handle: 'infra', role: 'plataforma'),
      ]);
      expect(prompt, contains('- @qa (pruebas)'));
      expect(prompt, contains('- @infra (plataforma)'));
      expect(prompt, contains('Esa lista de compañeros es completa.'));
    });
  });

  group('GitHub por MCP', () {
    test('el servidor instalado desde el catálogo se reconoce', () {
      expect(isGithubMcpServer(_server(name: 'gh', catalogId: 'github')), true);
    });

    test('uno registrado a mano con ese nombre también', () {
      expect(isGithubMcpServer(_server(name: 'github')), true);
      expect(isGithubMcpServer(_server(name: 'github-enterprise')), true);
    });

    test('cualquier otro no', () {
      expect(isGithubMcpServer(_server(name: 'linear')), false);
      expect(
        isGithubMcpServer(_server(name: 'mi-github-clone')),
        false,
        reason: 'contener la palabra no alcanza: sería un falso positivo',
      );
    });

    test('la entrega por MCP no vuelve a pedir gh', () {
      expect(kDeliveryPrompt, contains('gh pr create'));
      expect(kGithubDeliveryPrompt, isNot(contains('gh pr create')));
      expect(kGithubDeliveryPrompt, contains('draft'));
      expect(kGithubDeliveryPrompt, contains('URL'));
    });

    test('la regla deja `git` en paz: solo reemplaza gh y la API', () {
      expect(kGithubMcpPrompt, contains('local `git`'));
      expect(kGithubMcpPrompt, contains('`gh`'));
      expect(kGithubMcpPrompt, contains('curl'));
    });

    test('prohíbe commitear por el MCP, que es lo que rompe la firma', () {
      // Nombradas una por una: la prohibición genérica no le impidió a un
      // agente rehacer un commit con create_or_update_file «para usar mejor
      // el MCP», y el commit salió sin firma.
      for (final tool in const [
        'create_or_update_file',
        'push_files',
        'create_commit',
        'delete_file',
      ]) {
        expect(kGithubMcpPrompt, contains(tool));
      }
      expect(kGithubMcpPrompt, contains('unsigned'));
      expect(kGithubMcpPrompt, contains('Unverified'));
      expect(
        kGithubMcpPrompt.indexOf('THE LINE'),
        greaterThan(kGithubMcpPrompt.indexOf('GITHUB GOES THROUGH')),
      );
    });
  });

  group('el envoltorio de codex', () {
    test('encierra las instrucciones antes del pedido', () {
      final wrapped = codexRoleWrappedPrompt(
        prompt: 'arreglá el login',
        systemPrompt: 'SOS @qa',
      );
      expect(wrapped.indexOf('SOS @qa'), lessThan(wrapped.indexOf('arreglá')));
      expect(wrapped, contains('### Fin de instrucciones'));
    });
  });
}
