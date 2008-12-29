 /** <module> The Bursts Generation Algorithm

Predicates to paramatize burst content, based on student skills and previous intervention history
@version $Id: burst.pro,v 1.38 2008/12/18 15:44:34 jds Exp $
*/

/**
	generate_burst(+Students:list, +InstructionHistory:list, +NumDays:int, -Burst:term)
	
	Creates parameters for the burst generator
	
	@param Students is a list of student/7 objects
	@param InstructionHistory is a list of instruction/4 objects
	@param NumDays is the number of days' worth of steps to generate
	@param Burst is a burst/7 object
*/

generate_burst(UnaugmentedStudents, InstructionHistory, NumDays, Burst) :-
	% set levels for unspecified skills to 0
	maplist(augment_skill_levels, UnaugmentedStudents, Students),
	print_message(detail, format('generate burst: ~w ~w ~w ~w', [Students, InstructionHistory, NumDays, Burst])),
	
	% compute the ZPD skills for these students
	length(Students, NumStudents),
	zpd_skills(Students, NumStudents, Skill1, Skill2),
	print_message(detail, format('~w', zpd_skills(Skill1, Skill2))),
	
	% identify the lowest skill level for each skill,
	lowest_skill_level(Students, Skill1, SkillLevel1),
	lowest_skill_level(Students, Skill2, SkillLevel2),
	
	% map the skills and levels to strands
	% first get the grade of the group
	group_grade(Students, Grade),
	select_strand(Skill1, SkillLevel1, Grade, InstructionHistory, Strand1),
	select_strand(Skill2, SkillLevel2, Grade, InstructionHistory, Strand2),
	
	% the strand may not correspond to the skill; determine the correct skills from the strands
	strand_to_teach(ActualSkill1, _, _, Strand1),
	strand_to_teach(ActualSkill2, _, _, Strand2),
	lowest_skill_level(Students, ActualSkill1, ActualSkillLevel1),
	lowest_skill_level(Students, ActualSkill2, ActualSkillLevel2),
	
	% identify the progress-monitoring probes
	skill_measure(ActualSkill1, Measure1),
	skill_measure(ActualSkill2, Measure2),
	
	% find the next steps to be taught
	next_burst_step_for_group(Strand1, ActualSkill1, ActualSkillLevel1, NumDays, Students, InstructionHistory, NextStep1),
	next_burst_step_for_group(Strand2, ActualSkill2, ActualSkillLevel2, NumDays, Students, InstructionHistory, NextStep2),
	
	% set the appropriate pacing
	set_pace_for_group(Strand1, ActualSkill1, ActualSkillLevel1, Students, InstructionHistory, Pace1),
	set_pace_for_group(Strand2, ActualSkill2, ActualSkillLevel2, Students, InstructionHistory, Pace2),
	
	% identify low and high outliers
	include(low_outlier_for_skill(ActualSkill1, ActualSkill2), Students, LowOutliers1),
	include(low_outlier_for_skill(ActualSkill2, ActualSkill1), Students, LowOutliers2),
	include(high_outlier(ActualSkill1, ActualSkill2), Students, HighOutliers),
	
	% we have everything: wrap it up into a structure
	make_content(Strand1, Pace1, NextStep1, Content1),
	make_content(Strand2, Pace2, NextStep2, Content2),
	make_burst(
		[ActualSkill1, ActualSkill2],
		[Measure1, Measure2],
		[Content1, Content2],
		[low_outliers(ActualSkill1, LowOutliers1), low_outliers(ActualSkill2, LowOutliers2)],
		HighOutliers,
		% FIXME jds put something more interesting in the trace string?
		'hello from the burst generator $Revision: 1.38 $',
		Burst), !.
		
% if burst generation fails, log the event and return a null data structure
generate_burst(Students, InstructionHistory, NumDays, Burst) :-
	print_message(warning, goal_failed(generate_burst, [Students, InstructionHistory, NumDays])),
	make_burst(
		[],
		[],
		[],
		[],
		[],
		'failed to generate burst $Revision: 1.38 $',
		Burst).

/**
	select_strand(+Skill:atom, +SkillLevel:int, +Grade:atom, +InstructionHistory:list, -Strand:atom) is det
	
	Determines the strand to teach.
	
	@param Skill is the skill that needs to be addressed.
	@param SkillLevel is the lowest level of the skill in the group
	@param Grade is the grade of the group
	@InstructionHistory is a list of instruction/4 objects
	@param Strand is the strand to be taught
*/
% if irregular words are to be taught, but letter combinations is incomplete or has neven been taught, teach letter combinations.
select_strand(Skill, SkillLevel, Grade, InstructionHistory, letter_combinations) :-
	strand_to_teach(Skill, SkillLevel, Grade, irregular_words),
	not(strand_exhausted(InstructionHistory, letter_combinations)).
	
