/** <module> Data structures for the Bursts system

Prolog predicates that represent the logical model of the bursts algorithm domain.
@version $Id: model.pro,v 1.19 2008/12/05 04:46:14 jds Exp $
*/

% student
make_student(Sid, ClasseSid, GradeSid, LastInstRec, Skills, Scores, InstructionHistory, Student) :-
	grade(GradeSid, Grade),
	Student = student(Sid, ClasseSid, Grade, LastInstRec, Skills, Scores, InstructionHistory).
% no instruction history
make_student(Sid, ClasseSid, GradeSid, LastInstRec, Skills, Scores, Student) :-
	make_student(Sid, ClasseSid, GradeSid, LastInstRec, Skills, Scores, [], Student).
	
student_sid(student(Sid, _, _, _, _, _, _), Sid).
student_classe_sid(student(_, ClasseSid, _, _, _, _, _), ClasseSid).
student_grade(student(_, _, Grade, _, _, _, _), Grade).
student_last_inst_rec(student(_, _, _, LastInstRec, _, _, _), LastInstRec).
student_skill_levels(student(_, _, _, _, SkillLevels, _, _), SkillLevels).
student_scores(student(_, _, _, _, _, Scores, _), Scores).
student_instruction_history(student(_, _, _, _, _, _, InstructionHistory), InstructionHistory).

student_best_skill_level(Skill, Student, SkillLevel) :-
	student_skill_levels(Student, SkillLevels),
	member(skill_level(Skill, SkillLevel, _), SkillLevels), !.
% if the student is not rated for a skill, assume it is mastered IFF 
% the student has acquired a later skill
student_best_skill_level(Skill, Student, 2) :-
	student_skill_levels(Student, SkillLevels),
	not(member(skill_level(Skill, _, _), SkillLevels)),
	member(skill_level(Skill1, 2, _), SkillLevels),
	Skill1 \= Skill,
	depends(Skill1, Skill), !.
% otherwise, figure that the student has not acquired the skill
student_best_skill_level(_, _, 0).
	 
null_student(Student) :-
	student_skill_levels(Student, SkillLevels),
	exclude(null_skill_level, SkillLevels, []).
	
student_score(Student, Measure, Score) :-
	student_scores(Student, Scores),
	member(score(Measure, Score), Scores).

% skill_level
make_skill_level(Sid, BestLevel, LastLevel, SkillLevel) :-
	skill(Sid, Name, _, _),
	SkillLevel = skill_level(Name, BestLevel, LastLevel).
skill_level_name(skill_level(Name, _, _), Name).
skill_level_best(skill_level(_, BestLevel, _), BestLevel).
skill_level_last(skill_level(_, _, LastLevel), LastLevel).

% score
make_score(Sid, ScoreAttained, Score) :-
	measure(Sid, Measure, _, _),
	Score = score(Measure, ScoreAttained).
score_measure(score(Measure, _), Measure).
score_score(score(_, Score), Score).

% result
make_result(ResultProbeSid, MeasureSid, Score, GradeSid, ILADescriptives, Result) :-
	measure(MeasureSid, Measure, _, _),
	grade(GradeSid, Grade),
	Result = result(ResultProbeSid, Measure, Score, Grade, ILADescriptives).
result_probe_sid(result(ResultProbeSid, _, _, _, _), ResultProbeSid).
result_measure(result(_, Measure, _, _, _), Measure).
result_score(result(_, _, Score, _, _), Score).
result_grade(result(_, _, _, Grade, _), Grade).
result_ila(result(_, _, _, _, ILADescriptives), ILADescriptives).
result_ila_value(Result, Key, Value) :-
	result_ila(Result, ILADescriptives),
	get_assoc(Key, ILADescriptives, Value).

% content
make_content(Strand, Pace, Sequence, Content) :-
	Content = content(Strand, Pace, Sequence).
content_strand(content(Strand, _, _), Strand).
content_pace(content(_, Pace, _), Pace).
content_sequence(content(_, _, Sequence), Sequence).
	
% instruction
measure_name(Sid, Name) :-
	measure(Sid, Name, _, _).
skill_name(Sid, Name) :-
	skill(Sid, Name, _, _).
	
measure_sid(Name, Sid) :-
	measure(Sid, Name, _, _).
skill_sid(Name, Sid) :-
	skill(Sid, Name, _, _).
	
make_instruction(Date, SkillSids, MeasureSids, Content, Instruction) :-
	maplist(measure_name, MeasureSids, Measures),
	maplist(skill_name, SkillSids, Skills),
	Instruction = instruction(Date, Skills, Measures, Content).
	
instruction_date(instruction(Date, _, _, _), Date).
instruction_skills(instruction(_, Skills, _, _), Skills).
instruction_skill(instruction(_, Skills, _, _), NumSkill, Skill) :-
	nth1(NumSkill, Skills, Skill).
instruction_measures(instruction(_, _, Measures, _), Measures).
instruction_measure(instruction(_, _, Measures, _), NumMeasure, Measure) :-
	nth1(NumMeasure, Measures, Measure).
instruction_content(instruction(_, _, _, Content), Content).
instruction_content(instruction(_, _, _, Content), NumElement, ContentElement) :-
	nth1(NumElement, Content, ContentElement).
	
% burst
make_burst(Skills, Measures, Content, LowOutliers, HighOutliers, Trace, Burst) :-
	Burst = burst(Skills, Measures, Content, LowOutliers, HighOutliers, Trace).
burst_skills(burst(Skills, _, _, _, _, _), Skills).
burst_measures(burst(_, Measures, _, _, _, _), Measures).
burst_content(burst(_, _, Content, _, _, _), Content).
burst_low_outliers(burst(_, _, _, LowOutliers, _, _), LowOutliers).
burst_high_outliers(burst(_, _, _, _, HighOutliers, _), HighOutliers).
burst_trace(burst(_, _, _, _, _, Trace), Trace).

% content slot
make_content_slot(StrandId, Sequence, PaceId, ContentSlot) :-
	strand(StrandId, Strand, _, _),
	pace(PaceId, Pace),
	ContentSlot = content_slot(Strand, Sequence, Pace).
content_slot_strand(content_slot(Strand, _, _), Strand).
content_slot_sequence(content_slot(_, Sequence, _), Sequence).
content_slot_pace(content_slot(_, _, Pace), Pace).

% load content
load_content(ContentPush) :-
	retractall(content_slot(_, _, _)),
	maplist(assert, ContentPush).


