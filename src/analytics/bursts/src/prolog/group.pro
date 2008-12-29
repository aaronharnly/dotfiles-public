/** <module> The Bursts Grouping Algorithm

This is where the magic really happens.
@version $Id: group.pro,v 1.45 2008/12/09 21:52:15 jds Exp $

*/

/**
	groups(+NumGroups:int, +StudentsPerGroup:int, Students:list, Groups:list)
	
	Partitions the list of students into a set of groups,
	returns the list of student sids for each group, along with its classe sid
	
	@param NumGroups the number of groups to create
	@param StudentsPerGroup the number of students to place in each group
	@param Students a list of student/6 objects
	@param Groups a list of group(classe_sid, list of student_sid) terms
*/	
group(NumGroups, StudentsPerGroup, Students, Groups) :-
	form_groups(NumGroups, StudentsPerGroup, Students, GroupedStudents),
	reverse(GroupedStudents, ReversedGroupedStudents),
	maplist(reduce_group, ReversedGroupedStudents, Groups). 

/**
	form_groups(+NumGroups:int, +StudentsPerGroup:int, Students:list, Groups:list)
	
	Partitions the list of students into a set of groups.
	
	@param NumGroups the number of groups to create
	@param StudentsPerGroup the number of students to place in each group
	@param Students a list of student/6 objects
	@param Groups a list of lists of students
*/
form_groups(NumGroups, StudentsPerGroup, Students, Groups) :-
	maplist(augment_skill_levels, Students, AugmentedStudents),
	form_groups_iter(NumGroups, StudentsPerGroup, AugmentedStudents, [], Groups).

/**
	form_group(+NumGroup:int, +StudentsPerGroup:int, +Students:list, -Group:list, -StudentsRemaining:list)
	
	Creates a group from a list of students, based on the grouping algorithm
	
	@param NumGroup is an arbitrary integer representing the grouping request, useful for tracing
	@param StudentsPerGroup is the maximum number of students in the group
	@param Students is a list of student/6 objects
	@param Group is a list of student/6 objects, the group formed
	@param StudentsRemaining is a list of student/6 objects remaining from the original set
*/	
form_group(NumGroup, StudentsPerGroup, Students, Group, StudentsRemaining) :-
	% remove null students; they are not candidates for grouping
	exclude(null_student, Students, NonNullStudents),
	% the actual size of the group is the minimum of the requested and the number of candidate students
	length(NonNullStudents, NumStudents),
	ActualGroupSize is min(StudentsPerGroup, NumStudents),
	% identify the skills to teach
	zpd_skills_no_outliers(NonNullStudents, ActualGroupSize, Skill1, Skill2),
	print_message(detail, format('form group: ~w', zpd_skills(Skill1, Skill2))),
	% remove the low and high outliers from the student set
	exclude(outlier(Skill1, Skill2), NonNullStudents, Students1),
	% sort the students
	sort_students(Skill1, Skill2, Students1, SortedStudents),
	print_message(detail, format('form group: ~w', sorted_students(SortedStudents))),
	length(SortedStudents, NumSortedStudents),
	% return the top N students
	N is min(NumSortedStudents, StudentsPerGroup),
	append(Group, _, SortedStudents),
	length(Group, N),
	subtract(Students, Group, StudentsRemaining),
	% (	NumGroup = 8 -> nl, write(form_group(NumGroup, StudentsPerGroup, Students, A, B)), nl ; true ),
	print_message(detail, format('form group: ~w', group(Group))),
	!.
% if the request fails, then return an empty group and log the event
form_group(NumGroup, StudentsPerGroup, Students, [], Students) :-
	print_message(warning, goal_failed(form_group, [NumGroup, StudentsPerGroup, Students])).
/**
	assign_group_to_class(+Group:list, ?Class:int) is det
	
	Unifies Class with the mode of the classes to which students in Group are assigned.
	This is a rough heuristic for attaching a class label to a group of students.
	
	@param Group a list of students
	@param Class the classe_sid of the class that best matches the students in the group
*/
% empty group gets null class
assign_group_to_class([], @null) :- !.
% otherwise look for the mode of the group wrt class
assign_group_to_class(Group, Class) :-
	maplist(student_classe_sid, Group, Classes),
	count_keys(Classes, [Class-_ | _]).
	
/** 
	sort_students(+Skill1:atom, +Skill2:atom, +UnsortedGroup:list, -SortedGroup:list) is det
	
	Re-orders a list of students such that the student with the least mastery appears first, the most accomplished last.
	The sort is relative to the specified skills.
	See compare_students/5 below for the decision logic of the sort.
	
	@param Skill1 a zpd skill
	@param Skill2 the second zpd skill
	@param UnsortedGroup a list of students
	@param SortedGroup a list of students in sorted order
*/
sort_students(Skill1, Skill2, UnsortedGroup, SortedGroup) :-
	predsort(compare_students(Skill1, Skill2), UnsortedGroup, SortedGroup).
	
