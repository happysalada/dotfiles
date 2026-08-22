# Tridactyl's config file, as a text template.
#
# IMPORTANT: the extension does not read this file by itself. It shells out to
# the native messenger to read it at startup, so this only takes effect because
# firefox.nix puts `pkgs.tridactyl-native` in
# `programs.firefox.nativeMessagingHosts`. Drop that and Tridactyl silently
# falls back to whatever is in its own extension storage, and this file is dead
# weight.
#
# Tridactyl re-reads it on `:source`, so most edits need no Firefox restart -
# but the file is a read-only store symlink, so edit it here and `switch`.
{ pkgs }:
''
  " Ex commands, one per line. `"` starts a comment.

  " Wipe anything set by a previous run so this file is the single source of
  " truth. Tridactyl persists config in extension storage, so without this a
  " `blacklistadd` or `bind` deleted here would live on forever.
  sanitise tridactyllocal tridactylsync

  " -------------------------------------------------------------------
  " sites where Tridactyl gets out of the way
  " -------------------------------------------------------------------
  " claude.ai: the composer is a contenteditable and the app binds Escape
  " itself, so Tridactyl's normal/insert mode fights it - keystrokes get eaten
  " after the SPA re-renders and blurs the box.
  "
  " `blacklistadd` puts Tridactyl in ignore mode on load (every key goes
  " straight to the page) and `noiframe` stops the command-line iframe being
  " injected at all.
  "
  " Deliberately NOT `seturl ^https://claude\.ai superignore true`: superignore
  " is more thorough but it also kills the escape hatch, so there is no way to
  " turn Tridactyl back on for a page. With the pair below, Shift+Insert still
  " flips to normal mode on the rare occasion you want `f` to click something.
  blacklistadd claude.ai
  seturl ^https://claude\.ai noiframe true

  " More sites go the same way, e.g.:
  " blacklistadd mail.google.com/mail

  " -------------------------------------------------------------------
  " tab and history navigation
  " -------------------------------------------------------------------
  " Key names are KeyboardEvent.key values, so it is <A-ArrowUp>, not <A-Up>.
  "
  " Alt+Up/Down walks the tab list (up = towards the top of Sidebery's list).
  " Also bound in insert and ignore mode so it keeps working while the cursor
  " is in a text box and on the blacklisted sites above - Tridactyl's default
  " J/K do not, since they are plain letters.
  bind <A-ArrowUp> tabprev
  bind <A-ArrowDown> tabnext
  bind --mode=insert <A-ArrowUp> tabprev
  bind --mode=insert <A-ArrowDown> tabnext
  bind --mode=ignore <A-ArrowUp> tabprev
  bind --mode=ignore <A-ArrowDown> tabnext

  " Alt+Left/Right for back/forward. Firefox binds these natively already, so
  " these two lines only make it explicit and consistent with Tridactyl's own
  " H/L. Normal mode only for that reason: the native binding still covers
  " insert and ignore. If you ever see a *double* back, one of the two is not
  " being suppressed - drop these lines and let Firefox own it.
  bind <A-ArrowLeft> back
  bind <A-ArrowRight> forward

  " -------------------------------------------------------------------
  " scrolling
  " -------------------------------------------------------------------
  " Tridactyl leaves the bare arrows unbound in normal mode (it only claims
  " them in the command line and in hint mode) and lets the page have them.
  " That works until focus lands on a widget that swallows them - a code
  " viewer, a custom scroll container - and then the page just sits there.
  " Binding them makes the scroll unconditional. 10 lines is not arbitrary:
  " it is what Tridactyl's own j/k and <C-e>/<C-y> use, so every way of
  " scrolling moves the same distance.
  "
  " Normal mode only, deliberately. In insert mode the arrows have to keep
  " moving the caret in the text box, and in ignore mode - claude.ai and
  " anything else blacklisted above - the page has to keep receiving them.
  bind <ArrowDown> scrollline 10
  bind <ArrowUp> scrollline -10

  " -------------------------------------------------------------------
  " appearance
  " -------------------------------------------------------------------
  " the stock theme is light; this matches the black chrome from firefox.nix
  colourscheme dark

  " `f` labels every link with a letter overlay you type to follow it. The
  " default `short` gives single-letter labels to the first 26 targets and
  " only grows past that, which is fewer keystrokes. Uncomment for labels that
  " are always the same width instead:
  " set hintnames uniform

  " -------------------------------------------------------------------
  " Ctrl-i in any text box hands off to the real editor
  " -------------------------------------------------------------------
  " Store paths rather than bare names: the native messenger inherits
  " Firefox's environment, which is not guaranteed to have either on PATH.
  set editorcmd ${pkgs.ghostty}/bin/ghostty -e ${pkgs.helix}/bin/hx %f
''
