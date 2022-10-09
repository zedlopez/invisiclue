#!/usr/bin/env ruby

require 'erubi'
require 'set'
require 'ostruct'

def should_merge?(section, filename)
  section = section.to_s.downcase
  return false if monospace?(section)
  [ /\bhave you tried\b/, /how\b.*\bpoints\b/, /points\b.*\bscored\b/, /spells\b.*\blocations/ ].each {|r| return false if r.match(section) }
  [ 'the quotations', 'guide entries', 'details of cubes', 'for your amusement', 'things you can ask' ].each {|s| return false if section.start_with?(s) }
  true
end

def monospace?(section)
  [ 'secret passage entrances', 'that which can be named', 'variable magic items', 'treasure' ].each {|s| return true if section.to_s.downcase.start_with?(s) }
  false
end

all_sections = Hash.new {|h,k| h[k] = [] }

def mixed_case?(str)
  return nil unless str
  str.to_s.match(/[A-Z]/) and str.match(/[a-z]/)
end

$dont_capitalize = %w{a an as by on to the and of up with m}.to_set
$dont_change = %w{i ii iii fc}
def titleize(str)
  orig = str.dup
  parenthetical = ""
  str.sub!(/\s*(\s\([^)]+\))/) {|m| parenthetical = $1; '' }
  first_word = true
  result = ""
  str = str.to_s.gsub (/\b(([A-Za-z])([A-Za-z]+?)?)\b/) do |m|
    whole, first, remaining = $1, $2, $3
    remaining ||= ""
    if mixed_case?(remaining) or $dont_change.member?(whole.downcase)
      result = whole
    else
      result = (((first_word or !$dont_capitalize.member?(whole.downcase)) ? first.upcase : first.downcase) + remaining.downcase)
    end
    first_word = false
    result
  end
  str.gsub!(/'S/,"'s")
  str.gsub!(/-- the/,'-- The')
  str += parenthetical unless parenthetical.empty?
  char_replace(str)
end

def char_replace(str)
  str.gsub!(/\.\.\./,'…')
  str.gsub!(/--/,'–')
  str
end

games = {}

class Template
  def initialize(filename)
    @tmpl = Erubi::Engine.new(File.read(File.join('tmpl',filename)), escape: true)
  end

  def render(**hash)
    context = OpenStruct.new(hash).instance_eval { binding }
    eval(@tmpl.src, context)
  end
end

templates = OpenStruct.new(%w{ invisiclue index _question _footer }.map {|x| [ x.sub(/\A_/,''), Template.new("#{x}.erb")] }.to_h)

Dir["*.inv"].each do |filename|
  lines = File.readlines(filename)
  sections = Hash.new {|h,k| h[k] = { lines: [] } }
  
  header = titleize(((filename == "HHGG.inv") ? lines[4] : lines[3]).gsub(/\*/,'').strip.sub(/\(tm\)/i,'').sub(/\(r\)/i,''))
  lines.slice!(0, ((filename == "HHGG.inv") ? 7 : 5))
  uncertain = false
  question = nil 
  current_section = "indicia"
  original_line = nil
  prev_indent = 0
  indent = 0
  current_list = sections[current_section][:lines]
  lines.push nil
  lines.each_cons(2) do |line, next_line|
    prev_line = original_line
    original_line = line
    line.chomp!
    case line.rstrip
    when /\A\*\**\*\Z/ # section underline
      next
    when /\A(\S.*)\Z/ # unindented line
      content = $1
      if next_line and next_line.match(/\A\*\**\*\Z/) # new section
        current_section = titleize(content.strip)
        current_list = sections[current_section][:lines]
      elsif current_section == "indicia"
        current_list << content
      elsif !should_merge?(current_section, filename) #and !line.strip.empty?
        current_list << line 
      else # if we're unindented and not in indicia and this isn't a new section header, we're in a question
        current_list = [] if prev_line.strip.empty?
        current_list << content
        if current_list[-1].match(/[:?.!]\Z/)
          question = current_list.join(' ')
          current_list = (sections[current_section][question] = [] )
        elsif next_line and next_line.strip.empty?
          sections[current_section][:lines] = current_list
        end
      end
    when /\A(\s+)(?:((?:-|[A-Z0-9]+)\.?))?\s+(.*)\Z/ # indented line, possibly an answer
      if !should_merge?(current_section, filename)
        current_list << line
        next
      end
      current_indent = ($1 ? $1.length : 0)
      if current_indent != indent
        prev_indent = indent
        indent = current_indent
      end
      label = $2
      content = $3.strip
      if question
        if label or (current_list.empty?) or (indent > prev_indent)
          current_list << content
        else
          current_list[-1] += ' ' + content
        end
      else
        current_list << line
      end
    when /\A\s*\Z/
      current_list << (monospace?(current_section) ? "\n" : "")
      question = nil
    when nil
      break
    else
      puts "shouldn't have gotten here for #{line} in #{filename}"
    end
  end

  sections.delete("Table of Contents")
  
  sections.each do |name, content|
    content.delete(:lines) if content[:lines].empty?
    next if Symbol === name
    content.each do |key, lines|
      next unless Array === lines
      lines.shift until lines.empty? or !lines.first.empty?
      lines.pop until lines.empty? or !lines.last.empty?
      content[key] = lines
    end
  end

  sections.each do |name, content|
    if content.key?(:lines)
      if monospace?(name)
        sections[name][:mono] = true 
        next
      end
      unless should_merge?(name, filename)
        sections[name][:no_merge] = true
        content[:indents] = {}
        content[:lines] = content[:lines].map.with_index(0) {|x,i| x.match(/\A(\s*)(.*)\Z/); content[:indents][i] = ($1 ? $1.length : 0); $2 }.map {|y| char_replace(y) }
        next
      end
      final = []
      current = []
      content[:lines].each do |line|
        line.strip!
        if line.empty?
          final << current.join(' ') unless current.empty?
          current = []
        else
          current << line
        end
      end
      final << current.join(' ') unless current.empty?
      sections[name][:lines] = final.map {|x| char_replace(x) }
    end
      content.each do |question, answers|
        next if Symbol === question
        replace = []
        if answers.any? {|x| x.match(/This space.*left.*blank/i) }
          answers.each.with_index do |answer,i|
            replace << i if answer.match(/\A(\d+\.\s*)?(?:\+\-+\+|\|\s+\|)\Z/) or answer.match(/This space.*left.*blank/i)
          end
          replace.each {|x| sections[name][question][x] = ((x == (answers.count-1)) ?  'This answer left intentionally blank.' : 'This answer and the ones beneath it left intentionally blank.') }
        elsif answers.any? {|x| x.match(/(drawing of.*cannot be included in a text file)/i) }
          text = $1
          replace = []
          answers.each.with_index do |answer,i|
            replace << i if answer.match(/\A(\d+\.\s*)?(?:\+\-+\+|\|\s+\|)\Z/) or answer.match(/drawing of.*cannot be included in a text file/)
          end
          replace.reverse.each {|x| sections[name][question].slice!(x) }
          sections[name][question] << "[ #{text} ]"
        end
        end
  end
  
  indicia_lines = sections["indicia"][:lines]
  indicia_lines[0].gsub!(/\A\[/,'')
  indicia_lines[-1].gsub!(/\]\Z/,'')
  sections["Indicia"][:lines] = indicia_lines

  sample = sections["Sample Question"]
  
  sections.delete("Sample Question")
  sections.delete("indicia")

  anchors = {}

  sections.each do |name, content|
    next if name == header
    converted = name.gsub(/\s+/,'_').gsub(/\W+/,'').downcase
    anchors[name] = converted
  end

  output_filename = File.basename(filename, '.inv').downcase + '.html'

  File.open(File.join('docs', output_filename), "w") do |f|
    f.puts templates.invisiclue.render(sections: sections, anchors: anchors, header: header, indicia: indicia_lines, sample: sample, templates: templates)
  end

  games[header] = output_filename

end

File.open(File.join('docs','index.html'),'w') do |f|
  f.puts(templates.index.render(games: games, templates: templates))
end

#all_sections.keys.sort.each do |k|
# puts %Q{#{k} #{ should_merge?(k) ? '' : "don't merge "} #{all_sections[k].sort.join(' ')}}
#end