/**
	compare_students(+Skill1:atom, +Skill2:atom, -Delta:atom, +Student1:student/7, +Student2:student/7) is det
	
	Sorting predicate to order a pair of students.
	
	@param Skill1 a zpd skill
	@param Skill2 the second zpd skill
	@param Delta the proper order of the two students: one of >, < or =
	@param Student1 a student/7 structure
	@param Student2 a student/7 structure
	
*/
% first compare the levels of the two zpd skills
compare_students(Skill1, Skill2, Delta, Student1, Student2) :-
	compare_skills(Skill1, Skill2, Student1, Student2, Delta),
	not(Delta = (=)).
% then check the paces on strands that the students would receive
compare_students(Skill1, Skill2, Delta, Student1, Student2) :-
	compare_paces(Skill1, Skill2, Student1, Student2, Delta),
	not(Delta = (=)).
% now compare to sequence numbers in the strands that students would start at 
compare_students(Skill1, Skill2, Delta, Student1, Student2) :-
	compare_sequences(Skill1, Skill2, Student1, Student2, Delta),
	not(Delta = (=)).
% finally check the scores of the measures associated with the zpd skills
compare_students(Skill1, Skill2, Delta, Student1, Student2) :-
	compare_scores(Skill1, Skill2, Student1, Student2, Delta),
	not(Delta = (=)).
% if the comparison fails, (e.g. no skills or scores), leave the current order as is
compare_students(_, _, >, _, _).
	
/**
	zpd_skills(+Students:list, -Skill1:atom, -Skill2:atom) is det
	
	Identifies the two ZPD skills to teach to a list of students
	
	@param Students a list of students
	@param StudentsPerGroup size of the requested group
	@param Skill1 a ZPD skill
	@param Skill2 a second ZPD skill
*/
% special case for students with only null skills: teach PhoA and LS
zpd_skills(Students, _, phonological_awareness, letter_sounds) :-
	exclude(null_student, Students, []).
zpd_skills(Students, StudentsPerGroup, Skill1, Skill2) :-
	count_non_mastered_skills(Students, NonMasteredSkills),
	select_earliest_largest_skill_to_teach(StudentsPerGroup, NonMasteredSkills, Skill1),
	delete(NonMasteredSkills, Skill1-_, ReducedNonMasteredSkills),
	% FIXME jds: if only one skill is specified for, or just one is unmastered, then search for a nearby skill 
	% as the second, making sure that it hasn't been acquired.
	% but: what if the one skill is the last one in the graph?
	(	select_earliest_largest_skill_to_teach(StudentsPerGroup, ReducedNonMasteredSkills, Skill2)
		; next_unacquired_skill(Skill1, NonMasteredSkills, [], Skill2)
	).

% select skills recursively, excluding LOW outliers
zpd_skills_no_outliers(Students, StudentsPerGroup, Skill1, Skill2) :-
	zpd_skills(Students, StudentsPerGroup, S1, S2), 
	exclude(low_outlier(S1, S2), Students, NonOutlierStudents),
	(	Students = NonOutlierStudents
		-> (Skill1 = S1, Skill2 = S2)
		;	zpd_skills_no_outliers(NonOutlierStudents, StudentsPerGroup, Skill1, Skill2)
	).
	
	
% ----------- IMPLEMENTATION ----------

% quit when we've generated the requested number of groups
form_groups_iter(NumGroups, _, _, Groups, Groups) :-
	length(Groups, NumGroups), !.
% quit when we're run out of students to group
form_groups_iter(_, _, [], Groups, Groups) :- !.
% otherwise create a group, and keep going
form_groups_iter(NumGroups, StudentsPerGroup, Students, GroupsIn, Groups) :-
	length(GroupsIn, NumGroupsFormed),
	NumGroup is NumGroupsFormed + 1,
	form_group(NumGroup, StudentsPerGroup, Students, Group, StudentsRemaining),
	form_groups_iter(NumGroups, StudentsPerGroup, StudentsRemaining, [Group | GroupsIn], Groups).
	
% if the current group is complete, push it to the formed groups and create a new one
% but only if there are more groups to create
assign_student(NumGroups, StudentsPerGroup, Student, GroupIn, GroupsIn, [Student], [GroupIn | GroupsIn]) :-
	length(GroupIn, StudentsPerGroup),
	length(GroupsIn, NumGroupsIn),
	NumGroupsIn < NumGroups.
% otherwise append the student to the current group.
assign_student(_, _, Student, GroupIn, GroupsIn, [Student | GroupIn], GroupsIn).

% map a group of students to just the sids + the classe_sid label
% no skills for an empty group
reduce_group([], group(@null, [], [])) :-
	!.
reduce_group(Group, group(ClasseSid, StudentSids, [Skill1, Skill2])) :-
	maplist(student_sid, Group, StudentSids),
	assign_group_to_class(Group, ClasseSid),
	length(Group, NumStudents),
	zpd_skills(Group, NumStudents, Skill1, Skill2), !.
