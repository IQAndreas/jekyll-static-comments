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
	include Liquid::StandardFilters
	
	# Find all the comments for a post or page with the specified id
	def self.find_for(site, id)
		@comment_list ||= read_comments(site)
		@comment_list[id]
	end
	
	# Read all the comments files in the site, and return them as a hash of
	# arrays containing the comments, where the key to the array is the value
	# of the 'post_id' field in the YAML data in the comments files.
	def self.read_comments(site)
		comment_list = Hash.new() { |h, k| h[k] = Array.new }
		
		source=site.source
		Dir["#{source}/**/_comments/**/*"].sort.each do |comment_filename|
			next unless File.file?(comment_filename) and File.readable?(comment_filename)
			yaml_data = read_yaml(comment_filename, site.converters)
			if (yaml_data != nil)
				post_id = yaml_data.delete('post_id')
				comment_list[post_id] << yaml_data
			end
		end
		
		comment_list
	end
	
	# Reads the specified file, parses the frontmatter and YAML, and returns the YAML data.
	# Taken from Jekyll::Convertible, but with a few local modifications.
	# Some code borrowed from http://stackoverflow.com/a/14232953/617937
	def self.read_yaml(filename, converters = nil)
		begin
			file_contents = File.read(filename)
			if (md = file_contents.match(/^(?<metadata>---\s*\n.*?\n?)^(---\s*$\n?)/m))
				yaml_data = YAML.safe_load(md[:metadata])
				yaml_data['content'] = md.post_match
			else # If there is no YAML header, it's all YAML. (reverse compatability with previous versions)
				yaml_data = YAML.safe_load(file_contents)
			end
		rescue SyntaxError => e
			puts "YAML Exception reading #{filename}: #{e.message}"
			return nil
		rescue Exception => e
			puts "Error reading file #{filename}: #{e.message}"
			return nil
		end
		
		# Reverse compatiblitiy with previous versions of `jekyll-static-comments` wich called the "content" field "comment"
		if (yaml_data.key?('comment'))
			yaml_data['content'] = yaml_data['comment']
			yaml_data.delete('comment')
		end
		
		# Parse Markdown, Textile, or just leave it as-is (such as with HTML) based on filename extension.
		converter = get_converter(filename, converters)
		yaml_data['content'] = converter.convert(yaml_data['content'])
		
		yaml_data
		
	end
	
	# First the script goes through a few custom converters (I don't want to interfere with the rest
	# of Jekyll just in case). If none is profided, just use one of the builtin converters.
	# The default converter that handles the type of extension can be found and adjusted in `configuration.rb`
	def self.get_converter(filename, stored_converters)
		file_extension = File.extname(filename)
		if (PlaintextConverter::matches(file_extension))
			PlaintextConverter.new()
		elsif (HTMLConverter::matches(file_extension))
			HTMLConverter.new(true, true)
		elsif (stored_converters != nil)
			# Will use `Jekyll::Converters::Identity` if none matches
			stored_converters.find { |c| c.matches(file_extension) }
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

