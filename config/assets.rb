# frozen_string_literal: true

base_path = File.expand_path("..", __dir__)

Decidim::Shakapacker.register_path("#{base_path}/app/packs")
Decidim::Shakapacker.register_stylesheet_import("stylesheets/decidim/mpassid/mpassid")
Decidim::Shakapacker.register_entrypoints(
  decidim_mpassid: "#{base_path}/app/packs/entrypoints/decidim_mpassid.js"
)
