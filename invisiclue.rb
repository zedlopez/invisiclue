#!/usr/bin/env ruby

# usage: invisiclue.rb ZorkI.inv > zork.html

require 'erubi'
require 'set'
require 'ostruct'

lines = File.readlines(ARGV.shift)
in_header = true
unindented_starts_sections = false

sections = Hash.new {|h,k| h[k] = { lines: [] } }
current_section = "header"

unindented_sections = [ "indicia", "Table of Contents", "For Your Amusement" ].to_set

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

no_merge = [ 'Table of Contents', 'For Your Amusement', 'Progress Points', 'Treasures: Their Values and Locations' ].to_set

anchors = {}

sections.each do |name, content|
  content.each do |key, lines|
    lines.shift until lines.empty? or !lines.first.empty?
    lines.pop until lines.empty? or !lines.last.empty?
    content[key] = lines
  end
  content.delete(:lines) if content[:lines].empty?
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

erubi = Erubi::Engine.new(DATA.read, escape: true)

puts(render(erubi, sections: sections, anchors: anchors))

__END__
<!doctype html>
<html lang="en"><head><meta charset="UTF-8"><title>Invisiclues</title>
<style>* { padding: 0; margin: 0 ; }
html { font-size: 100%; }
body { 
color: #080808; 
background-color: #FAFAFA;
color: #0A0A0A;
width: 41.5rem;
margin: auto;
font-size: 100%;
margin-bottom: 2rem;
font-family: Helvetica Neue,Helvetica,Arial,sans-serif;
} 
h1.title { text-align: center; margin-top: 1rem; margin-bottom: 2rem; }
.other-versions { font-weight: bold; }
.other-versions > ul { margin-top: 1rem; }
header { margin: auto; }
div.ext-table { line-height: 1.5; width: 40rem; margin-bottom: 2rem; }
a.title { text-decoration-style: dotted; }
hr.border { border: .05rem solid #333; margin: 1rem .5rem 1rem -1.5rem; }
div.ext-name {  white-space: nowrap; width: 100%; margin-top: .1rem; font-size: 1.25rem; text-indent: -1.5rem; }
div.ext-desc { margin-bottom: .5rem; padding-top: .25rem; }
div.empty-desc { text-align: right; margin-right: .5rem; }
span.link { font-weight: bold;} 
span.version { font-size: 1rem; }
span.limiter { font-style: italic; font-size: 1rem; }
span.code { font-family: monospace; }
div.error { margin-left: -1.5rem; }
h2 { margin-top: 1rem; margin-bottom: 1rem; }
details { border: .1rem solid black; padding: .5rem; }
summary { margin: .5rem 0 .5rem 0; }
p.omission { margin-bottom: .5rem; }
</style>
</head>
<body>
<header>
</header>
                                    <% sections.each do |name, content| %>
<% if name == "header" %>
  <h1><%== content[:lines].first %></h1>
  <% next %>
<% end %>
  <% unless name == "indicia" %>
   <% candidate = name.sub(/\s*\([^\)]+\)/,'').sub(/\W*\Z/,'') %><!-- <%= candidate %> -->
  <h2<% if anchors.key?(candidate) %> id="<%= anchors[candidate] %>"<% end %>><%= name %></h2>
<% end %>
<% if name == "Table of Contents" %><ul>
  <% content[:lines].each do |line| %>
    <li><a href="#<%= anchors[line] %>"><%= line %></a></li>
  <% end %></ul>
  <% next %>
<% end %>
  <% if content.key?(:lines) %>
    <% if name.start_with?('Treasures') %><pre><%= content[:lines].join("\n") %></pre><% else %>
    <% content[:lines].each do |line| %>
      <p><%= line %></p>
    <% end %>
    <% end %>
  <% else %>
    <%  content.each do |question, answers| %>
      <p><%= question %></p>
      <% answers.each.with_index do |answer,i| %>
        <details><summary><%== ('A'.ord+i).chr %>.</summary><%= answer %></details>
      <% end %>
    <% end %>
  <% end %>
<% end %>
                                                                              </main></body></html>
