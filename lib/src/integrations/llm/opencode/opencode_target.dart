/// How Keel reaches OpenCode: its headless server (`opencode serve`). The
/// one-shot `opencode run` cannot ask for permission — it rejects every
/// `ask` on its own — so the server is the only transport that lets a turn
/// wait for the person, like the other providers do.
sealed class OpenCodeTarget {
  const OpenCodeTarget();
}

final class OpenCodeServe extends OpenCodeTarget {
  const OpenCodeServe();
}
