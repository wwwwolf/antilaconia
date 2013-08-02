#!/usr/bin/ruby
######################################################################
#
# Antilaconia microblog engine - client library
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

require 'yaml'
require 'yaml/store'
require 'json'
require 'net/http'
require 'uri'

class AntilaconiaClient
  ALC_VERSION = '0.1'
  SETTINGS_FILE = "#{ENV['HOME']}/.antilaconiaclient"
  USER_AGENT = "AntilaconiaClient/#{ALC_VERSION} "+
    "(#{RUBY_PLATFORM}; Ruby/#{RUBY_VERSION})"

  # Creates barebones settings file with example settings.
  def AntilaconiaClient::create_barebones_settings_file
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

  # Read settings from settings file.
  def read_settings
    fail "Settings file doesn't exist." unless File.exists?(SETTINGS_FILE)
    @blogs = {}
    store = YAML::Store.new(SETTINGS_FILE)
    store.transaction do
      @blogs = store['blogs']
    end
  end

  def blogs
    return @blogs
  end
  def blog_names
    return @blogs.keys
  end
  def valid_blog?(what)
    return @blogs.has_key?(what)
  end

  def initialize
    read_settings
  end

  def post(blog,message,also_tweet)

    fail "No message."           if message.length <= 0
    fail "Message too long."     if message.length > 140
    fail "Blog #{blog} unknown." unless valid_blog?(blog)

    api      = URI.parse(@blogs[blog]['api'] + '/new')
    f = {
      'client'   => 'AntilaconiaClient',
      'username' => @blogs[blog]['username'],
      'password' => @blogs[blog]['password'],
      'blog_id'  => @blogs[blog]['blog_id'],
      'newpost'  => message
    }
    if also_tweet.nil?
      f['also_tweet'] = 'on' if @blogs[blog]['tweet_by_default']
    else
      f['also_tweet'] = 'on' if also_tweet
    end

    request = Net::HTTP::Post.new(api.path)
    request.set_form_data(f)
    request['User-Agent'] = USER_AGENT
    response = Net::HTTP.start(api.host, api.port) do |http|
      http.request(request)
    end

    s = {
      :response_code => response.code,
      :response_message => response.message
    }
    if response.code == '200'
      s[:status] = :success
    else
      s[:status] = :failure
      begin
        r = JSON.parse(response.body)
        s[:error] = r['error']
      rescue JSON::ParserError
        s[:error] = 'Unknown error, failed to parse JSON response'
      end
    end
    return s
  end
end
