#-*-ruby-*-

module Antilaconia
  module Antilaconia::Settings
    PageTitle   = 'Random Laconic Musings'
    PageHeading = 'Random Laconic Musings'
    CampingSessionSecret = 'Is this readable??? I do hope not.'
  end
end

require './antilaconia.rb'

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => './antilaconia.db',
  :encoding => 'utf8'
)

run Antilaconia
