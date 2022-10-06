#!/usr/bin/env ruby

# usage: invisiclue.rb ZorkI.inv > zork.html

lines = File.readlines(ARGV.shift)

prev = nil


done_with_header = false

header = []
html = []
current_q = nil
paragraphs = []
sections = {}
current_section = nil

current_list = header
lines.shift
lines.each do |line|
  case line.rstrip
  when /\A\*\**\*\Z/
    if done_with_header
      current_section = current_list.pop
      sections[current_section] = {}
      current_list = []
    else
      done_with_header = true
      current_list = paragraphs
    end
  when /\A(\S.*\?)\Z/
    current_q = $1
    current_list = (sections[current_section][current_q] = [])
  when /\A\s+([A-Z]\.)\s+(.*)\Z/
    current_list << $2
  when /\A\s+(\S.*)\Z/
    if current_list.empty?
      current_list << $1
    else
      current_list[-1] += ' ' + $1
    end
  when /\A\*\s+(.*?)\s+\*\Z/
    current_list << $1
  else
    current_list = []
    current_list << line
  end
end

puts '<!doctype html>'
puts '<html lang="en"><body>'
sections.each do |name, questions|
  puts %Q{<h2>#{name}</h2>}
  questions.each do |question, answers|
    puts %Q{<p>#{question}</p>}
    answers.each.with_index do |answer,i|
      puts %Q{<details><summary>#{('A'.ord+i).chr}</summary>#{answer}</details>}
    end
  end
end
puts '</body></html>'
