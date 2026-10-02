/// What the channel is showing: the conversation, the same conversation
/// drawn as a network, or the live keel-e2e panel.
///
/// `e2e` is always there (the user's decision, 2026-10-02, architecture
/// §14): a step that runs keel-e2e must never end up without its tab
/// because of how its workflow was declared. Without a run in progress its
/// stage shows the waiting state, never the device live.
enum SessionTab {
  chat,
  map,
  e2e;

  /// The tabs every session shows, in display order.
  static const List<SessionTab> available = [
    SessionTab.chat,
    SessionTab.map,
    SessionTab.e2e,
  ];

  /// What to actually render for this choice, given [available]: itself
  /// when it is still on the list, else the first tab (`chat`). A session
  /// stuck on `e2e` after its workflow stops declaring keel-e2e — or before
  /// it ever did — must not render a tab that no longer exists.
  SessionTab effective(List<SessionTab> available) =>
      available.contains(this) ? this : available.first;
}
