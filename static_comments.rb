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

module StaticComments

	def comment_list()
		@comment_list ||= StaticComments.find_for(self.site, self.id)
	end
	
	def comment_count()
		comment_list.length
	end
	
    # Returns the comment-specific liquid attributes
	def liquid_comment_attributes
		{
			'comment_list'  => self.comment_list,
			'comment_count' => self.comment_count
		}
	end
	
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
		
		# TODO: Sort 'comment_list' by date
		comment_list
	end
	
	class Comment 
		#include Jekyll::Convertible
		
		attr_accessor :site, :filename, :ext
		attr_accessor :data, :content
		attr_accessor :page_id, :published
		
		def initialize(site, filename)
			@site = site
			@filename = filename
			
			self.load_yaml(filename)
			
			@date      = self.data['date']
			#@name      = self.data['name']
			#@link      = self.data['link']
			@published = self.published?
			
			# Reverse compatiblitiy with previous versions of `jekyll-static-comments` wich called the "page_id" field "post_id"
			if (data.key?('post_id'))
				@page_id = self.data['post_id']
			else
				@page_id = self.data['page_id']
			end
			
			self.transform()
		end
		
		def load_yaml(filename)
			begin
				#Jeyll: self.content = File.read_with_options(filename, self.site.file_read_opts)
				self.content = File.read(filename)
				self.ext = File.extname(filename)
				if self.content =~ /\A(---\s*\n.*?\n?)^(---\s*$\n?)/m
					self.content = $POSTMATCH
					self.data = YAML.safe_load($1)
					#Octopress: self.data = YAML.load($1)
				else
					# It's all YAML! (maybe)
					# This is to accomodate for comments generated in older versions of Jekyll Static Comments
					self.data = YAML.safe_load(self.content)
					#Octopress: self.data = YAML.load(self.content)
					if (data.key?('comment'))
						self.content = data['comment']
						data.delete('comment')
					else
						self.content = ""
						puts "[StaticComments::Comment] WARNING: I don't know how to parse #{filename}; there doesn't seem to be any content or 'comment' property."
					end
				end
			rescue SyntaxError => e
				puts "YAML Exception reading #{filename}: #{e.message}"
			rescue Exception => e
				puts "Error reading file #{filename}: #{e.message}"
			end

			self.data ||= {}
		end
		
		# Transform the contents based on the content type.
		#
		# Returns nothing.
		def transform
			self.content = converter.convert(self.content)
		rescue => e
			Jekyll.logger.error "Conversion error:", "There was an error converting '#{filename}'."
			raise e
		end
		
		# First the script goes through a few custom converters (I don't want to interfere with the rest
		# of Jekyll just in case). If none is profided, just use one of the builtin converters.
		# The default converter that handles the type of extension can be found and adjusted in `configuration.rb`
		def converter
			if (PlaintextConverter::matches(self.ext))
				PlaintextConverter.new()
			elsif (HTMLConverter::matches(self.ext))
				HTMLConverter.new(true, true)
			else
				self.site.converters.find { |c| c.matches(self.ext) }
			end
		end
		
		def to_liquid
			return self.data.deep_merge({ "content" => self.content })
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


class Jekyll::Post
	include StaticComments
	# Already contains 'id' property

	alias :to_liquid_without_comments :to_liquid
	def to_liquid(attrs = nil)
		data = (attrs.nil? ? to_liquid_without_comments() : to_liquid_without_comments(attrs))
		data.deep_merge(self.liquid_comment_attributes)
	end
end

class Jekyll::Page
	include StaticComments
	
	alias :to_liquid_without_comments :to_liquid
	def to_liquid(attrs = nil)
		data = (attrs.nil? ? to_liquid_without_comments() : to_liquid_without_comments(attrs))
		data.deep_merge(self.liquid_comment_attributes)
	end
	
	def id
		return data['id'] if self.data.key? 'id'
		self.url
	end 
	
end


