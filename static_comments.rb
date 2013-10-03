# Store and render comments as a static part of a Jekyll site
#
# See README.md for detailed documentation on this plugin.
#
# Homepage: http://theshed.hezmatt.org/jekyll-static-comments
#
#  Copyright (C) 2011 Matt Palmer <mpalmer@hezmatt.org>
#
#  This program is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License version 3, as
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, see <http://www.gnu.org/licences/>

class Jekyll::Post
	alias :to_liquid_without_comments :to_liquid
	
	def to_liquid(attrs = nil)
		data = to_liquid_without_comments(attrs)
		data['comment_list'] = StaticComments::find_for(self.site, data['id'])
		data['comment_count'] = data['comment_list'].length
		data
	end
end

class Jekyll::Page
	alias :to_liquid_without_comments :to_liquid
	
	def to_liquid(attrs = nil)
		data = to_liquid_without_comments(attrs)
		data['comment_list'] = StaticComments::find_for(self.site, data['id'])
		data['comment_count'] = data['comment_list'].length
		data
	end
end

module StaticComments
	
	# Find all the comments for a post or page with the specified id
	def self.find_for(site, id)
		@comment_list ||= read_comments(site)
		@comment_list[id]
	end
	
	# Read all the comments files in the site, and return them as a hash of
	# arrays containing the comments, where the key to the array is the value
	# of the 'page_id' field in the YAML data in the comments files.
	def self.read_comments(site)
		comment_list = Hash.new() { |h, k| h[k] = Array.new }
		
		source=site.source
		Dir["#{source}/**/_comments/**/*"].sort.each do |comment_filename|
			next unless File.file?(comment_filename) and File.readable?(comment_filename)
			# `comment_filename` includes everything: the full, absolute path, file name, and extension.
			comment = Comment.new(site, comment_filename)
			if (comment.published?)
				comment_list[comment.page_id] << comment
			end
		end
		
		comment_list
	end
	
	class Comment 
		include Jekyll::Convertible
		
		# Attributes for Liquid templates
		ATTRIBUTES_FOR_LIQUID = %w[
			page_id
			date
			name
			link
			content
			published
		]
		
		attr_accessor :site
		attr_accessor :data, :content
		attr_accessor :page_id, :date, :published
		attr_accessor :name, :link
		attr_accessor :path, :dir, :name, :basename, :ext, :output
		
		def initialize(site, full_filename)
			@site = site
			self.process(full_filename)
			
			self.read_yaml(@dir, @name)
			@date      = self.data['date']
			@name      = self.data['name']
			@link      = self.data['link']
			@published = self.published?
			
			# Reverse compatiblitiy with previous versions of `jekyll-static-comments` wich called the "page_id" field "post_id"
			if (data.key?('post_id'))
				@page_id = self.data['post_id']
			else
				@page_id = self.data['page_id']
			end
			
			# Reverse compatiblitiy with previous versions of `jekyll-static-comments` wich called the "content" field "comment"
			if (data.key?('comment'))
				@content = data['comment']
				data.delete('comment')
			end
			
			
			# First the script goes through a few custom converters (I don't want to interfere with the rest
			# of Jekyll just in case). If none is profided, just use one of the builtin converters.
			# The default converter that handles the type of extension can be found and adjusted in `configuration.rb`
			@converter = custom_converter || converter
			
			self.transform()
		end
		
		def process(full_filename)
			@path =     full_filename # Required by Jekyll::Convertible
			@name =     File.basename(full_filename)
			@ext =      File.extname(full_filename)
			@dir =      File.dirname(full_filename)
			@basename = File.basename(@name, @ext)
		end
		
		def custom_converter
			if (PlaintextConverter::matches(self.ext))
				PlaintextConverter.new()
			elsif (HTMLConverter::matches(self.ext))
				HTMLConverter.new(true, true)
			else
				nil
			end
		end
		
		def published?
			if self.data.has_key?('published') && self.data['published'] == false
				false
			else
				true
			end
		end
		
	end
	
	class PlaintextConverter
		include Liquid::StandardFilters
		def self.matches(ext)
			ext.eql?('.txt')
		end
	
		def convert(content)
			content = escape(content)
			content = newline_to_br(content)
			content
		end
	end
	
	class HTMLConverter
		include Liquid::StandardFilters
		def self.matches(ext)
			ext.eql?('.html') or ext.eql?('.htm')
		end
		
		def initialize(basic_html, newlines_to_br)
			@basic_html = basic_html 		 # Strip out some potentially "unwanted" elements such as <script>
			@newlines_to_br = newlines_to_br # Convert all found newlines into <br /> tags
		end
		
		def convert(content)
			if (@basic_html)
				content = content.gsub(/<script.*?<\/script>/m, '')
				content = content.gsub(/<!--.*?-->/m, '')
				content = content.gsub(/<style.*?<\/style>/m, '')
			end
			if (@newlines_to_br)
				content = newline_to_br(content)
			end
			content
		end
	end
end

