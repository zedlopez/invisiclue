#!/usr/bin/env ruby

require 'erubi'
require 'set'
require 'ostruct'

def should_merge?(section)
  section = section.downcase
  [ /\bhave you tried\b/, /how\b.*\bpoints\b/, /points\b.*\bscored\b/ ].each {|r| return false if r.match(section) }
  [ 'spells, potions, and their locations', 'for your amusement', 'treasure', 'things you can ask' ].each {|s| return false if section.start_with?(s) }
  return true
end

all_sections = Hash.new {|h,k| h[k] = [] }

$dont_capitalize = %w{ to the and }.to_set
def titleize(str)
  str.to_s.downcase.split(/\s/).map {|x| x.match(/\Ai+\Z/) ? x.upcase : ($dont_capitalize.member?(x) ? x : (x[0]=x[0].upcase; x))}.join(' ').sub(/\Athe /,'The ')
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

#invisiclue = Template.new('invisiclue.erb')
#index = Template.new('index.erb')
#question_template = Template.new('_question.erb')

Dir["*.inv"].each do |filename|
  lines = File.readlines(filename)
  in_header = true

  sections = Hash.new {|h,k| h[k] = { lines: [] } }
  current_section = "header"

  current_list = sections[current_section][:lines]
  lines.shift
  lines.each do |line|
    case line.chomp
    when /\A\*\**\*\Z/ # header box top or bottom or section underline: line of all *'s
      if in_header
        current_section = "indicia"
        in_header = false
      else
        current_section = titleize(current_list.pop)
      end
      current_list = sections[current_section][:lines]
    when /\A(\S.*\?)\Z/ # a question: unindented line ending with ?
      current_list = (sections[current_section][$1] = [])
    when /\A\s+([A-Z]\.)\s+(.*)\Z/ # an answer: an indented line beginning [A-Z].
      current_list << $2
    when /\A\*\s+(.*?)\s+\*\Z/ # header box content: begins '* ' and ends ' *'
      current_list << $1.strip
    when /\A((\s*)(.*))\Z/ # catches all else
      current_list << (should_merge?(current_section) ? $3.strip : $1)
    else
      puts "shouldn't have gotten here for #{line}"
    end
  end

  sections.each do |name, content|
    content.each do |key, lines|
      lines.shift until lines.empty? or !lines.first.empty?
      lines.pop until lines.empty? or !lines.last.empty?
      content[key] = lines
    end
    content.delete(:lines) if content[:lines].empty?
    sections.delete(name) if name.downcase == "table of contents"
  end

  2.times { sections["header"][:lines].shift }
  if sections["header"][:lines].count > 1 # hello, hitchhiker's
    sections["header"][:lines].shift
    sections["header"][:lines].pop
  end

  sections.each do |name, content|
    if content.key?(:lines)
      unless should_merge?(name)
        sections[name][:no_merge] = true
        sections[name][:mono] = true if name.downcase.start_with?('treasure')
        next
      end
      final = []
      current = []
      content[:lines].each do |line|
        line.strip!
        if line.empty?
          final << current.join(' ')
          current = []
        else
          current << line
        end
      end
      final << current.join(' ') unless current.empty?
      sections[name][:lines] = final
    else # doesn't have :lines, i.e. it's questions
      content.each do |question, answers|
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
  end

  header = titleize(sections["header"][:lines][0] = sections["header"][:lines][0].sub(/\(tm\)/i,'').sub(/\(r\)/i,''))
  sections.delete("header")
  indicia_lines = sections["indicia"][:lines]
  indicia_lines[0].gsub!(/\A\[/,'')
  indicia_lines[-1].gsub!(/\]\Z/,'')
  sections["Indicia"][:lines] = indicia_lines
  sample = sections["Sample Question"]

  sections.delete("Sample Question")
  sections.delete("indicia")
  sections.keys.each {|x| all_sections[x] << header }

  anchors = {}

  sections.each do |name, content|
    next if name == header
    converted = name.gsub(/\s+/,'_').gsub(/[^-\w]+/,'').downcase
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
