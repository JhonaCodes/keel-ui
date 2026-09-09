# F13 — Images in the chat

## What it is

Attaching images to a message by **dropping them onto the chat** (or with the
image button in the composer). Each attachment shows in the bubble as a
**bounded preview card**, never at full size, and opens large on click.

It applies to the 1:1 chat (`ChatView`), which is the same widget the assistant
panel uses. Projects (`StationChatView`) have their own composer and **do not
yet** accept attachments.

## Flow

1. The user drops one or more files onto the chat area (`desktop_drop`'s
   `DropTarget` wrapping the WHOLE chat, not just the input: you drag against
   the conversation you are reading). While the drag hovers, `ChatDropHint` is
   shown, ignoring pointers so it does not get in the way of the native drop.
2. Anything that is not a supported image is discarded silently — a drag may
   bring folders or PDFs.
3. Each image is **copied into the app's storage** before being shown
   (`ChatAttachmentStore.adoptImages`). This is the point of the feature: a
   screenshot is dropped from a temporary folder the system deletes whenever it
   likes, and a file on the Desktop gets renamed by its owner. The app keeps its
   own copy and never looks at the original path again.
4. The images sit in the composer as a `ChatAttachmentStrip` (64px squares with
   an X). Removing one also deletes the copy: it was not sent, it has no reason
   to survive.
5. On send they travel with the message. A message with **images only** and no
   text is valid — dropping a screenshot and hitting send is the central case.

## How the image reaches the model

By **path, never by bytes**. `AgentsViewModel.sendMessage` adds a
`_describeAttachments` block to the prompt:

```
The user attached 2 images to this message. Read them with the Read tool
before answering:
- /…/chat_attachments/<uuid>.png
- /…/chat_attachments/<uuid>.png
```

The agent reads them with its own `Read` tool (which understands images). A 4 MB
screenshot costs nothing until the model decides to look at it, the prompt stays
text, and the path stays valid because the file lives in the app's storage.

The text shown in the bubble (`ChatMessage.text`) stays clean: the block of
paths is for the model only.

## Model and port

- `ChatMessage.imagePaths` (`List<String>`, serialized): paths inside the app's
  storage.
- `ChatActions.sendMessage(agentId, text, {imagePaths})` — the port carries
  **paths**, so the assistant window's `BridgeChatActions` keeps sending a small
  JSON payload regardless of the image's size. The main-side handler
  (`assistant_window_bridge`) forwards them to the real `AgentsViewModel`.

## Preview UI

`ChatImageAttachments` (above the text in `ChatMessageBody`, so it serves both
the 1:1 bubble and the project one once that accepts attachments):

- A fixed 200×140 card with `BoxFit.cover`. A raw 3000px image would blow out
  the bubble's width and push the text off screen.
- Click → a `Dialog` with an `InteractiveViewer` bounded to 90% of the window
  (informational, with nothing to confirm).
- If the file is gone, it is said in words ("Image unavailable"), not with a
  broken glyph: the message's text still makes sense.

## Storage

`<applicationSupport>/chat_attachments/<uuid>.<ext>`. Accepted formats: png,
jpg, jpeg, gif, webp, bmp — what Flutter can decode AND the model can read, so
that a preview in the bubble always means the agent sees the same thing.

## Known limits

- Deleting a message or an agent does **not** delete its images: they are left
  orphaned in `chat_attachments/`. The same if you switch agent or session with
  staged, unsent attachments (the `ChatView` is keyed by id, and the state is
  rebuilt).
- In the assistant's dedicated window, the native drop depends on `desktop_drop`
  working inside a `desktop_multi_window` sub-window; unverified. The attach
  button does work in both.
- Projects do not accept attachments yet.
- Pasting from the clipboard (⌘V) is not there: the feature is dropping or
  picking.
- `desktop_drop` is a new native plugin — after updating, the app must be
  restarted (hot reload is not enough).
