require 'everypolitician/popolo'
require 'json5'
require 'everypolitician/dataview/terms'

desc 'Build the term-table CSVs'
task csvs: ['term_csvs:term_tables', 'term_csvs:name_list', 'term_csvs:positions', 'term_csvs:reports']

CLEAN.include('term-*.csv', 'names.csv')

namespace :term_csvs do
  desc 'Generate the Term Tables'
  task term_tables: 'ep-popolo-v1.0.json' do
    @popolo = popolo = EveryPolitician::Popolo.read('ep-popolo-v1.0.json')
    terms = EveryPolitician::Dataview::Terms.new(popolo: @popolo).terms
    terms.each do |term|
      path = Pathname.new('term-%s.csv' % term.id)
      path.write(term.as_csv)

      # TODO: make this a separate task
      next unless term.id == terms.last.id
      latest = Pathname.new('unstable/latest.csv')
      csv = CSV.table(path).delete_if { |r| r[:end_date] }.tap do |t|
        %i[chamber end_date].each { |col| t.delete(col) }
      end
      latest.write(csv.to_s)
    end
  end

  task top_identifiers: :term_tables do
    top_identifiers = @popolo.persons.flat_map(&:identifiers).map { |i| i[:scheme] }
                             .reject { |i| i == 'everypolitician_legacy' }
                             .group_by { |i| i }
                             .sort_by { |_, is| -is.count }
                             .take(5)
                             .map { |i, is| [i, is.count] }
    next unless top_identifiers.any?
    warn "\nTop identifiers:"
    top_identifiers.each { |i, c| warn "  #{c} x #{i}" }
    warn "\n"
  end

  task name_list: :top_identifiers do
    names = @popolo.persons.flat_map do |p|
      Set.new([p.name]).merge(p.other_names.map { |n| n[:name] }).map { |n| [n, p.id] }
    end.uniq { |name, id| [name.downcase, id] }.sort_by { |name, id| [name.downcase, id] }

    filename = 'names.csv'
    header = %w[name id].to_csv
    csv    = [header, names.map(&:to_csv)].compact.join
    warn "Creating #{filename}"
    File.write(filename, csv)
  end

  desc 'Add some final reporting information'
  task reports: :term_tables do
    wikidata_persons = @popolo.persons.partition(&:wikidata)
    wikidata_areas   = @popolo.areas.partition(&:wikidata)
    wikidata_parties = @popolo.organizations.where(classification: 'party').partition(&:wikidata)

    matched, unmatched = wikidata_persons.map(&:count)
    warn "Persons matched to Wikidata: #{matched} ✓ #{unmatched.zero? ? '' : "| #{unmatched} ✘"}"
    wikidata_persons.last.shuffle.take(10).each { |p| warn "  No wikidata: #{p.name} (#{p.id})" } unless matched.zero?

    matched, unmatched = wikidata_parties.map(&:count)
    warn "Parties matched to Wikidata: #{matched} ✓ #{unmatched.zero? ? '' : "| #{unmatched} ✘"}"
    wikidata_parties.last.shuffle.take(5).each { |p| warn "  No wikidata: #{p.name} (#{p.id})" } unless matched.zero?

    matched, unmatched = wikidata_areas.map(&:count)
    warn "Areas matched to Wikidata: #{matched} ✓ #{unmatched.zero? ? '' : "| #{unmatched} ✘"}"
    wikidata_areas.last.shuffle.take(5).each { |p| warn "  No wikidata: #{p.name} (#{p.id})" } unless matched.zero?
  end

  desc 'Build the Cabinet file'
  task positions: ['ep-popolo-v1.0.json'] do
    src = @INSTRUCTIONS.sources_of_type('wikidata-cabinet').first or next

    data = src.filtered(position_map: POSITION_FILTER_CSV)
    members = @popolo.persons.select(&:wikidata).group_by(&:wikidata)

    csv_headers = %w[id name position start_date end_date type].to_csv
    csv_data = data.select { |r| members.key? r[:id] }.map do |r|
      member = members[r[:id]].first
      if r[:start_date].to_s.empty? && r[:end_date].to_s.empty?
        warn "  ☇ No dates for #{member.name} (#{member.wikidata}) as #{r[:label]}"
      end
      [member.id, member.name, r[:label], r[:start_date], r[:end_date], 'cabinet'].to_csv
    end

    POSITION_CSV.dirname.mkpath
    POSITION_CSV.write(csv_headers + csv_data.join)

    # TODO: Warn about uncategorised positions
  end
end

desc 'Convert the old JSON position filter to a CSV'
task :convert_position_filter do
  # for now, simply convert the old JSON file to a new CSV one
  src = @INSTRUCTIONS.sources_of_type('wikidata-cabinet').first or next
  map = PositionMap.new(pathname: POSITION_FILTER)

  csv_headers = %w[id label description type].to_csv
  csv_data = src.as_table.group_by { |r| r[:position] }.map do |id, ps|
    [id, ps.first[:label], ps.first[:description], map.type(id) || 'unknown']
  end.sort_by { |d| [d[3].to_s, d[1].to_s.downcase] }.map(&:to_csv)

  POSITION_FILTER_CSV.dirname.mkpath
  POSITION_FILTER_CSV.write(csv_headers + csv_data.join)
end

desc 'Generate the position filter interface'
task :generate_position_interface do
  abort 'not implemented yet'
  # TODO: make the HTML interface to this again.
  # new_map = PositionMap.new(pathname: POSITION_FILTER).to_json
  # html = Position::Filter::HTML.new(new_map).html
  # POSITION_HTML.write(html)
  # FileUtils.copy('../../../templates/position-filter.js', 'sources/manual/.position-filter.js')
  # warn "open #{POSITION_HTML}".yellow
  # warn "pbpaste | bundle exec ruby #{POSITION_LEARNER} #{POSITION_FILTER}".yellow
end