select_strand(Skill, SkillLevel, Grade, _, Strand) :-
	strand_to_teach(Skill, SkillLevel, Grade, Strand).
	

/**
	next_burst_step(+Strand:atom, +SkillLevel+int, +NumDays:int, +Students:list, +InstructionHistory:list, ?NextStep:int)
	
	Calculates the next step for a given strand for a group
	
	@param Strand is the name of an instruction strand
	@param SkillLevel, is a skill level, one of {0, 1, 2}, representing the lowest skill level for the (implied) group
	@param NumDays is the number of days' worth of instruction to generate
	@param Students is a list of student/7 objects
	@param InstructionHistory is a list of instuction/4 objects
	@param NextStep the next step in the strand to teach
*/
next_burst_step(Strand, _, NumDays, _, InstructionHistory, NextStep) :-
	last_instruction_for_strand(InstructionHistory, Strand, LastInstruction),
	instruction_content(LastInstruction, [Content1, Content2]),
	(	content_strand(Content1, Strand) 
		-> content_sequence(Content1, LastStep)
		; content_sequence(Content2, LastStep)
	),
	NextStep is LastStep + NumDays,
	!.
% if the strand was not previounly taught, start at specified defaults
next_burst_step(phonemic_awareness, 1, _, _, _, 17) :- !.
next_burst_step(letter_sounds, 1, _, _, _, 31) :- !.
next_burst_step(sounding_out, 1, _, _, _, 56) :- !.
next_burst_step(connected_text, _, _, Students, _, 35) :- 
	lowest_skill_level(Students, irregular_words, IWLevel),
	skill_mastered(IWLevel), !.
next_burst_step(connected_text, _, _, Students, _, 35) :-
	group_grade(Students, 1), !.
	
next_burst_step(_, _, _, _, _, 1).

/** 
	group_grade(+Students:list, -Grade:atom)
	
	Reduces a list of students to a grade, using the mode operator.
	
	@param Students is a list of student/7 objects
	@param Grade the grade mode of the class
*/
group_grade(Students, Grade) :-
	maplist(student_grade, Students, Grades),
	count_keys(Grades, [Grade-_ | _]).
	
/**
	set_pace(+Strand:atom, +SkillLevel:atom, +InstructionHistory:list, -Pace:atom)
	
	Determines the proper pace for a strand, given a skill level

	@param Strand is the name of the strand
	@param SkillLevel is a skill level, one of {0, 1, 2}, representing the lowest skill level for the (implied) group
	@param is a list of instruction/4 objects
*/
% continue the same pace in the strand if there is history
set_pace(Strand, _, InstructionHistory, LastPace) :-
	last_pace_for_strand(InstructionHistory, Strand, LastPace), !.
% otherwise find the correct initial pace
set_pace(letter_sounds, 1, _, hot) :- !.
set_pace(sounding_out, 1, _, hot) :- !.
set_pace(letter_combinations, 1, _, hot) :- !.
% default to warm
set_pace(_, _, _, warm).


/**
	strand_exhausted(+Strand:atom, +InstructionHistory:list) is det
	
	Succeeds if all slots of the strand have been generated.
	
	@param Strand is the strand
	@param InstructionHistory is a list of instruction/4 objects
*/
strand_exhausted(Strand, InstructionHistory) :-
	last_pace_for_strand(InstructionHistory, Strand, LastPace),
	last_sequence_for_strand(InstructionHistory, Strand, LastSequence),
	findall(Sequence, content_slot(Strand, Sequence, LastPace), Sequences),
	sort(Sequences, SortedSequences),
	reverse(SortedSequences, [_, S2 | _ ]),
	LastSequence > S2.
	
% ---------- IMPLEMENTATION ----------

extract_strand(Strand, Instruction) :-
	instruction_content(Instruction, [Content1, Content2]),
	(	content_strand(Content1, Strand) 
		; content_strand(Content2, Strand)
	).
	
% special case for null students
lowest_skill_level(Students, _, 0) :-
	exclude(null_student, Students, []).
lowest_skill_level(Students, Skill, SkillLevel) :-
	maplist(student_best_skill_level(Skill), Students, SkillLevels),
	count_keys(SkillLevels, SkillLevelCounts),
	sort(SkillLevelCounts, [SkillLevel-_ | _]).
% default the lowest skill level to 0 
% lowest_skill_level(_, _, 0).

last_instruction_for_strand(InstructionHistory, Strand, LastInstruction) :-
	include(extract_strand(Strand), InstructionHistory, FilteredHistory),
	sort(FilteredHistory, SortedFilteredHistory),
	last(SortedFilteredHistory, LastInstruction).
	
