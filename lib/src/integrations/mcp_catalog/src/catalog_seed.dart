part of '../mcp_catalog.dart';

/// Las integraciones que el catálogo conoce.
///
/// Criterio para entrar: que su documentación oficial publique la
/// configuración, y que se pueda usar desde Keel. Los que piden OAuth entran
/// igual —son demasiados para esconderlos— pero lo dicen en la ficha, porque
/// con `--strict-mcp-config` un servidor autenticado por fuera no se ve
/// desde acá y enterarse tarde es peor que no verlo en la lista.
const kMcpCatalog = <McpCatalogEntry>[
  // ── Trabajo y equipo ───────────────────────────────────────────────
  McpCatalogEntry(
    id: 'github',
    name: 'GitHub',
    tagline: 'Issues, pull requests y código',
    category: McpCatalogCategory.trabajo,
    auth: McpCatalogAuth.token,
    transport: McpTransport.http,
    serverName: 'github',
    url: 'https://api.githubcopilot.com/mcp/',
    headers: {'Authorization': 'Bearer {{GITHUB_TOKEN}}'},
    credentials: [
      McpCredential(
        name: 'GITHUB_TOKEN',
        label: 'Personal access token',
        hint:
            'GitHub → Settings → Developer settings → Personal access tokens. '
            'Con permiso de repo alcanza para issues y PRs.',
      ),
    ],
    docsUrl: 'https://github.com/github/github-mcp-server',
    glyph: 'GH',
    colorIndex: 0,
  ),
  McpCatalogEntry(
    id: 'linear',
    name: 'Linear',
    tagline: 'Issues, ciclos y proyectos',
    category: McpCatalogCategory.trabajo,
    auth: McpCatalogAuth.oauth,
    transport: McpTransport.http,
    serverName: 'linear',
    url: 'https://mcp.linear.app/mcp',
    headers: {'Authorization': 'Bearer {{LINEAR_API_KEY}}'},
    credentials: [
      McpCredential(
        name: 'LINEAR_API_KEY',
        label: 'Personal API key',
        hint:
            'Linear → Settings → API → Personal API keys. Empieza con '
            'lin_api_.',
      ),
    ],
    note:
        'El servidor de Linear está pensado para OAuth. Si rechaza el token '
        'con un 401, la salida es usar su API key personal o consultarlo '
        'desde su documentación.',
    docsUrl: 'https://linear.app/docs/mcp',
    glyph: 'LN',
    colorIndex: 2,
  ),
  McpCatalogEntry(
    id: 'atlassian',
    name: 'Atlassian',
    tagline: 'Jira y Confluence',
    category: McpCatalogCategory.trabajo,
    auth: McpCatalogAuth.oauth,
    transport: McpTransport.sse,
    serverName: 'atlassian',
    url: 'https://mcp.atlassian.com/v1/sse',
    note:
        'Autentica por OAuth en el navegador, que es un flujo que Keel no '
        'puede completar. Anda si tu organización habilita un token de API; '
        'probalo antes de asignárselo a un agente.',
    docsUrl: 'https://support.atlassian.com/rovo/docs/setting-up-ides/',
    glyph: 'AT',
    colorIndex: 2,
  ),
  McpCatalogEntry(
    id: 'slack',
    name: 'Slack',
    tagline: 'Canales, hilos y mensajes',
    category: McpCatalogCategory.trabajo,
    auth: McpCatalogAuth.token,
    transport: McpTransport.stdio,
    serverName: 'slack',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-slack'],
    secretEnv: {
      'SLACK_BOT_TOKEN': 'SLACK_BOT_TOKEN',
      'SLACK_TEAM_ID': 'SLACK_TEAM_ID',
    },
    credentials: [
      McpCredential(
        name: 'SLACK_BOT_TOKEN',
        label: 'Bot user OAuth token',
        hint:
            'api.slack.com/apps → tu app → OAuth & Permissions. Empieza con '
            'xoxb-.',
      ),
      McpCredential(
        name: 'SLACK_TEAM_ID',
        label: 'Team ID',
        hint: 'El identificador del workspace, empieza con T.',
      ),
    ],
    docsUrl:
        'https://github.com/modelcontextprotocol/servers/tree/main/src/slack',
    glyph: 'SL',
    colorIndex: 4,
  ),
  McpCatalogEntry(
    id: 'notion',
    name: 'Notion',
    tagline: 'Páginas y bases de datos',
    category: McpCatalogCategory.trabajo,
    auth: McpCatalogAuth.oauth,
    transport: McpTransport.http,
    serverName: 'notion',
    url: 'https://mcp.notion.com/mcp',
    headers: {'Authorization': 'Bearer {{NOTION_TOKEN}}'},
    credentials: [
      McpCredential(
        name: 'NOTION_TOKEN',
        label: 'Internal integration secret',
        hint:
            'notion.so/profile/integrations → nueva integración. Después hay '
            'que compartirle las páginas a mano.',
      ),
    ],
    note:
        'El servidor alojado autentica por OAuth. La vuelta que sí funciona '
        'desde Keel es crear una integración interna en tu workspace y usar '
        'su secret como token: hay que compartirle a mano cada página que '
        'quieras que vea.',
    docsUrl: 'https://developers.notion.com/docs/mcp',
    glyph: 'NO',
    colorIndex: 7,
  ),
  McpCatalogEntry(
    id: 'gmail',
    name: 'Gmail',
    tagline: 'Leer, buscar y redactar correo',
    category: McpCatalogCategory.trabajo,
    auth: McpCatalogAuth.archivo,
    transport: McpTransport.stdio,
    serverName: 'gmail',
    command: 'npx',
    args: ['-y', '@gongrzhe/server-gmail-autoauth-mcp'],
    note:
        'No hay servidor oficial de Google para Gmail: este es de la '
        'comunidad y pide autorizar una vez con las credenciales OAuth de un '
        'proyecto tuyo de Google Cloud. Leé su README antes de darle acceso a '
        'tu correo.',
    docsUrl: 'https://github.com/GongRzhe/Gmail-MCP-Server',
    glyph: 'GM',
    colorIndex: 6,
  ),

  // ── Datos y nube ───────────────────────────────────────────────────
  McpCatalogEntry(
    id: 'postgres',
    name: 'Postgres',
    tagline: 'Consultas de solo lectura',
    category: McpCatalogCategory.datos,
    auth: McpCatalogAuth.token,
    transport: McpTransport.stdio,
    serverName: 'postgres',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-postgres'],
    secretEnv: {'DATABASE_URL': 'DATABASE_URL'},
    credentials: [
      McpCredential(
        name: 'DATABASE_URL',
        label: 'Cadena de conexión',
        hint:
            'postgres://usuario:clave@host:5432/base. Usá un usuario de solo '
            'lectura: el servidor no distingue.',
      ),
    ],
    docsUrl:
        'https://github.com/modelcontextprotocol/servers/tree/main/src/postgres',
    glyph: 'PG',
    colorIndex: 1,
  ),
  McpCatalogEntry(
    id: 'gdrive',
    name: 'Google Drive',
    tagline: 'Buscar y leer documentos',
    category: McpCatalogCategory.datos,
    auth: McpCatalogAuth.archivo,
    transport: McpTransport.stdio,
    serverName: 'gdrive',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-gdrive'],
    note:
        'Pide autorizar una vez contra un proyecto de Google Cloud tuyo; las '
        'credenciales quedan en un archivo local que el servidor lee.',
    docsUrl:
        'https://github.com/modelcontextprotocol/servers/tree/main/src/gdrive',
    glyph: 'DR',
    colorIndex: 3,
  ),
  McpCatalogEntry(
    id: 'stripe',
    name: 'Stripe',
    tagline: 'Pagos, clientes y suscripciones',
    category: McpCatalogCategory.datos,
    auth: McpCatalogAuth.token,
    transport: McpTransport.stdio,
    serverName: 'stripe',
    command: 'npx',
    args: ['-y', '@stripe/mcp', '--tools=all'],
    secretEnv: {'STRIPE_SECRET_KEY': 'STRIPE_SECRET_KEY'},
    credentials: [
      McpCredential(
        name: 'STRIPE_SECRET_KEY',
        label: 'Secret key',
        hint:
            'Stripe → Developers → API keys. Para probar, la de test: '
            'empieza con sk_test_.',
      ),
    ],
    docsUrl: 'https://docs.stripe.com/mcp',
    glyph: 'ST',
    colorIndex: 7,
  ),
  McpCatalogEntry(
    id: 'sentry',
    name: 'Sentry',
    tagline: 'Errores, trazas y releases',
    category: McpCatalogCategory.datos,
    auth: McpCatalogAuth.oauth,
    transport: McpTransport.http,
    serverName: 'sentry',
    url: 'https://mcp.sentry.dev/mcp',
    headers: {'Authorization': 'Bearer {{SENTRY_TOKEN}}'},
    credentials: [
      McpCredential(
        name: 'SENTRY_TOKEN',
        label: 'User auth token',
        hint:
            'Sentry → Settings → Auth Tokens. Con lectura de issues y '
            'proyectos alcanza.',
      ),
    ],
    note:
        'Está pensado para OAuth. Con un token de usuario suele andar; si da '
        '401, es eso.',
    docsUrl: 'https://docs.sentry.io/product/sentry-mcp/',
    glyph: 'SE',
    colorIndex: 5,
  ),

  // ── Código y documentación ─────────────────────────────────────────
  McpCatalogEntry(
    id: 'context7',
    name: 'Context7',
    tagline: 'Documentación de librerías al día',
    category: McpCatalogCategory.codigo,
    auth: McpCatalogAuth.ninguna,
    transport: McpTransport.stdio,
    serverName: 'context7',
    command: 'npx',
    args: ['-y', '@upstash/context7-mcp'],
    docsUrl: 'https://github.com/upstash/context7',
    glyph: 'C7',
    colorIndex: 4,
  ),
  McpCatalogEntry(
    id: 'filesystem',
    name: 'Filesystem',
    tagline: 'Carpetas fuera del proyecto',
    category: McpCatalogCategory.codigo,
    auth: McpCatalogAuth.ninguna,
    transport: McpTransport.stdio,
    serverName: 'filesystem',
    command: 'npx',
    args: ['-y', '@modelcontextprotocol/server-filesystem'],
    note:
        'Los argumentos son las rutas que expone, y hay que agregarlas: sin '
        'ninguna no sirve de nada. Cada carpeta que sumes queda legible para '
        'todo agente que lo tenga asignado.',
    docsUrl:
        'https://github.com/modelcontextprotocol/servers/tree/main/src/filesystem',
    glyph: 'FS',
    colorIndex: 3,
  ),

  // ── Navegador y diseño ─────────────────────────────────────────────
  McpCatalogEntry(
    id: 'playwright',
    name: 'Playwright',
    tagline: 'Un navegador de verdad',
    category: McpCatalogCategory.navegador,
    auth: McpCatalogAuth.ninguna,
    transport: McpTransport.stdio,
    serverName: 'playwright',
    command: 'npx',
    args: ['-y', '@playwright/mcp@latest'],
    docsUrl: 'https://github.com/microsoft/playwright-mcp',
    glyph: 'PW',
    colorIndex: 1,
  ),
  McpCatalogEntry(
    id: 'figma',
    name: 'Figma',
    tagline: 'Archivos y nodos de diseño',
    category: McpCatalogCategory.navegador,
    auth: McpCatalogAuth.token,
    transport: McpTransport.stdio,
    serverName: 'figma',
    command: 'npx',
    args: ['-y', 'figma-developer-mcp', '--stdio'],
    secretEnv: {'FIGMA_API_KEY': 'FIGMA_API_KEY'},
    credentials: [
      McpCredential(
        name: 'FIGMA_API_KEY',
        label: 'Personal access token',
        hint: 'Figma → Settings → Security → Personal access tokens.',
      ),
    ],
    note:
        'Es de la comunidad. Figma también publica un servidor propio que '
        'corre local con la app de escritorio abierta; si preferís ese, '
        'registralo como remoto contra su URL local.',
    docsUrl: 'https://github.com/GLips/Figma-Context-MCP',
    glyph: 'FI',
    colorIndex: 5,
  ),
];