% failure case, usually related to zpd-skill generation
reduce_group(Group, group(ClasseSid, StudentSids, [])) :-
	print_message(warning, goal_failed(reduce_group, reduce_group(Group))),
	maplist(student_sid, Group, StudentSids),
	assign_group_to_class(Group, ClasseSid).

% for every skill represented in the group of students, count the number of students
% who have not mastered the skill
skill_to_pair(skill_level(SkillName, BestLevel, _), SkillName-BestLevel).

% enumerate the skills reported in this set of students, and for each skill, 
% count the number of students who have yet to master it
count_non_mastered(SkillName-BestLevels, SkillName-NumNonMastered) :-
	include(skill_not_mastered, BestLevels, NotMastered),
	length(NotMastered, NumNonMastered).

count_non_mastered_skills(Students, NonMasteredSkillCounts) :-
	findall(StudentSkillLevels, (member(Student, Students), student_skill_levels(Student, StudentSkillLevels)), SkillLevels), 
	flatten(SkillLevels, AllSkillLevels),
	msort(AllSkillLevels, SortedSkillLevels),
	maplist(skill_to_pair, SortedSkillLevels, SkillLevelPairs),
	group_pairs_by_key(SkillLevelPairs, GroupedSkillLevelPairs),
	maplist(count_non_mastered, GroupedSkillLevelPairs, NonMasteredSkillCounts).
	
% compare two groups without taking ordering into account
equal_groups(Group1, Group2) :-
	subtract(Group1, Group2, []).
	
select_earliest_skill_to_teach(NonMasteredSkills, Skill1-NumStudents) :-
	member(Skill1-NumStudents, NonMasteredSkills),
	% ensure the skill is "instructible", i.e. we have content for it
	instructible(Skill1, true),
	% succeed if there are no lower skills that could be taught
	findall(Skill2, 
		(member(Skill2-_, NonMasteredSkills),
		not(Skill2 = Skill1),
		depends(Skill1, Skill2)),
		[]).

skill_filter(NumOutliers, _-NumStudents) :-
	NumStudents =< NumOutliers.
	
% order skills-to-teach by cardinality, then skill sid
sort_skills_to_teach(Delta, skill_to_teach(Num1, _), skill_to_teach(Num2, _)) :-
	Num1 =\= Num2,
	compare(Delta, Num1, Num2).
sort_skills_to_teach(Delta, skill_to_teach(Num, Skill1), skill_to_teach(Num, Skill2)) :-
	skill(SkillSid1, Skill1, _, _),
	skill(SkillSid2, Skill2, _, _),
	(	SkillSid1 > SkillSid2
		-> Delta = (<)
		; Delta = (>)
	).
	
select_earliest_largest_skill_to_teach(StudentsPerGroup, NonMasteredSkills, Skill) :-
	% remove skills that have too few unacquireds
	num_outliers(StudentsPerGroup, NumOutliers),
	exclude(skill_filter(NumOutliers), NonMasteredSkills, NonMasteredSkills1),
	findall(
		skill_to_teach(NumStudents, Skill),
		select_earliest_skill_to_teach(NonMasteredSkills1, Skill-NumStudents),
		EarliestSkills),
	predsort(sort_skills_to_teach, EarliestSkills, SortedSkills),
	reverse(SortedSkills, [skill_to_teach(_, Skill) | _]).
		
% determine whether a student has mastered all skills
has_unmastered_skills(Student) :-
	student_skill_levels(Student, SkillLevels),
	member(skill_level(_, BestLevel, _), SkillLevels),
	skill_not_mastered(BestLevel).
	
% identify the earliest unmastered skill for a student
earliest_unmastered_skill(Student, Skill1) :-
	student_skill_levels(Student, SkillLevels),
	member(skill_level(Skill1, BestLevel1, _), SkillLevels),
	skill_not_mastered(BestLevel1),
	% succeed if there are no unmastered skills that depend on this one
	findall(Skill2,
		(member(skill_level(Skill2, BestLevel2, _), SkillLevels),
		not(Skill2 = Skill1),
		skill_not_mastered(BestLevel2),
		depends(Skill1, Skill2)),
		[]).
		
% find a subsequent skill that isn't known to be acquired
next_unacquired_skill(Skill1, SkillCounts, Seen, NextSkill) :-
	nearby_skill(Skill1, Skill2),
	not(member(Skill2, Seen)),
	(	not(member(Skill2-_, SkillCounts))
		-> NextSkill = Skill2
		; next_unacquired_skill(Skill2, SkillCounts, [Skill1 | Seen], NextSkill)
	).
		
compare_skills(Skill1, _, Student1, Student2, Delta) :-
	student_best_skill_level(Skill1, Student1, Level1),
	student_best_skill_level(Skill1, Student2, Level2),
	Level1 =\= Level2,
	compare(Delta, Level1, Level2).
compare_skills(_, Skill2, Student1, Student2, Delta) :-
	student_best_skill_level(Skill2, Student1, Level1),
	student_best_skill_level(Skill2, Student2, Level2),
	compare(Delta, Level1, Level2).

