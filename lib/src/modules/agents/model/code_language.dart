const _extensionToLanguage = {
  'dart': 'dart',
  'py': 'python',
  'js': 'javascript',
  'mjs': 'javascript',
  'cjs': 'javascript',
  'jsx': 'javascript',
  'ts': 'typescript',
  'tsx': 'typescript',
  'json': 'json',
  'yaml': 'yaml',
  'yml': 'yaml',
  'md': 'markdown',
  'markdown': 'markdown',
  'sh': 'bash',
  'bash': 'bash',
  'zsh': 'bash',
  'c': 'cpp',
  'h': 'cpp',
  'cc': 'cpp',
  'cpp': 'cpp',
  'hpp': 'cpp',
  'cs': 'cs',
  'go': 'go',
  'rs': 'rust',
  'rb': 'ruby',
  'php': 'php',
  'sql': 'sql',
  'css': 'css',
  'scss': 'scss',
  'html': 'xml',
  'htm': 'xml',
  'xml': 'xml',
  'java': 'java',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'swift': 'swift',
  'm': 'objectivec',
  'mm': 'objectivec',
  'ini': 'ini',
  'properties': 'properties',
  'toml': 'ini',
  'diff': 'diff',
  'patch': 'diff',
  'makefile': 'makefile',
  'gradle': 'gradle',
  'dockerfile': 'dockerfile',
  'lua': 'lua',
  'graphql': 'graphql',
  'proto': 'protobuf',
};

/// Best-effort highlight.js language key for [path]'s extension, or
/// `'plaintext'` when unknown — never `null`, so callers never trigger
/// highlight.js's (slower, occasionally wrong) auto-detection.
String codeLanguageForPath(String path) {
  final fileName = path.split('/').last.toLowerCase();
  if (fileName == 'dockerfile') return 'dockerfile';
  if (fileName == 'makefile') return 'makefile';

  final dot = fileName.lastIndexOf('.');
  if (dot == -1) return 'plaintext';
  final extension = fileName.substring(dot + 1);
  return _extensionToLanguage[extension] ?? 'plaintext';
}
