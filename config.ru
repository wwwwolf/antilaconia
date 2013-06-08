#-*-ruby-*-

module Antilaconia
  module Antilaconia::Settings
    # All actions will be set relative to this.
    # e.g. when Approot = '', result = '/login'
    #           Approot = '/foo', result = '/foo/login'
    Approot = ''
    # Secret key for handling session cookies. Please make this really
    # cryptographical and stuff. This isn't an example of that.
    CampingSessionSecret = 'Is this readable??? I do hope not.'
    # SQLite3 database where the stuff is stored.
    DatabaseFile = './antilaconia.db'

    # Twitter settings, from your registered Twitter app.
    # See Twitter Gem homepage (http://sferik.github.io/twitter/).
    TwitterConsumerKey = ''
    TwitterConsumerSecret = ''
    TwitterOAuthToken = ''
    TwitterOAuthTokenSecret = ''
  end
end

require './antilaconia.rb'

use Rack::Static, :urls => ["/s"]
run Antilaconia
