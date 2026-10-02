# NOT WIRED UP. Disabled after it broke ordinary typing - do not import this
# without fixing what is described below.
#
# defchordsv2 puts every defsrc key into a pending chord queue, so a participant
# is emitted when it is released, or when its chord times out, while a key left
# out of defsrc passes straight through. Two consequences, both of which showed
# up in real typing: participants come out reordered against the unlisted
# letters ("typing" as "typgin", "all" as "lal"), and two participants pressed
# with nothing between them form a chord outright ("the" as "thee"). min-idle
# does not cover the second one - its timer only starts once a key has been
# forwarded the ordinary way, so the first overlapping pair in a burst is never
# guarded.
#
# The chord list below is the part worth keeping. Anything that revives it has
# to keep participants off the ordinary path - chords disabled on the base layer
# and reachable only while a layer key is held - and has to be typed on real
# hardware first, because `--check` proves a config parses and says nothing
# about how it types.
#
# Chorded text expansion, host-side, for the Glove80.
#
# A chord is the word's own letters pressed together: both of them for a
# two-letter word, all three where the pair is already spoken for. kanata
# swallows the keys and emits the word, so `the` costs two keystrokes instead
# of three, and `have` two instead of four. The set is the top of the English
# word list, which is how steno gets its speed too - a brief per word beats
# spelling it out.
#
# Letters are the whole scheme, and that is also its ceiling: a chord is an
# unordered set, so "of" and "for" are the same two keys, and there is no way
# to add a suffix rule the way steno's -S does. A word whose pair is taken
# moves to a third key instead, which is what for, not and that below are.
#
# Not the Glove80's own ZMK combos, which would travel with the keyboard
# instead of living on this machine: those are a firmware build and flash per
# edit, where this is a rebuild that validates the config before it starts.
#
# One keyboard, deliberately. An empty `devices` list grabs every keyboard
# kanata detects, which here is also the ASUS N-KEY device (it carries the
# numpad's mouse interface) and the keyboard Handy holds an exclusive EVIOCGRAB
# on for push-to-talk - an evdev grab is exclusive per device, so whichever of
# the two grabs first leaves the other blind.
{
  services.kanata = {
    enable = true;

    keyboards.typing = {
      # Required by defchordsv2; kanata refuses the config without it.
      #
      # min-idle is what makes a chord safe to leave armed while typing: chords
      # go dead for 200ms after any ordinary keystroke, so a word expands when
      # the pair is pressed deliberately and never when two letters are rolled
      # together at speed. Lowering it to 5 (the minimum, and the default) arms
      # chords mid-flow, and then "there" expands to "the" with "ere" typed on
      # top of it - tolerable only with pairs that do not roll, which "th" and
      # "an" are not.
      #
      # The include is only consulted while `devices` above is empty; the name
      # must match in full, no prefix, and `kanata --list` prints it with the
      # board attached. keyboard-only keeps kanata off the mice.
      extraDefCfg = ''
        concurrent-tap-hold yes
        chords-v2-min-idle 200
        linux-device-detect-mode keyboard-only
        linux-dev-names-include ("Glove80 Keyboard")
      '';

      # Every participant of every chord must be in defsrc or kanata never sees
      # the key at all. Keys left out are forwarded untouched, so the rest of
      # the keyboard is unaffected by the omission. The two lines are the same
      # sequence because each position is one key: identity in defsrc's order.
      #
      # 200ms for all of them, including the two-key words. A chord's window is
      # bounded by the shortest timeout among its supersets - "the" expiring
      # would cut "that" off mid-press - so the shorter siblings cannot be
      # tightened without shortening the longer words with them.
      #
      # first-release because the action is a macro that emits on activation,
      # so which release ends it makes no difference. It matters for a different
      # reason: seven of the two-key words are also the opening two keys of a
      # three-key one - the, have, at and of, on, or, to - so kanata holds each
      # of them back in case the third key is coming. Releasing either key fires
      # the two-key word straight away; holding it waits out the 200ms.
      config = ''
        (defsrc a b e f h i n o r s t u w y)

        (deflayer base a b e f h i n o r s t u w y)

        ;; (participants) action timeout release-behaviour (disabled-layers)
        (defchordsv2
          (a n) (macro a n d)   200 first-release ()
          (a r) (macro a r e)   200 first-release ()
          (a s) (macro a s)     200 first-release ()
          (a t) (macro a t)     200 first-release ()
          (b e) (macro b e)     200 first-release ()
          (b u) (macro b u t)   200 first-release ()
          (b y) (macro b y)     200 first-release ()
          (h a) (macro h a v e) 200 first-release ()
          (h i) (macro h i s)   200 first-release ()
          (i n) (macro i n)     200 first-release ()
          (i s) (macro i s)     200 first-release ()
          (i t) (macro i t)     200 first-release ()
          (o f) (macro o f)     200 first-release ()
          (o n) (macro o n)     200 first-release ()
          (o r) (macro o r)     200 first-release ()
          (t h) (macro t h e)   200 first-release ()
          (t o) (macro t o)     200 first-release ()
          (w a) (macro w a s)   200 first-release ()
          (w i) (macro w i t h) 200 first-release ()
          (y o) (macro y o u)   200 first-release ()

          ;; Three keys, because two of the three pairs in each of these words
          ;; are already words on their own - {t,h}/{t,a} are the/at, {f,o}/{o,r}
          ;; are of/or, {n,o}/{t,o} are on/to - so the third key is the only one
          ;; that distinguishes them. That is the steno move, minus the ordered
          ;; keys that would have made it free.
          (f o r) (macro f o r)   200 first-release ()
          (n o t) (macro n o t)   200 first-release ()
          (t h a) (macro t h a t) 200 first-release ())
      '';
    };
  };

  # The module sets no Restart, so a crash leaves the keyboard remapping nothing
  # until the next rebuild - hence this, on the unit for `keyboards.typing`
  # above. on-failure and not always: kanata exits 0 on its own
  # LCtrl+Space+Escape emergency exit, which should stay a way out.
  systemd.services.kanata-typing.serviceConfig.Restart = "on-failure";
}