% only succeeds if the students are to receive the same strand (usually the case)
compare_paces(Skill1, _, Student1, Student2, Delta) :-
	compare_pace(Skill1, Student1, Student2, Delta),
	not(Delta = (=)).
compare_paces(_, Skill2, Student1, Student2, Delta) :-
	compare_pace(Skill2, Student1, Student2, Delta).
	
strand_and_pace(Skill, Student, Strand, Pace) :-
	student_grade(Student, Grade),
	student_best_skill_level(Skill, Student, Level),
	strand_to_teach(Skill, Level, Grade, Strand),
	student_instruction_history(Student, InstructionHistory),
	set_pace(Strand, Level, InstructionHistory, Pace).
	
compare_pace(Skill, Student1, Student2, Delta) :-
	strand_and_pace(Skill, Student1, Strand, Pace1),
	strand_and_pace(Skill, Student2, Strand, Pace2),
	pace(PaceSid1, Pace1),
	pace(PaceSid2, Pace2),
	compare(Delta, PaceSid1, PaceSid2).
	
% only succeeds if the students are to receive the same strand (usually the case)
compare_sequences(Skill1, _, Student1, Student2, Delta) :-
	compare_sequence(Skill1, Student1, Student2, Delta),
	not(Delta = (=)).
compare_sequences(_, Skill2, Student1, Student2, Delta) :-
	compare_sequence(Skill2, Student1, Student2, Delta).

compare_sequence(Skill, Student1, Student2, Delta) :-
	strand_and_pace(Skill, Student1, Strand, _),
	strand_and_pace(Skill, Student2, Strand, _),
	student_best_skill_level(Skill, Student1, Level1),
	student_best_skill_level(Skill, Student2, Level2),
	student_instruction_history(Student1, InstructionHistory1),
	student_instruction_history(Student2, InstructionHistory2),
	next_burst_step(Strand, Level1, 0, [Student1], InstructionHistory1, NextStep1),
	next_burst_step(Strand, Level2, 0, [Student2], InstructionHistory2, NextStep2),
	compare(Delta, NextStep1, NextStep2).
	
compare_scores(Skill1, _, Student1, Student2, Delta) :-
	skill_measure(Skill1, Measure),
	compare_score(Measure, Student1, Student2, Delta),
	not(Delta = (=)).
compare_scores(_, Skill2, Student1, Student2, Delta) :-
	skill_measure(Skill2, Measure),
	compare_score(Measure, Student1, Student2, Delta).
	
compare_score(Measure, Student1, Student2, Delta) :-
	student_score(Student1, Measure, Score1),
	student_score(Student2, Measure, Score2),
	compare(Delta, Score1, Score2).
	
% if scores for the measure are not available, invoke special cases
% if we're here, then either Student1 or Student2 (or both) does not have a score for the measure
% 1.  ISF as proxy for PSF.
% if we have a PSF score for one but not the other, rank the student missing the PSF score lower
compare_score(psf, Student1, Student2, >) :-
	student_score(Student1, psf, _),
	not(student_score(Student2, psf, _)).
compare_score(psf, Student1, Student2, <) :-
	not(student_score(Student1, psf, _)),
	student_score(Student2, psf, _).
% if we have no PSF scores at all, then compare ISF scores
compare_score(psf, Student1, Student2, Delta) :-
	not(student_score(Student1, psf, _)),
	not(student_score(Student1, psf, _)),
	compare_score(isf, Student1, Student2, Delta).

% 2.  LNF as a weak proxy for NWF.
% if we have a NWF score for one but not the other, rank the student missing the NWF score _higher_
compare_score(nwf, Student1, Student2, <) :-
	student_score(Student1, psf, _),
	not(student_score(Student2, psf, _)).
compare_score(nwf, Student1, Student2, >) :-
	not(student_score(Student1, psf, _)),
	student_score(Student2, psf, _).
% if we have no NWF scores at all, then compare LNF scores
compare_score(nwf, Student1, Student2, Delta) :-
	not(student_score(Student1, psf, _)),
	not(student_score(Student1, psf, _)),
	compare_score(lnf, Student1, Student2, Delta).
	
% 3.  Look for the latest common skill, and compare that
compare_score(_, Student1, Student2, Delta) :-
	final_skill(FinalSkill),
	depends(FinalSkill, Skill),
	skill_measure(Skill, Measure),
	student_score(Student1, Measure, Score1),
	student_score(Student2, Measure, Score2),
	compare(Delta, Score1, Score2).

outlier(Skill1, Skill2, Student) :-
	low_outlier(Skill1, Skill2, Student) 
	; high_outlier(Skill2, Skill2, Student).

low_outlier(Skill1, Skill2, Student) :-
	zpd_skills([Student], 1, ZPDSkill1, ZPDSkill2), 
	sort([Skill1, Skill2], [S1, S2]),
	sort([ZPDSkill1, ZPDSkill2], [Z1, Z2]),
	!,
	(
		(	Z1 \= S1, depends(S1, Z1) )
	;	(	Z2 \= S2, depends(S2, Z2) )
	),
	print_message(detail, format('low_outlier: ~w', Student)).
	
