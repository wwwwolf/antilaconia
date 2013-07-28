#!/usr/bin/ruby
######################################################################
#
# Antilaconia microblog engine - client
# Copyright (C) 2013  Urpo Lankinen
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
######################################################################

require 'optparse'
require 'json'
require 'yaml'
require 'yaml/store'
require 'net/http'
require 'uri'

ALC_VERSION = '0.1'
SETTINGS_FILE = "#{ENV['HOME']}/.antilaconiaclient"
USER_AGENT = "AntiLaconiaClient/#{ALC_VERSION} "+
  "(#{RUBY_PLATFORM}; Ruby/#{RUBY_VERSION})"
@blogs = {}

def create_barebones_settings_file
  File.delete(SETTINGS_FILE) if File.exists?(SETTINGS_FILE)
  store = YAML::Store.new(SETTINGS_FILE)
  store.transaction do
    store['blogs'] = {
      'default' => {
        'api' => 'http://example.net/ublog',
        'user' => '??',
        'password' => '??',
        'blog_id' => 1,
        'tweet_by_default' => true
      }
    }
  end
  File.chmod(0600,SETTINGS_FILE)
end
def read_settings
  @blogs = {}
  store = YAML::Store.new(SETTINGS_FILE)
  store.transaction do
    @blogs = store['blogs']
  end
end

blog = "default"
tweet = false
message = ""
ARGV.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: #{script_name} [options] Message"

  opts.separator ""

  opts.on("-b", "--blog=xxx", String,
          "Blog to post to.",
          "Default: 'default'") { |x| blog = x }
  opts.on("-t", "--tweet",
          "Also tweet.",
          "Default: per blog settings.") { tweet = true }
  opts.on("-T", "--no-tweet",
          "Don't tweet.",
          "Default: per blog settings.") { tweet = false }
  opts.separator ""
  opts.on("-C", "--create-settings-file",
          "Create barebones settings file.") do
    create_barebones_settings_file
    exit
  end
  opts.on("-h", "--help",
          "Show this help message.") { puts opts; exit }

  # Do the command line parsing NOW...
  opts.parse!
  # Do we have a file name? if not, let's bail out.
  if ARGV.length != 1
    puts opts; exit
  end
  message = ARGV.pop
end
message.chomp!
if message.length <= 0
  fail "No message."
end
if message.length > 140
  fail "Message too long."
end
