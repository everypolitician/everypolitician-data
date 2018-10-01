# frozen_string_literal: true

require_relative 'source'

class Instructions
  def initialize(path)
    @path = path
  end

  def sources
    @sources ||= raw_sources.map { |s| Source::Base.instantiate(s) }
  end

  def sources_of_type(type)
    sources.select { |src| src.type.to_s.downcase == type.to_s.downcase }
  end

  def write(data)
    path.write(JSON.pretty_generate(data))
  end

  private

  attr_reader :path

  def data
    @data ||= JSON.parse(path.read, symbolize_names: true)
  end

  def raw_sources
    @raw_sources = data[:sources].each do |s|
      s[:file] = Pathname.new('sources') + s[:file]
    end
  end
end