high_outlier(Skill1, Skill2, Student) :-
	student_best_skill_level(Skill1, Student, 2),
	student_best_skill_level(Skill2, Student, 2),
	student_last_inst_rec(Student, 3),
	print_message(detail, format('high_outlier: ~w', Student)).
	
% FIXME jds 2008-11-07 The mighty Bursts '08 hack: set skill levels for skills
% subsequent to the most advanced measured skill, to 0.
augment_skill_levels(Student, AugmentedStudent) :-
	student_skill_levels(Student, SkillLevels),
	final_skill(FinalSkill),
	depends(FinalSkill, Skill),
	member(skill_level(Skill, _, _), SkillLevels),
	findall(
		skill_level(SuccessorSkill, 0, 0),
		(
			skill(_, SuccessorSkill, _, _),
			not(depends(Skill, SuccessorSkill)),
			not(SuccessorSkill = Skill),
			not(member(skill_level(SuccessorSkill, _, _), SkillLevels))
		),
		SuccessorSkillLevels),
	list_to_set(SuccessorSkillLevels, SuccessorSkillLevelsSet),
	student_sid(Student, StudentSid),
	student_classe_sid(Student, StudentClasseSid),
	student_grade(Student, Grade),
	grade(GradeSid, Grade),
	student_last_inst_rec(Student, InstRec),
	student_skill_levels(Student, SkillLevels),
	student_scores(Student, Scores),
	student_instruction_history(Student, InstructionHistory),
	append(SkillLevels, SuccessorSkillLevelsSet, AugmentedSkillLevels),
	make_student(StudentSid, StudentClasseSid, GradeSid, InstRec, AugmentedSkillLevels, Scores, InstructionHistory, AugmentedStudent),
	!.
	
% for a null student, do not set any skill levels.
augment_skill_levels(Student, Student) :-
	null_student(Student).
		 
% ---------- TESTS ----------