last_pace_for_strand(InstructionHistory, Strand, LastPace) :-
	last_instruction_for_strand(InstructionHistory, Strand, LastInstruction),
	instruction_content(LastInstruction, [Content1, Content2]),
	(	content_strand(Content1, Strand) ->
		LastContent = Content1
	;	LastContent = Content2
	),
	content_pace(LastContent, LastPace).
	
last_sequence_for_strand(InstructionHistory, Strand, LastSequence) :-
	last_instruction_for_strand(InstructionHistory, Strand, LastInstruction),
	instruction_content(LastInstruction, [Content1, Content2]),
	(	content_strand(Content1, Strand) ->
		LastContent = Content1
	;	LastContent = Content2
	),
	content_sequence(LastContent, LastSequence).
	
low_outlier_for_skill(FocusSkill, OtherFocusSkill, Student) :-
	zpd_skills([Student], 1, Skill1, Skill2),
	(	(	depends(FocusSkill, Skill1), not(Skill1 = OtherFocusSkill))
	;	(	depends(FocusSkill, Skill2), not(Skill2 = OtherFocusSkill))
	).
	
next_step_for_student(Strand, Skill, Student, NextStep) :-
	student_best_skill_level(Skill, Student, SkillLevel),
	student_instruction_history(Student, InstructionHistory),
	next_burst_step(Strand, SkillLevel, 1, [Student], InstructionHistory, NextStep).

pace_for_student(Strand, Skill, Student, PaceSid) :-
	student_best_skill_level(Skill, Student, SkillLevel),
	student_instruction_history(Student, InstructionHistory),
	set_pace(Strand, SkillLevel, InstructionHistory, Pace),
	pace(PaceSid, Pace).
	
% ensure that we check the student histories only when group history is empty
next_burst_step_for_group(Strand, Skill, SkillLevel, NumDays, Students, [], NextStep) :-
	maplist(next_step_for_student(Strand, Skill), Students, StudentNextSteps),
	sort(StudentNextSteps, [StudentNextStep | _]),
	next_burst_step(Strand, SkillLevel, NumDays, Students, [], GroupNextStep),
	NextStep is max(GroupNextStep, StudentNextStep).
next_burst_step_for_group(Strand, _, SkillLevel, NumDays, Students, InstructionHistory, NextStep) :-
	next_burst_step(Strand, SkillLevel, NumDays, Students, InstructionHistory, NextStep).

% ensure that we check the student histories only when group history is empty
set_pace_for_group(Strand, Skill, SkillLevel, Students, [], LastPace) :-
	maplist(pace_for_student(Strand, Skill), Students, StudentPaceSids),
	sort(StudentPaceSids, [StudentPaceSid | _]),
	set_pace(Strand, SkillLevel, [], GroupPace),
	pace(GroupPaceSid, GroupPace),
	LastPaceSid is max(GroupPaceSid, StudentPaceSid),
	pace(LastPaceSid, LastPace).
set_pace_for_group(Strand, _, SkillLevel, _, InstructionHistory, LastPace) :-
	set_pace(Strand, SkillLevel, InstructionHistory, LastPace).

% ---------- TESTS ----------

load_burst_request(Filename, BurstRequest) :-
	open(Filename, read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_burst_request(JsonRequest, BurstRequest),
	!.
	
:- begin_tests(burst).

test(next_burst_step, [true(PhoA-PheA=13-3)]) :-
	load_burst_request('test/data/burst_input.json', burst_request(_, InstructionHistory, NumDays)), 
	next_burst_step(phonological_awareness, 1, NumDays, _, InstructionHistory, PhoA),
	next_burst_step(phonemic_awareness, 1, NumDays, _, InstructionHistory, PheA).
	
test(group_grade, []) :-
	load_burst_request('test/data/burst_input.json', burst_request(Students, _, _)),
	group_grade(Students, 1).
	
test(generate_burst, []) :-
	load_burst_request('test/data/burst_input.json', burst_request(Students, InstructionHistory, NumDays)),
	generate_burst(Students, InstructionHistory, NumDays, Burst),
	burst_skills(Burst, [phonological_awareness, letter_sounds]),
	burst_measures(Burst, [psf, nwf]),
	burst_content(Burst, [content(phonemic_awareness, warm, 17), content(letter_sounds, hot, 61)]),
	burst_low_outliers(Burst, [low_outliers(phonological_awareness, []), low_outliers(letter_sounds, [])]),
	burst_high_outliers(Burst, []).
	
test(lowest_skill_level, []) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 844945, Class1),
	select_class(Students, 845045, Class2),
	append(Class1, Class2, Classes),
	form_groups(2, 5, Classes, [_, Group1]),!,
	lowest_skill_level(Group1, phonological_awareness, 1),
	lowest_skill_level(Group1, blending, 0).
	
