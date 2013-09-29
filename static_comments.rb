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
	# of the 'post_id' field in the YAML data in the comments files.
	def self.read_comments(site)
		comment_list = Hash.new() { |h, k| h[k] = Array.new }
		
		source=site.source
		Dir["#{source}/**/_comments/**/*"].sort.each do |comment_filename|
			next unless File.file?(comment_filename) and File.readable?(comment_filename)
			yaml_data = read_yaml(comment_filename, site.converters)
			post_id = yaml_data.delete('post_id')
			comment_list[post_id] << yaml_data
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
		rescue Exception => e
			puts "Error reading file #{filename}: #{e.message}"
		end
		
		# Reverse compatiblitiy with previous versions of `jekyll-static-comments` wich called the "content" field "comment"
		if (yaml_data.key?('comment'))
			yaml_data['content'] = yaml_data['comment']
			yaml_data.delete('comment')
		end
		
		# Parse Markdown, Textile, or just leave it as-is (such as with HTML) based on filename extension.
		# The converter that handles the type of extension can be found and adjusted in `configuration.rb`
		if (converters != nil)
			file_extension = File.extname(filename)
			converter = converters.find { |c| c.matches(file_extension) }
			yaml_data['content'] = converter.convert(yaml_data['content'])
		end
		
		yaml_data
		
	end
end
