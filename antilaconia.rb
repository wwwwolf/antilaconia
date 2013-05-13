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
gem     'activerecord'
gem     'camping',     '>= 2.1'
gem     'bcrypt-ruby', '>= 3.0'
gem     'kramdown'

require 'active_record'
require 'camping'
require 'camping/session'
require 'bcrypt'
require 'kramdown'

Camping.goes :Antilaconia

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => Antilaconia::Settings::DatabaseFile,
  :encoding => 'utf8'
)

module Antilaconia
  set :secret, Antilaconia::Settings::CampingSessionSecret
  include Camping::Session
end

module Antilaconia::Models
  class User < Base
    include BCrypt
    has_many :blogs
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
  class Blog < Base
    belongs_to :owner, :class_name => User
  end
  class Post < Base
    belongs_to :blog
  end
  class BasicFields < V 1.0
    def self.up
      create_table User.table_name do |t|
        t.string      :username,      :limit => 40
        t.string      :pwhash,        :limit => 100
      end
      create_table Blog.table_name do |t|
        t.references  :owner
        t.string      :title,         :limit => 200
        t.string      :pagetitle,     :limit => 200
      end
      create_table Post.table_name do |t|
        t.references  :blog
        t.string      :mtext,         :limit => 140
        t.text        :body,
        t.timestamps
      end
    end    
    def self.down
      drop_table Post.table_name
      drop_table Blog.table_name
      drop_table User.table_name
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
      user = User.where(:username => @input['username']).first
      if user.nil?
        @state = {}
        @error = 'Unknown username.'
        redirect '/'
        return
      end
      if user.password_valid?(@input['password'])
        # Valid password, put user ID in state.
        @state['user_id'] = user.id
        @error = nil
      else
        # Invalid password, reset state.
        @state = {}
        @error = "Invalid password."
      end
      redirect '/'
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
      if @state.has_key?('user_id')
        @user = User.find(@state['user_id'])
      else
        @user = nil
      end
      @blog = Blog.find(:first)
      @posts = Post.where({:blog_id => @blog.id},
                          :limit => 10, :order => 'created_at DESC')
      render :index
    end
  end
end

module Antilaconia::Views
  def loginform
    html do
      head do
        title 'Log in to Antilaconia'
        meta(:name => 'robots', :content => 'noindex,nofollow')
      end
      body do
        h1 'Log in'
        form(:action => Antilaconia::Settings::Approot+'/login',
             :method => 'POST') do         
          table do 
            tr do
              td do
                text "Username"
              end
              td do
                input :type => :text, :name => 'username'
              end
            end
            tr do
              td do
                text "Password"
              end
              td do
                input :type => :password, :name => 'password'
              end
            end
          end
          p do
            input :type => :submit, :value => 'Log in'
          end
        end
      end
    end
  end

  def index
    html do 
      head do 
        title @blog.title
      end
      body do 
        if not @error.nil?
          p.error! @error
        end
        if @user.nil?
          p do
            text "Not logged in. "
            a(:href => '/login', :rel => 'nofollow') do
              text "Log in?"
            end
          end
        else
          p do
            text "Welcome, #{@user.username}! "
            a(:href => '/logout', :rel => 'nofollow') do
              "Log out"
            end
          end
        end
        h1 @blog.pagetitle
        @posts.each do |post|
          div.entry do
            if post.body.nil? or post.body == ''
              div.text { p post.mtext }
            else
              div.text { p post.mtext }
              blockquote.body { text! Kramdown::Document.new(post.body).to_html }
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
