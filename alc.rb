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
USER_AGENT = "AntilaconiaClient/#{ALC_VERSION} "+
  "(#{RUBY_PLATFORM}; Ruby/#{RUBY_VERSION})"
@blogs = {}

def create_barebones_settings_file
  File.delete(SETTINGS_FILE) if File.exists?(SETTINGS_FILE)
  store = YAML::Store.new(SETTINGS_FILE)
  store.transaction do
    store['blogs'] = {
      'default' => {
        'api' => 'http://example.net/ublog',
        'username' => '??',
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
tweet = nil
message = ""
verbose = false
dryrun = false
ARGV.options do |opts|
  script_name = File.basename($0)
  opts.banner = "Usage: #{script_name} [options] Message"

  opts.separator ""

  opts.on("-b", "--blog=xxx", String,
          "Blog to post to.",
          "Default: 'default'") { |x| blog = x }
  opts.on("-t", "--tweet",
          "Also tweet.",
          "Default: per blog settings.")   { tweet = true }
  opts.on("-T", "--no-tweet",
          "Don't tweet.",
          "Default: per blog settings.")   { tweet = false }
  opts.on("-v", "--verbose",
          "Print additional information.") { verbose = true }
  opts.on("-k", "--dry-run",
          "Don't actually post.")          { dryrun = true }
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
  message = ARGV.pop.dup
end
message.chomp!
read_settings

fail "No message."           if message.length <= 0
fail "Message too long."     if message.length > 140
fail "Blog #{blog} unknown." unless @blogs.has_key?(blog)

api      = URI.parse(@blogs[blog]['api'] + '/new')
username = @blogs[blog]['username']
password = @blogs[blog]['password']
blog_id  = @blogs[blog]['blog_id']
tweet    = @blogs[blog]['tweet_by_default'] if tweet.nil? # honour cli opts

if verbose
  puts "Message  : #{message}"
  puts "API      : #{api}"
  puts "User     : #{username}"
  puts "Password : #{'*' * password.length}"
  puts "Blog ID  : #{blog_id}"
  puts "Tweet    : #{tweet}"
end

exit if dryrun

f = {
  'client' => 'AntilaconiaClient',
  'username' => username,
  'password' => password,
  'blog_id' => blog_id,
  'newpost' => message
}
f['also_tweet'] = 'on' if tweet

request = Net::HTTP::Post.new(api.path)
request.set_form_data(f)
request['User-Agent'] = USER_AGENT
response = Net::HTTP.start(api.host, api.port) do |http|
  http.request(request)
end

if response.code == "200"
  puts "Message posted successfully."
else
  begin
    r = JSON.parse(response.body)
    puts "Error (HTTP #{response.code} #{response.message}): #{r['error']}"
  rescue JSON::ParserError
    puts "Error (HTTP #{response.code} #{response.message}) - "+
      "additionally unable to parse server response!"
  end
end