load_request_from_file(Filename, GroupRequest) :-
	open(Filename, read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_group_request(JsonRequest, GroupRequest).
load_request(GroupRequest) :-
	load_request_from_file('test/data/group_input.json', GroupRequest).
	
select_class(Students, ClasseSid, StudentsInClass) :-
	findall(Student, (member(Student, Students), student_classe_sid(Student, ClasseSid)), StudentsInClass).

:- begin_tests(group).
	
test(assign_student, [nondet]) :-
	load_request(group_request(NumGroups, StudentsPerGroup, _, [Student|_])),
	assign_student(NumGroups, StudentsPerGroup, Student, [], [], [Student], []),
	assign_student(NumGroups, StudentsPerGroup, Student, [1, 2, 3, 4, 5], [], [Student], [[1, 2, 3, 4, 5]]).

	
test(form_groups, [nondet]) :-
	load_request(group_request(NumGroups, StudentsPerGroup, _, Students)),
	form_groups(NumGroups, StudentsPerGroup, Students, Groups),
	length(Groups, NumGroups).


% if there are fewer students to group than requested, return a smaller group
test(form_groups_small, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 7398111, Class),
	Class = [Student1,Student2,Student3 | _],
	augment_skill_levels(Student1, AugmentedStudent1),
	augment_skill_levels(Student2, AugmentedStudent2),
	augment_skill_levels(Student3, AugmentedStudent3),
	form_groups(1, 5, [Student1, Student2, Student3], [[AugmentedStudent1, AugmentedStudent3, AugmentedStudent2]]).


test(group1, [nondet]) :-
	load_request(group_request(NumGroups, StudentsPerGroup, _, Students)),
	group(NumGroups, StudentsPerGroup, Students, [Group|_]),!,
	Group = group(724932, [686108101, 65410997, 80597108, 766104116, 7486597], [phonological_awareness, letter_sounds]).
	
test(group2, [nondet]) :-
	open('test/data/group_2008_09_04.json', read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_group_request(JsonRequest, group_request(NumGroups, StudentsPerGroup, 0, Students)),
	group(NumGroups, StudentsPerGroup, Students, Groups),!,
	length(Groups, 6).
	
test(group3, [nondet]) :-
	open('test/data/group_2008_09_05.json', read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_group_request(JsonRequest, group_request(NumGroups, StudentsPerGroup, 0, Students)),
	group(NumGroups, StudentsPerGroup, Students, Groups),!,
	length(Groups, 16).
	
test(assign_group_to_class, []) :-
	make_student(10, 200, 3, 2, [], [], Student1),
	make_student(12, 202, 1, 2, [], [], Student2),
	make_student(15, 210, 2, 1, [], [], Student3),
	make_student(17, 200, 2, 1, [], [], Student4),
	assign_group_to_class([Student1, Student2, Student3, Student4], 200).
	
test(count_non_mastered_skills, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 7398111, Class),
	count_non_mastered_skills(Class, [blending-9, letter_sounds-1, phonological_awareness-0]).
	
% identify skill to teach for an unambiguous class	
test(select_skill_simple, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 7398111, Class),
	count_non_mastered_skills(Class, NonMasteredSkills),
	select_earliest_largest_skill_to_teach(5, NonMasteredSkills, blending).

test(earliest_unmastered_skill, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 7398111, Class),
	member(Student1, Class),
	student_sid(Student1, 896121108),
	earliest_unmastered_skill(Student1, blending),
	member(Student2, Class),
	student_sid(Student2, 838121116),
	earliest_unmastered_skill(Student2, letter_sounds).
	
test(select_skill_by_assertion_order,[true(Skill = regular_words), nondet]) :-
	select_earliest_largest_skill_to_teach(5, [
		advanced_phonics-5, 
		blending-1, 
		comprehension-5, 
		fluency-5, 
		irregular_words-5, 
		letter_sounds-1, 
		regular_words-5, 
		regularish_words-5, 
		vocabulary_oral_language-5], Skill).

% identify earliest skill when there is ambiguity
test(select_skill_ambiguous, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 724932, Class1),
	select_class(Students, 725032, Class2),
	append(Class1, Class2, Classes),
	count_non_mastered_skills(Classes, NonMasteredSkills),
	select_earliest_largest_skill_to_teach(5, NonMasteredSkills, phonological_awareness).

% order students by increasing skill where there are no complex ambiguities
test(sort_students_simple, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 7398111, Class),
	sort_students(blending, letter_sounds, Class, SortedClass),
	maplist(student_sid, SortedClass, SortedSids),
	SortedSids = [838121116, 823121111, 84811097, 838114111, 84497101, 84797104, 896121108, 86797115, 87911197, 90910497,827115117].

% order students who have no PSF scores, but have ISF, by ISF scores	
test(compare_students_no_psf, [true(Delta = (<)), nondet]) :-
	make_student(1000, 100, 2, 1, 
		[],
		[score(isf, 4), score(lnf, 5)],
		Student1),
	make_student(1001, 100, 2, 1, 
		[],
		[score(isf, 5), score(lnf, 5)],
		Student2),
	compare_students(phonological_awareness, letter_sounds, Delta, Student1, Student2),
	!.
	
% order students who have mixed PSF and ISF scores	
test(compare_students_no_psf_mixed, [true(Delta = (<)), nondet]) :-
	make_student(1000, 100, 2, 1, 
		[],
		[score(isf, 6), score(lnf, 5)],
		Student1),
	make_student(1001, 100, 2, 1, 
		[skill_level(phonological_awareness, 0, 0)],
		[score(isf, 5), score(lnf, 5), score(psf, 5)],
		Student2),
	compare_students(phonological_awareness, letter_sounds, Delta, Student1, Student2),
	!.
	
% order students who have no NWF scores, but have LNF, by LNF scores	
test(compare_students_no_nwf, [true(Delta = (<)), nondet]) :-
	make_student(1000, 100, 2, 1, 
		[],
		[score(isf, 4), score(lnf, 5)],
		Student1),
	make_student(1001, 100, 2, 1, 
		[],
		[score(isf, 4), score(lnf, 6)],
		Student2),
	compare_students(phonological_awareness, letter_sounds, Delta, Student1, Student2),
	!.
	
% order students who have mixed NWF and LNF scores	
test(compare_students_no_nwf_mixed, [true(Delta = (>)), nondet]) :-
	make_student(1000, 100, 2, 1, 
		[],
		[score(isf, 6), score(lnf, 10)],
		Student1),
	make_student(1001, 100, 2, 1, 
		[skill_level(letter_sounds, 0, 0)],
		[score(isf, 5), score(lnf, 5), score(nwf, 5)],
		Student2),
	compare_students(phonological_awareness, letter_sounds, Delta, Student1, Student2),
	!.
	
% order students who are equal on skills, but who lack scores (both skills)
test(compare_augmented_student1, [true(Delta = (<)), nondet]) :-
	make_student(154092180, 160286146, 4, @null,
		[skill_level(phonological_awareness, 2, 2),
		 skill_level(letter_sounds, 2, 2), 
		 skill_level(blending, 2, 2)],
		[score(psf, 51), 
		 score(nwf, 65)],
		Student1),
	make_student(154092180, 160286146, 4, @null,
		[skill_level(phonological_awareness, 2, 2),
		 skill_level(letter_sounds, 2, 2), 
		 skill_level(blending, 2, 2), 
		 skill_level(regular_words, 1, 1)],
		[score(psf, 51), 
		 score(nwf, 64), 
		 score(orf, 52)],
		Student2),
	augment_skill_levels(Student1, AugmentedStudent1),
	augment_skill_levels(Student2, AugmentedStudent2),
	compare_students(regular_words, irregular_words, Delta, AugmentedStudent1, AugmentedStudent2),
	!.
test(compare_augmented_student2, [true(Delta = (<)), nondet]) :-
	make_student(154092180, 160286146, 4, @null,
		[skill_level(phonological_awareness, 2, 2),
		 skill_level(letter_sounds, 2, 2), 
		 skill_level(blending, 2, 2)],
		[score(psf, 51), 
		 score(nwf, 65)],
		 Student1),
	make_student(154092180, 160286146, 4, @null,
		[skill_level(phonological_awareness, 2, 2),
		 skill_level(letter_sounds, 2, 2), 
		 skill_level(blending, 2, 2), 
		 skill_level(regular_words, 1, 1)],
		[score(psf, 51), 
		 score(nwf, 64), 
		 score(orf, 52)],
		 Student2),
	augment_skill_levels(Student1, AugmentedStudent1),
	augment_skill_levels(Student2, AugmentedStudent2),
	compare_students(irregular_words, advanced_phonics, Delta, AugmentedStudent2, AugmentedStudent1),
	!.

% identify outliers
test(low_outlier, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 7398111, Class),
	member(Student1, Class),
	student_sid(Student1, 838121116),
	low_outlier(blending, regular_words, Student1).
	
test(high_outlier, []) :-
	make_student(65410997, 724932, 3, 1, 
		[skill_level(phonological_awareness, 1, 1), skill_level(letter_sounds, 0, 0), skill_level(blending, 0, 0)], 
		[score(psf, 4), score(nwf, 0), score(orf, 0)],
		Student),
	not(
		high_outlier(
			phonological_awareness, 
			letter_sounds,
			Student)).
			
test(outlier_no_skills, []) :-
	make_student(155864381, 160296739, 1, 1, [], [score(isf, 20), score(lnf, 1)], Student),
	not(outlier(phonological_awareness, letter_sounds, Student)).


% create a single group off a single class
test(create_group_1_1, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 7398111, Class),
	form_group(1, 5, Class, Group, _),
	maplist(student_sid, Group, StudentSids),!,
	equal_groups(StudentSids, [823121111, 84811097, 84497101, 838114111, 84797104]).

test(create_group_1_2, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 89116111, Class),
	form_group(1, 5, Class, Group, _),
	maplist(student_sid, Group, StudentSids),!,
	equal_groups(StudentSids, [80597108, 825108101, 824101110, 82497115, 807112105]).
	
test(create_group_1_3, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 83116101, Class),
	form_group(1, 5, Class, Group, _),
	maplist(student_sid, Group, StudentSids),!,
	equal_groups(StudentSids, [69511497, 685110111, 69711097, 699104116, 696101107]).
	
test(create_group_1_4, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 78116101, Class),
	form_group(1, 5, Class, Group, _),
	maplist(student_sid, Group, StudentSids),!,
	equal_groups(StudentSids, [71897108, 716111110, 719101112, 726114101, 736108101]).
	
test(multi_class_groups1, []) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 724932, Class1),
	select_class(Students, 725032, Class2),
	append(Class1, Class2, Classes),
	form_groups(2, 5, Classes, [Group2, Group1]),
	maplist(student_sid, Group1, StudentSids1),
	maplist(student_sid, Group2, StudentSids2),!,
	equal_groups(StudentSids1, [65410997, 65611097, 65697117, 65997105, 667110101]),
	equal_groups(StudentSids2, [656119101, 655108101, 657111100, 656121101, 676110111]).
	
test(multi_class_groups2, []) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 844945, Class1),
	select_class(Students, 845045, Class2),
	append(Class1, Class2, Classes),
	form_groups(2, 5, Classes, [Group2, Group1]),
	maplist(student_sid, Group1, StudentSids1),
	maplist(student_sid, Group2, StudentSids2),!,
	equal_groups(StudentSids1, [766104116, 7486597, 7486697, 765115117, 748110111]),
	equal_groups(StudentSids2, [744110104, 746101105, 775110111, 77997116, 7786697]).

% form a group from a class of just one student
test(form_group_one_student, [nondet]) :-
	make_student(154092180, 160286146, 4, @null, 
		[skill_level(phonological_awareness, 1, 1),
		 skill_level(letter_sounds, 2, 2),
		 skill_level(blending, 2, 2),
		 skill_level(regular_words, 2, 2),
		 skill_level(irregular_words, 2, 2),
		 skill_level(fluency, 1, 1)], 
		[score(psf, 51),
		 score(nwf, 65),
		 score(orf, 52)],
		Student),
	Students = [Student],
	form_group(1, 5, Students, Students, []).
	
% form a group with one student where the deficient skill is not instructible
test(form_group_one_student, [nondet]) :-
	make_student(154092180, 160286146, 4, @null, 
		[skill_level(phonological_awareness, 2, 2), 
		 skill_level(letter_sounds, 2, 2), 
		 skill_level(blending, 2, 2), 
		 skill_level(regular_words, 2, 2), 
		 skill_level(irregular_words, 2, 2), 
		 skill_level(fluency, 1, 1)], 
		[score(psf, 51),
		 score(nwf, 65),
		 score(orf, 52)],
		Student),
	Students = [Student],
	form_group(1, 5, Students, [], Students).

% set skill level of subsequent skills for which there's no assessment data to 0
test(augment_skill_levels, [nondet]) :-
	make_student(154092180, 160286146, 4, @null,
		[skill_level(phonological_awareness, 2, 2),
		 skill_level(letter_sounds, 2, 2), 
		 skill_level(blending, 2, 2), 
		 skill_level(regular_words, 1, 1)],
		[score(psf, 51), 
		 score(nwf, 65), 
		 score(orf, 52)],
		Student),
	augment_skill_levels(Student, AugmentedStudent),
	make_student(154092180, 160286146, 4, @null,
		[skill_level(phonological_awareness, 2, 2),
		 skill_level(letter_sounds, 2, 2), 
		 skill_level(blending, 2, 2), 
		 skill_level(regular_words, 1, 1),
		 skill_level(irregular_words, 0, 0),
		 skill_level(regularish_words, 0, 0),
		 skill_level(advanced_phonics, 0, 0),
		 skill_level(fluency, 0, 0),
		 skill_level(comprehension, 0, 0),
		 skill_level(vocabulary_oral_language, 0, 0)],
		[score(psf, 51), 
		 score(nwf, 65), 
		 score(orf, 52)],
		AugmentedStudent).
	
% augmenting skills of a null student does nothing, all skills remain null.
test(augment_skill_levels_none_acquired, [nondet]) :-
	make_student(154092180, 160286146, 4, @null,
		[],
		[],
		Student),
	augment_skill_levels(Student, AugmentedStudent),
	AugmentedStudent = Student.

% tests for generation of zpd skills
test(zpd_skills, [nondet]) :-
	load_request(group_request(_, _, _, Students)),
	select_class(Students, 844945, Class1),
	select_class(Students, 845045, Class2),
	append(Class1, Class2, Classes),
	form_groups(2, 5, Classes, [Group2, Group1]),
	zpd_skills(Group1, 5, phonological_awareness, blending),!,
	zpd_skills(Group2, 5, blending, regular_words).
% special case: students whose skills are all null
test(zpd_skills_all_null, [nondet]) :-
	json_to_student(json([
		sid=123, 
		classeSid=456, 
		gradeSid=3,
		lastSupportRecTypeSid=2,
		skills=[
			json([sid=2, bestLevel= @null, lastLevel= @null]), 
			json([sid=3, bestLevel= @null, lastLevel=0]), 
			json([sid=4, bestLevel= @null, lastLevel= @null])
		], 
		scores=[json([measure=1, score=35]), json([measure=2, score=17])]]), 
	Student),
	zpd_skills([Student, Student], 5, phonological_awareness, letter_sounds).

% special case: student with only one skill specified
test(zpd_skills_one_skill, [nondet]) :-
	make_student(154486260, 154486297, 2, 1, 
		[skill_level(phonological_awareness, 1, 1)], 
		[score(isf, 5), score(lnf, 0), score(psf, 9)],
	Student),
	zpd_skills([Student], 1, phonological_awareness, letter_sounds).
	 
	
test(distant_second_zpd_skill, [nondet]) :-
	Group = [
	student(176734268, 185957856, 1, 3, [skill_level(phonological_awareness, 1, 1), skill_level(letter_sounds, 2, 2), skill_level(blending, 1, 1)], [score(isf, 9), score(lnf, 35), score(psf, 33), score(nwf, 37)], []), 
	student(176734486, 185958002, 1, 3, [skill_level(phonological_awareness, 1, 1), skill_level(letter_sounds, 2, 2), skill_level(blending, 2, 2)], [score(isf, 22), score(lnf, 38), score(psf, 40), score(nwf, 39)], []), 
	student(176733968, 185957918, 1, 3, [skill_level(phonological_awareness, 1, 1), skill_level(letter_sounds, 2, 2), skill_level(blending, 2, 2)], [score(isf, 48), score(lnf, 78), score(psf, 40), score(nwf, 43)], []), 
	student(176733976, 185957856, 1, 3, [skill_level(phonological_awareness, 1, 1), skill_level(letter_sounds, 2, 2), skill_level(blending, 2, 2)], [score(isf, 36), score(lnf, 57), score(psf, 30), score(nwf, 50)], []), 
	student(176734310, 185957856, 1, 1, [skill_level(phonological_awareness, 1, 1), skill_level(letter_sounds, 2, 2), skill_level(blending, 2, 2)], [score(isf, 32), score(lnf, 54), score(psf, 42), score(nwf, 53)], [])],
	zpd_skills(Group, 5, phonological_awareness, regular_words).
	
% conversion of students with instructional history to prolog objects
test(load_students_with_history, [true(StudentSid = 823121111), true(Date1 = '2007-11-19 02:34:28'),nondet]) :-
	load_request_from_file('test/data/group_input_history.json', group_request(_, _, _, Students)),
	select_class(Students, 7398111, [Student1 | _]),
	student_sid(Student1, StudentSid),
	student_instruction_history(Student1, [Instruction1 | _]),
	instruction_date(Instruction1, Date1).

:- end_tests(group).




