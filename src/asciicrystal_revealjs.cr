require "asciicrystal"
require "./asciicrystal_revealjs/converter"

module AsciicrystalRevealjs
  # Lue au compile-time depuis `shard.yml` via le macro `read_file`.
  # Cf. note mémoire `feedback_shard_version_macro.md` (mémoire ALOLI).
  VERSION = {{
              (read_file("#{__DIR__}/../shard.yml")
                .lines
                .find(&.starts_with?("version:")) || "version: 0.0.0")
                .gsub(/^version:\s*/, "")
                .chomp
            }}

  # Version de la gem Ruby asciidoctor-revealjs utilisee comme reference.
  UPSTREAM_VERSION = "5.2.0"
end
