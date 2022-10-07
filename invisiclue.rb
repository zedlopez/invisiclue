#!/usr/bin/env ruby

# usage: invisiclue.rb ZorkI.inv > zork.html

require 'erubi'
require 'set'
require 'ostruct'

no_merge = [ 'Table of Contents', 'For Your Amusement', 'Progress Points', 'Treasures: Their Values and Locations' ].to_set

unindented_sections = [ "indicia", "Table of Contents", "For Your Amusement" ].to_set

games = {}

invisiclue = Erubi::Engine.new(File.read(File.join('tmpl','invisiclue.erb')), escape: true)
index = Erubi::Engine.new(File.read(File.join('tmpl','index.erb')), escape: true)
erubi = 

Dir["*.inv"].each do |filename|


  
  lines = File.readlines(filename)
  

in_header = true
unindented_starts_sections = false

sections = Hash.new {|h,k| h[k] = { lines: [] } }
current_section = "header"


current_list = sections[current_section][:lines]
lines.shift
lines.each do |line|
  case line.rstrip
  when /\A\*\**\*\Z/ # header box top or bottom or section underline: line of all *'s
    if in_header
      current_section = "indicia"
      in_header = false
    else
      current_section = current_list.pop
    end
    current_list = sections[current_section][:lines]
  when /\A(\S.*\?)\Z/ # a question: unindented line ending with ?
    current_list = (sections[current_section][$1] = [])
  when /\A\s+([A-Z]\.)\s+(.*)\Z/ # an answer: an indented line beginning [A-Z].
    current_list << $2
  when /\A\*\s+(.*?)\s+\*\Z/ # header box content: begins '* ' and ends ' *'
    current_list << $1.strip
  when /\A(\s*)(.*)\Z/ # catches all else
    current_list << $2.strip
  else
    puts "shouldn't have gotten here for #{line}"
  end
end


anchors = {}

sections.each do |name, content|
  content.each do |key, lines|
    lines.shift until lines.empty? or !lines.first.empty?
    lines.pop until lines.empty? or !lines.last.empty?
    content[key] = lines
  end
  content.delete(:lines) if content[:lines].empty?
end

2.times { sections["header"][:lines].shift }
if sections["header"][:lines].count > 1 # hello, hitchhiker's
  sections["header"][:lines].shift
  sections["header"][:lines].pop
end
  

sections["Table of Contents"][:lines].shift # Introduction
sections["Table of Contents"][:lines].each do |line|
  line.sub!(/\s*\([^\)]+\)/,'')
  converted = line.gsub(/\s+/,'_').gsub(/[^-\w]+/,'').downcase
  anchors[line] = converted
end

sections.each do |name, content|
  next unless content.key?(:lines)
  next if no_merge.member?(name)
  final = []
  current = []
  content[:lines].each do |line|
    if line.empty?
      final << current.join(' ')
      current = []
    else
      current << line
    end
  end
  final << current.join(' ') unless current.empty?
  sections[name][:lines] = final
end

sections["header"][:lines][0] = sections["header"][:lines][0].sub(/\(tm\)/i,'&trade;').sub(/\(r\)/i,'&reg;')
sections["indicia"][:lines][0].gsub!(/\A\[/,'')
sections["indicia"][:lines][-1].gsub!(/\]\Z/,'')

def render(tmpl, **hash)
  context = OpenStruct.new(hash).instance_eval { binding }
  eval(tmpl.src, context)
end


output_filename = File.basename(filename, '.inv').downcase + '.html'

File.open(File.join('docs', output_filename), "w") do |f|

  f.puts(render(invisiclue, sections: sections, anchors: anchors))

end

games[sections["header"][:lines].first] = output_filename

end

File.open(File.join('docs','index.html'),'w') do |f|
  f.puts(render(index, games: games))

end


