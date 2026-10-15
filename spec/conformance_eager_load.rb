# frozen_string_literal: true

# conformance-kit's audit.require: loads phlex-forms, eager-loads every file its
# Zeitwerk loader manages (both roots), then finalizes the configuration as a
# host's boot does, so `conformance-audit --strict` audits the booted state.
require "json" # phlex-reactive's Sortable calls Hash#to_json while it loads; a Rails host has json loaded already
require_relative "../lib/phlex-forms"

Zeitwerk::Loader.eager_load_namespace(PhlexForms)
Zeitwerk::Loader.eager_load_namespace(Forms)
PhlexForms.finalize!
