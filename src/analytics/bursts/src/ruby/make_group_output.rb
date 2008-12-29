#!/usr/bin/ruby

require('rubygems')
require('json')
require('CSV')

def label_group(group)
	classes = Hash.new {|hash, key| hash[key] = 0}
	group.each do |pair|
		classes[pair[0]] += 1
	end
	sorted_classes = classes.sort {|a,b| a[1] <=> b[1]}
	sorted_classes.last[0]
end

groups = Hash.new {|hash, key| hash[key] = Array.new}
ARGF.each do |line|
  row = CSV.parse_line line
  group_sid = row[15]
  if group_sid != nil then
	classe_sid = row[1].to_i
	student_sid = row[3].to_i
	groups[group_sid.to_i].push [classe_sid, student_sid]
  end
end

response_groups = []
groups.each_value do |group| 
	classe_sid = label_group(group)
	response_groups.push({
		"classeSid" => classe_sid,
		"studentSids" => group.collect {|_, student_sid| student_sid}
	})
end

response = {
	"groups" => response_groups
}

puts JSON.pretty_generate(response)
