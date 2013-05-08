#!/usr/bin/ruby

require 'rubygems'
gem 'activerecord'

require 'sqlite3'
require 'active_record'

# Database connection
ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :database => 'test.db'
)

# Data schema
class User < ActiveRecord::Base
  has_many :posts
  validates_uniqueness_of :name
end
class Post < ActiveRecord::Base
  belongs_to :user
end

######################################################################

u = User.new
u.name = "wobblybob"
u.save

p1 = Post.new
p1.user = u
p1.text = "Hello world!"
p1.save

p1 = Post.new
p1.user = u
p1.text = "Hello world again!"
p1.save

