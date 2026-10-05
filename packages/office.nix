# Office documents: editing ODT and converting to and from it. Workstation only:
# the suite's closure is 2.6 GiB, so none of this belongs in basic_cli_set.nix,
# which bee and hetz also import.
{ pkgs }:
with pkgs;
[
  # The CV is authored in Typst, and this is the one tool that turns a source
  # file into a PDF - one binary, no toolchain behind it. pandoc below reads
  # and writes the same format, which is how the docx export is produced.
  typst

  # The suite. `soffice --headless --convert-to` is the only converter here
  # that keeps ODT layout, and it is also the app for editing one.
  libreoffice

  # Same LibreOffice over UNO, so a batch of conversions pays its startup cost
  # once: it wraps the unwrapped build and sets UNO_PATH itself, so nothing has
  # to be running first, and its closure adds one path over the suite's rather
  # than a second copy of it. installSymlinks stays off because those 24
  # odt2pdf/odt2doc/... names include a second `odt2txt`, which collides with
  # the real one below in the single buildEnv `home.packages` produces - `-f
  # pdf` says what the symlinks would have.
  (unoconv.override { installSymlinks = false; })

  # Where the layout does not have to survive: odt <-> md/docx/html/epub, and
  # the route to markdown an agent can read.
  pandoc

  # Body text out of an ODT without starting LibreOffice at all.
  odt2txt

  # An ODT is a zip of XML, `content.xml` holding the body, and unzip is
  # already in basic_cli_set.nix. For a mechanical edit, rewriting that XML
  # beats a round trip through a converter.
  xmlstarlet
]
