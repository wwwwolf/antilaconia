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
gem     'twitter'

require 'active_record'
require 'camping'
require 'camping/session'
require 'bcrypt'
require 'kramdown'
require 'twitter'

Camping.goes :Antilaconia

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => Antilaconia::Settings::DatabaseFile,
  :encoding => 'utf8'
)

Twitter.configure do |config|
  config.consumer_key = Antilaconia::Settings::TwitterConsumerKey
  config.consumer_secret = Antilaconia::Settings::TwitterConsumerSecret
  config.oauth_token = Antilaconia::Settings::TwitterOAuthToken
  config.oauth_token_secret = Antilaconia::Settings::TwitterOAuthTokenSecret
end

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
  class NewPost < R '/new'
    def post
      unless @state.has_key?('user_id')
        @state = {}
        @error = "Must be logged in to post."
        redirect '/'
      end
      user = User.find(@state['user_id'])
      unless @input.has_key?('blog_id')
        @error = "No blog id specified."
        redirect '/'
      end
      blog = Blog.find(@input['blog_id'])
      if blog.nil?
        @error = "Invalid blog"
        redirect '/'
      end
      if blog.owner != user
        @error = "You don't own this blog"
        redirect '/'
      end
      entry = Post.new
      entry.blog = blog
      entry.mtext = @input['newpost'].chomp.slice(0,140)
      entry.save
      if @input.has_key?('also_tweet') and @input['also_tweet']=='on'
        Twitter.update(entry.mtext)
      end
      redirect '/'
    end
  end
  class ShowPost < R '/post/(\d+)'
    def get(post_id)
      redirect '/'
    end
  end
  class Tweet < R '/tweet/(\d+)'
    def get(post_id)
      redirect '/'
    end
  end
  class Delete < R '/delete/(\d+)'
    def get(post_id)
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
      @posts = Post.where({:blog_id => @blog.id}).limit(10).order('created_at DESC')
      render :index
    end
  end
end

module Antilaconia::Views
  def common_head_tags
    meta('http-equiv' => 'Content-Type',
         :content => 'text/html;charset=UTF-8')
    meta(:name => 'viewport',
         :content => 'width=device-width, initial-scale=1.0')
    script(:type => 'text/javascript',
           :src => '/s/jquery-2.0.0.min.js')
    script(:type => 'text/javascript',
           :src => '/s/antilaconia.js')    
    link(:rel => 'stylesheet',
         :href => '/s/bootstrap/css/bootstrap.min.css',
         :media => 'screen')
    script(:type => 'text/javascript',
           :src => '/s/bootstrap/js/bootstrap.min.js')
    link(:rel => 'stylesheet',
         :href => '/s/antilaconia.css', :type => 'text/css')
  end

  def loginform
    html do
      head do
        title 'Log in to Antilaconia'
        meta(:name => 'robots', :content => 'noindex,nofollow')
        common_head_tags
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

  def toolbar
    div(:class => 'navbar navbar-inverse navbar-fixed-bottom') do
      div(:class => 'navbar-inner') do
        div(:class => 'container') do
          a "Antilaconia", :class => 'brand', :href => '#'
          div(:class => 'nav-collapse collapse') do
            ul(:class => 'nav') do
              if @user.nil?
                li(:class => 'active') do
                  a "Not logged in.", :href => '#'
                end
                li { a "Login", :href => R(Login), :rel => 'nofollow' }
              else
                li(:class => 'active') do
                  a "Welcome, #{@user.username}!", :href => '#'
                end
                li { a "Logout", :href => R(Logout), :rel => 'nofollow' }
              end
            end
          end
        end
      end
    end
  end

  def new_post_form_layout
    div.row do
      div.span3 { } # Left empty area
      div(:id => 'postbox', :class => 'span8') do
        div.row do
          div.span6 do
            div.row do
              div.newpostcontainer!.span8 do
                fieldset do
                  # legend("New post")
                  label do
                    text! "\u00B5blog message &ndash; "
                    span.charcount! { text! '&nbsp;' }
                  end
                  textarea :rows => 3, :cols => 50, :maxlength => 140,
                           :wrap => 'soft', :required => true,
                           :id => 'newpost', :name => 'newpost',
                           :placeholder => 'Enter your post...'
                  label(:class => :checkbox) do
                    input(:type => :checkbox, :name => 'also_tweet',
                          :checked => true)
                    text! "Tweet"
                  end                  
                  button(:type => :submit, :class => 'btn btn-mini',
                         :title => 'Submit') do
                    i(:class=>'icon-envelope') { }
                  end
                end                
              end
            end
          end
        end
      end
      div.span3 { } # Right empty area
    end
  end


  def new_post_form
    form(:action => R(NewPost), :method => 'POST') do
      input :type => :hidden, 
            :name => 'blog_id',
            :value => @blog.id
      new_post_form_layout
    end
  end

  def recent_posts
    @posts.each do |post|
      div.entry do
        if post.body.nil? or post.body == ''
          div.text { p post.mtext }
        else
          div.text { p post.mtext }
          blockquote.body {text! Kramdown::Document.new(post.body).to_html}
        end

        div.span6 do
          div.row do
            div.span3 do
              if @user.nil?
                div.postoperations { }
              else
                div.postoperations do
                  div(:class => 'btn-toolbar') do
                    div(:class => 'btn-group') do
                      a(:class => 'btn btn-mini',
                        :title => 'Delete',
                        :href => R(Delete, post.id),
                        :rel => 'nofollow') do
                        i(:class => "icon-remove-sign ") { "" }
                      end
                      a(:class => 'btn btn-mini',
                        :title => 'Tweet',
                        :href => R(Tweet, post.id),
                        :rel => 'nofollow') do
                        i(:class => "icon-retweet ") { "" }
                      end
                    end # btn-group
                  end # btn-toolbar
                end # postoperations
              end # if user...
            end # postoperations span
            div.span3 do
              p.timestamp do
                a(:href => R(ShowPost, post.id),
                  :title => 'Permalink') do
                  post.created_at
                end
              end
            end # timestamp span
          end
        end

      end
    end
  end

  def index
    html do 
      head do 
        title @blog.title
        common_head_tags
      end
      body do
        div.container do
          #if not @error.nil?
          #  p.error! @error
          #end

          h1.pagetitle! @blog.pagetitle

          # Posting box.          
          unless @user.nil?
            new_post_form
          end

          # Blog content.
          div.row do
            div.span3 { }
            div.span6 do
              recent_posts
            end
            div.span3 { }
          end
          # Toolbar is shown if the user is logged in, or if the
          # system is accessed with URL parameter ?toolbar=show
          # (the default non-logged-in toolbar only shows the login link,
          # however, so this is just for tidiness.)
          if (not @user.nil?) or @input['toolbar'] == 'show' then
            toolbar
          end

        end # div.container for the page
      end # body
    end # html
  end

end

######################################################################
#Rack::Handler::CGI.run(Antilaconia) if __FILE__ == $0
