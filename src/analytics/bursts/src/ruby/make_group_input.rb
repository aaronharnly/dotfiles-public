#!/usr/bin/ruby

require('rubygems')
require('json')
require('CSV')

psf_measure_sid = 3
nwf_measure_sid = 4
orf_measure_sid = 5

phonological_awareness_sid = 1
letter_sounds_sid = 2
word_blends_sid = 3
regular_words_sid = 4
irregular_words_sid = 5
letter_combinations_sid = 6
advanced_phonics_sid = 7
reading_fluency_sid = 8

grade_map = {"K" => 2, "1" => 3, "2" => 4, "3" => 5}
inst_rec_map = {"r" => 1, "y" => 2, "g" => 3}

students = []
ARGF.each do |line|
  row = CSV.parse_line line
  
  classe_sid = row[1].to_i
  student_sid = row[3].to_i
  grade_sid = grade_map[row[4]]
  inst_rec = inst_rec_map[row[5]]
  
  student = {
	"sid" => student_sid,
	"classeSid" => classe_sid,
	"gradeSid" => grade_sid,
	"lastSupportRecTypeSid" => inst_rec,
	"scores" => [
		{"measure" => psf_measure_sid, "score" => row[12].to_i},
		{"measure" => nwf_measure_sid, "score" => row[13].to_i},
		{"measure" => orf_measure_sid, "score" => row[14].to_i}
	],
	"skills" => [
		{"sid" => phonological_awareness_sid, "lastLevel" => row[6].to_i, "bestLevel" => row[7].to_i},
		{"sid" => letter_sounds_sid, "lastLevel" => row[8].to_i, "bestLevel" => row[9].to_i},
		{"sid" => word_blends_sid, "lastLevel" => row[10].to_i, "bestLevel" => row[11].to_i}
	]}
    
  students.push student
end

request = {
	"maxStudentsPerGroups" => 5,
	"maxNbOfGroups" => 3,
	"forceUnderperfStudentsIntoGroups" => false,  
	"students" => students
}

puts JSON.pretty_generate(request)
