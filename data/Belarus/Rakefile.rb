require_relative '../../rakefile_morph.rb'
require 'csv'

@MORPH = 'duncanparkes/belarus'
@LEGISLATURE = {
  name: 'National Assembly',
  seats: 110,
}

# TODO: move these out to a data file
@remap = {
  'ZHILINSKY MARAT'       => ['KPB', 'Communist Party of Belarus'],
  'ZHURAVSKAYA VALENTINA' => ['KPB', 'Communist Party of Belarus'],
  'KLIMOVICH NATALIA'     => ['KPB', 'Communist Party of Belarus'],
  'KUBRAKOVA LIUDMILA'    => ['KPB', 'Communist Party of Belarus'],
  'KUZMICH ALEKSEY'       => ['KPB', 'Communist Party of Belarus'],
  'LEONENKO VALENTINA'    => ['KPB', 'Communist Party of Belarus'],
}
# source = http://www.comparty.by/deputati

namespace :transform do

  def find_or_create_party(data)
    party_id = data.first.prepend "party/"
    party = @json[:organizations].find { |o| o[:id] == party_id }
    return party if party
    party = {
      classification: 'party',
      id: party_id,
      name: data.last,
    }
    @json[:organizations] << party
    party
  end


  task :ensure_membership_terms do
    @remap.each do |name, data|
      party = find_or_create_party(data)
      person = @json[:persons].find { |p| p[:name] == name }

      @json[:memberships].find_all { |m| m[:person_id] == person[:id] }.each do |m|
        m[:on_behalf_of_id] = party[:id]
      end
    end
  end

end
