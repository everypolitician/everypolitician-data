# frozen_string_literal: true

namespace :report do
  task :area_list do
    areas = ep_popolo.memberships.select(&:area_id).group_by(&:area_id)
    puts %w[id wikidata].to_csv
    puts areas.map do |id, ms|
      ts = ms.map(&:legislative_period).sort_by(&:id)
      [id.sub('area/', ''), ms.map { |m| m.area.name }.uniq.join(';'), ts.first.start_date, ts.last.end_date]
    end.sort_by { |a| a[1] }.map(&:to_csv)
  end
end