test(burst_level_2_skills, []) :-
	load_burst_request('test/data/burst_13162910.json', burst_request(Students, InstructionHistory, NumDays)),
	generate_burst(Students, InstructionHistory, NumDays, Burst),
	burst_skills(Burst, [phonological_awareness, regular_words]),
	burst_content(Burst, [content(phonemic_awareness, _, _), content(connected_text, _, _)]).
	
test(invalid_burst_request, []) :-
	generate_burst([], [], 1, Burst),
	make_burst(
		[],
		[],
		[],
		[],
		[],
		_,
		Burst).
		
test(set_pace_no_history, []) :-
	set_pace(phonological_awareness, _, [], warm),
	set_pace(phonemic_awareness, _, [], warm),
	set_pace(letter_sounds, 0, [], warm),
	set_pace(letter_sounds, 1, [], hot),
	set_pace(sounding_out, 0, [], warm),
	set_pace(sounding_out, 1, [], hot),
	set_pace(connected_text, 0, [], warm),
	set_pace(connected_text, 1, [], warm),
	set_pace(irregular_words, 0, [], warm),
	set_pace(irregular_words, 1, [], warm),
	set_pace(letter_combinations, 0, [], warm),
	set_pace(letter_combinations, 1, [], hot).
	
	
test(strand_exhausted, []) :-
	InstructionHistory = [
		instruction('2007-11-19 02:34:28', [regular_words, letter_sounds], [psf, isf], [content(phonemic_awareness, cool, 10), content(phonological_awareness, cool, 0)]), 
		instruction('2008-02-10 02:34:28', [regular_words, letter_sounds], [psf, isf], [content(phonemic_awareness, cool, 20), content(phonological_awareness, cool, 10)]), 
		instruction('2008-03-28 02:34:28', [letter_sounds, regular_words], [isf, psf], [content(phonological_awareness, cool, 30), content(phonemic_awareness, cool, 20)]), 
		instruction('2008-03-28 02:34:31', [regular_words, letter_sounds], [psf, isf], [content(phonemic_awareness, cool, 40), content(phonological_awareness, cool, 30)]), 
		instruction('2008-04-01 02:34:28', [regular_words, letter_sounds], [psf, isf], [content(sounding_out, cool, 50), content(letter_sounds, cool, 60)]), 
		instruction('2008-06-19 02:34:28', [regular_words, letter_sounds], [psf, isf], [content(phonemic_awareness, cool, 2), content(phonological_awareness, cool, 30)]), 
		instruction('2007-07-19 02:34:28', [regular_words, letter_sounds], [psf, isf], [content(phonemic_awareness, cool, 10), content(phonological_awareness, cool, 20)])],
	not(strand_exhausted(phonemic_awareness, InstructionHistory)),
	strand_exhausted(phonological_awareness, InstructionHistory).

test(next_burst_step_pho1, [true(NextStep=17)]) :-
	next_burst_step(phonemic_awareness, 1, _, _, [], NextStep).
test(next_burst_step_ls1, [true(NextStep=31)]) :-
	next_burst_step(letter_sounds, 1, _, _, [], NextStep).
test(next_burst_step_bl1, [true(NextStep=56)]) :-
	next_burst_step(sounding_out, 1, _, _, [], NextStep).
test(next_burst_step_rw_has_iw, [true(NextStep=35), nondet]) :-
	load_burst_request('test/data/burst_input.json', burst_request(Students, _, _)),
	next_burst_step(connected_text, _, _, Students, [], NextStep).
test(next_burst_step_rw_grade1, [true(NextStep=35), nondet]) :-
	load_burst_request('test/data/burst_input_grade1.json', burst_request(Students, _, _)),
	next_burst_step(connected_text, _, _, Students, [], NextStep).
	
% outlier identification tests
	
test(low_outlier, [true(LowOutliersSids = [126568066]), nondet]) :-
	load_burst_request('test/data/burst_input_outliers.json', burst_request(Students, _, _)),
	include(low_outlier_for_skill(irregular_words, regularish_words), Students, LowOutliers),
	include(low_outlier_for_skill(regularish_words, irregular_words), Students, LowOutliers),
	maplist(student_sid, LowOutliers, LowOutliersSids).
	
test(high_outlier, [true(HighOutliersSids = [126568178]), nondet]) :-
	load_burst_request('test/data/burst_input_outliers.json', burst_request(Students, _, _)),
	include(high_outlier(irregular_words, regularish_words), Students, HighOutliers),
	maplist(student_sid, HighOutliers, HighOutliersSids).
	

:- end_tests(burst).
