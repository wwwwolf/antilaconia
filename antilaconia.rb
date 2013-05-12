#!/usr/bin/ruby
######################################################################
#
# Antilaconia microblog engine
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

require 'rubygems'
gem     'camping',     '>= 2.1'
gem     'bcrypt-ruby', '>= 3.0'

require 'camping'
require 'camping/session'
require 'bcrypt'

Camping.goes :Antilaconia

module Antilaconia
  set :secret, Antilaconia::Settings::CampingSessionSecret
  include Camping::Session
end

module Antilaconia::Models
  class User < Base
    include BCrypt
    has_many :posts
    validates_uniqueness_of :username

    def password
      @password ||= Password.new(pwhash)
    end
    def password=(new_password)
      @password = Password.create(new_password)
      self.pwhash = @password
    end
    def password_valid?(password_to_test)
      return (password == password_to_test)
    end
  end
  class Post < Base
    belongs_to :user
  end
  class BasicFields < V 1.0
    def self.up
      create_table User.table_name do |t|
        t.string      :username,      :limit => 40
        t.string      :pwhash,        :limit => 100
      end
      create_table Post.table_name do |t|
        t.references  :user
        t.string      :mtext,         :limit => 140
        t.text        :body,
        t.timestamps
      end
    end    
    def self.down
      drop_table User.table_name
      drop_table Post.table_name
    end
  end
  def Antilaconia.create
    Antilaconia::Models.create_schema
  end
end

module Antilaconia::Controllers
  class Login < R '/login'
    def get
      render :loginform
    end
    def post
      # DEBUG ONLY
      render :logingpost
      #user = User.where(:username => @user)
      #if user.password_valid?(@password)
      #  # Valid password, put user ID in state.
      #  @state['user_id'] = user.id
      #else
      #  # Invalid password, reset state.
      #  @state = {}
      #end
      #redirect '/'
    end
  end
  class Logout < R '/logout'
    def get
      @state = {}
      redirect '/'
    end
  end
  class Index
    def get
      @posts = Post.all(:limit => 10, :order => 'created_at DESC')
      render :index
    end
  end
end

module Antilaconia::Views
  def loginform
    html do
      head do
        title 'Log in to Antilaconia'
      end
      body do
        h1 'Log in'
      end
    end
  end
  def loginpost
    # DEBUG ONLY
  end


  def index
    html do 
      head do 
        title Antilaconia::Settings::PageTitle
      end
      body do 
        h1 Antilaconia::Settings::PageHeading
        @posts.each do |post|
          div.entry do
            if post.body.nil? or post.body == ''
              div.text { p post.mtext }
            else
              div.text { p post.mtext }
              blockquote.body { p post.body }
            end
            em { post.created_at }
          end
        end
      end
    end
  end
end
######################################################################
#Rack::Handler::CGI.run(Antilaconia) if __FILE__ == $0
