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

$: << File.dirname(File.symlink?($0) ?
                   File.readlink($0) :
                   $0)
require 'antilaconia_clientlib'

require 'optparse'

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
    AntilaconiaClient.create_barebones_settings_file
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

exit if dryrun

client = AntilaconiaClient.new
response = client.post(blog,message,tweet)
if response[:status] == :success
  puts "Message posted successfully."
else
  fail "Error (HTTP #{response[:response_code]} "+
    "#{response[:response_message]}): "+
    "#{response[:error]}"
end
