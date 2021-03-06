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
gem     'activesupport'

require 'active_record'
require 'active_support'
require 'active_support/json'
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

if Antilaconia::Settings::Twitter
  Twitter.configure do |config|
    config.consumer_key = Antilaconia::Settings::TwitterConsumerKey
    config.consumer_secret = Antilaconia::Settings::TwitterConsumerSecret
    config.oauth_token = Antilaconia::Settings::TwitterOAuthToken
    config.oauth_token_secret = Antilaconia::Settings::TwitterOAuthTokenSecret
  end
end

module Antilaconia
  set :secret, Antilaconia::Settings::CampingSessionSecret
  include Camping::Session
end

module Antilaconia::Helpers
  # Will return user object for the specified username if the password
  # is valid, otherwise will return nil.
  def authenticate(username,password)
    user = User.where(:username => username).first
    return nil  if user.nil?
    return user if user.password_valid?(password)
    return nil
  end
  # Post an entry.
  def perform_post(uid,blogid,mtext,body,tweet)
    if uid.nil?
      r(401, 'Must be logged in to post.')
      throw :halt
    end
    user = User.find(uid)
    if user.nil?
      r(401, 'Invalid user ID.')
      throw :halt
    end
    if blogid.nil?
      r(400, 'Blog ID missing from parameters.')
      throw :halt
    end
    blog = Blog.find(blogid)
    if blog.nil?
      r(400, 'Invalid blog ID.')
      throw :halt
    end
    if blog.owner != user
      r(403, 'User not authorised to post on specified blog.')
      throw :halt
    end
    entry = Post.new
    entry.blog = blog
    entry.mtext = mtext.chomp.slice(0,140)
    entry.save
    if tweet
      Twitter.update(entry.mtext)
    end
  end
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
      user = authenticate(@input['username'],@input['password'])
      if user.nil?
        @state = {}
        r(401, 'Invalid username or password.')
        return
      end
      @state['user_id'] = user.id
      redirect R(Index)
    end
  end
  class NewPost < R '/new'
    # GET method will just show a form for new posts, or if the user has
    # logged out or the session has expired, will redirect to login.
    def get
      unless @state.has_key?('user_id')
        redirect R(Login)
        return
      end
      @user = User.find(@state['user_id'])
      @blog = Blog.find(:first)
      render :new_post_page
    end
    # POST is used to actually post the new entry.
    def post
      if @input.has_key?('client')
        # Posting via client. Will not look at the state cookie
        # at all, but will perform an in-place authentication.

        # Response will be given in JSON format.
        @headers['Content-Type'] = "application/json"

        user = authenticate(@input['username'],@input['password'])
        if user.nil?
          @status = 401
          result = {
            :error => 'Invalid username or password.'
          }
          return result.to_json
        end

        uid = user.id
        blogid = @input['blog_id']
        mtext = @input['newpost']
        if Antilaconia::Settings::Twitter
          tweet = (@input.has_key?('also_tweet') and @input['also_tweet']=='on')
        else
          tweet = false
        end
        perform_post(uid,blogid,mtext,nil,tweet)
        @status = 200
        result = {
          :error => 'Message posted.',
          :message => mtext,
          :tweet => tweet
        }
        return result.to_json
      else
        # Posting via web. Will store the thingy and
        # redirect to index.
        uid = @state['user_id']
        blogid = @input['blog_id']
        mtext = @input['newpost']
        if Antilaconia::Settings::Twitter
          tweet = (@input.has_key?('also_tweet') and @input['also_tweet']=='on')
        else
          tweet = false
        end
        perform_post(uid,blogid,mtext,nil,tweet)
        redirect R(Index)
      end
    end
  end
  class ShowPost < R '/post/(\d+)'
    def get(post_id)
      redirect R(Index)
    end
  end
  class Tweet < R '/tweet/(\d+)'
    def get(post_id)
      redirect R(Index)
    end
  end
  class Delete < R '/delete/(\d+)'
    def get(post_id)
      redirect R(Index)
    end
  end
  class Logout < R '/logout'
    def get
      @state = {}
      redirect R(Index)
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
      body.loginpage! do
        form(:action => R(Login),
             :method => 'POST',
             :class => 'form-signin') do
          h2(:class=> 'form-signin-heading') do
            "Log in"
          end
          input(:type => :text,
                :name => 'username',
                :class => 'input-block-level',
                :placeholder => 'Username')
          input(:type => :password,
                :name => 'password',
                :class => 'input-block-level',
                :placeholder => 'Password')
          button(:class => 'btn btn-large btn-primary',
                 :type => :submit) do
            "Log in"
          end
        end
      end
    end
  end

  def new_post_page
    html do
      head do
        title 'New post'
        meta(:name => 'robots', :content => 'noindex,nofollow')
        common_head_tags
      end
      body do
        div(:class => 'container-fluid') do
          h1(:style => 'text-align: center') { "New post" }
          new_post_form
          toolbar
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
    div(:class => 'row-fluid') do
      div.span3 { } # Left empty area
      div(:id => 'postbox', :class => 'span8') do
        div(:class => 'row-fluid') do
          div.span6 do
            div(:class => 'row-fluid') do
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
                  div(:class => 'row-fluid', :style=> 'text-align: left;') do
                    div(:class => 'span6') do
                      if Antilaconia::Settings::Twitter
                        label(:class => :checkbox) do
                          input(:type => :checkbox, :name => 'also_tweet',
                                :checked => true)
                          text! "Tweet"
                        end
                      else
                        label(:class => :checkbox) do
                          input(:type => :checkbox, :name => 'also_tweet',
                                :checked => false, :disabled => true)
                          text! "Tweet"
                        end
                      end
                    end
                    div(:class => 'span6', :style=> 'text-align: right;') do
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

        div.span12 do
          div(:class => 'row-fluid') do
            div.span6 do
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
                      if Antilaconia::Settings::Twitter
                        a(:class => 'btn btn-mini',
                          :title => 'Tweet',
                          :href => R(Tweet, post.id),
                          :rel => 'nofollow') do
                          i(:class => "icon-retweet ") { "" }
                        end
                      end
                    end # btn-group
                  end # btn-toolbar
                end # postoperations
              end # if user...
            end # postoperations span
            div.span6 do
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
        div(:class => 'container-fluid') do
          #if not @error.nil?
          #  p.error! @error
          #end

          h1.pagetitle! @blog.pagetitle

          # Posting box.          
          unless @user.nil?
            new_post_form
          end

          # Blog content.
          div(:class => 'row-fluid') do
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
