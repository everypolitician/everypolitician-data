# frozen_string_literal: true

require 'colorize'
require 'wikisnakker'
require 'pathname'

MAPPING = {
  'Q140247'  => 'unicameral legislature',
  'Q35749'   => 'unicameral legislature',
  'Q375928'  => 'lower house',
  'Q9247597' => 'lower house',
  'Q2145277' => 'lower house',
  'Q320289'  => 'lower house',
  'Q2570643' => 'upper house',
  'Q637846'  => 'upper house',
}.freeze

desc 'Add classification to a legislature’s meta.json'
namespace :legislature do
  task :classify do
    info = json_load(LEGISLATURE_META)
    abort " = #{info[:type]}" unless info[:type].to_s.empty?
    abort 'No wikidata!' unless info[:wikidata]
    legislature = Wikisnakker::Item.find(info[:wikidata])

    instance_of = legislature.P31s.map(&:value).map(&:id).to_set
    abort "Unknown type #{instance_of.to_a.join(', ')} for #{legislature.id}".yellow unless
      found = MAPPING.find { |k, _v| instance_of.include? k }

    info[:type] = found.last
    warn "  type set to #{info[:type]}"
    LEGISLATURE_META.write(JSON.pretty_generate(info))
  end
end
