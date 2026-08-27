# frozen_string_literal: true

module Jumbotron
  # Immutable semantic public team identity helper.
  # Derives a kebab-case slug once at assignment; callers must not re-run on rename.
  module TeamKey
    FORMAT = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

    module_function

    def normalize(name)
      slug = name.to_s.unicode_normalize(:nfc).downcase
      slug = slug.gsub(/[^a-z0-9]+/, "-").gsub(/\A-+|-+\z/, "")
      slug = "team" if slug.blank?
      slug
    end

    def valid_format?(key)
      key.to_s.match?(FORMAT)
    end
  end
end
