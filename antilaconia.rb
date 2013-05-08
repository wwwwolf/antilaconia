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
gem     'camping'

require 'camping'

Camping.goes :Antilaconia

module Antilaconia::Models
  class User < Base
    has_many :posts
    validates_uniqueness_of :username
  end
  class Post < Base
    belongs_to :user
  end
  class BasicFields < V 1.0
    def self.up
      create_table User.table_name do |t|
        t.string :username, :limit => 40
        t.string :password_hash, :limit => 200
        t.string :password_salt, :limit => 200
      end
      create_table Post.table_name do |t|
        t.references :user
        t.string :text, :limit => 140
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
  class Index
    def get
      @posts = Post.all
      render :index
    end
  end
end

module Antilaconia::Views
  def index
    @posts.each do |post|
      h1 post.title
      div.content! { post.body }
    end
  end
end

######################################################################
Rack::Handler::CGI.run(Antilaconia) if __FILE__ == $0
