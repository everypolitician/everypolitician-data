# frozen_string_literal: true

module Reconciliation
  class Template
    attr_reader :to_reconcile
    attr_reader :reconciled
    attr_reader :incoming_field
    attr_reader :existing_field

    def initialize(opts)
      @to_reconcile = opts[:to_reconcile]
      @reconciled = opts[:reconciled]
      @incoming_field = opts[:incoming_field]
      @existing_field = opts[:existing_field]
    end

    def render
      erb_template.result(binding)
    end

    private

    def erb_template
      ERB.new(reconciliation_html)
    end

    def reconciliation_html
      @reconciliation_html ||= ::File.read(
        ::File.join(templates_dir, 'reconciliation.html.erb')
      )
    end

    def templates_dir
      @templates_dir ||= ::File.expand_path('../../../templates', __FILE__)
    end

    def reconciliation_js
      @reconciliation_js ||= ::File.read(
        ::File.join(templates_dir, 'reconciliation.js')
      )
    end

    def reconciliation_css
      @reconciliation_css ||= sass_engine.render
    end

    def reconciliation_scss
      @reconciliation_scss ||= ::File.read(
        ::File.join(templates_dir, 'reconciliation.scss')
      )
    end

    def sass_engine
      @sass_engine ||= Sass::Engine.new(
        reconciliation_scss, syntax: :scss, load_paths: [templates_dir]
      )
    end
  end
end
