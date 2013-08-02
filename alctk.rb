#!/usr/bin/ruby
######################################################################
#
# Antilaconia microblog engine - GUI client
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

require 'tk'

client = AntilaconiaClient.new

# Take a list of available blogs, but put 'default' as the first item.
# To wit, add 'default' as an option, then add everything else but 'default'.
blogs = ['default'] + client.blogs.keys.select { |x| x != 'default' }

root = TkRoot.new { title "Antilaconia" }

blogchoice = TkFrame.new(root)
TkLabel.new(blogchoice) { text 'Post to:' }.pack('side' => 'left')
combobox = TkCombobox.new(blogchoice)
combobox.values = blogs
combobox.pack('side' => 'right', 'fill' => 'x')


message = TkText.new(root) { width 80; height 3; }

bottom = TkFrame.new(root)
chars_left = TkMessage.new(bottom) { text "Characters left: 140" }
chars_left.pack('side' => 'left', 'fill' => 'x')
postbutton = TkButton.new(bottom) { text "Post" }
postbutton.pack('side' => 'right')

blogchoice.pack('side' => 'top', 'fill' => 'x')
message.pack('side' => 'left', 'fill' => 'both')
bottom.pack('side' => 'bottom', 'fill' => 'x')


Tk.mainloop
