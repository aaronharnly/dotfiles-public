 /** <module> The Bursts Feature Extraction Algorithm

Predicates to interpret assessment results in terms of reading skill levels, ultimately for input to the grouping algorithm.
@version $Id: feature.pro,v 1.23 2008/12/26 05:50:19 aharnly Exp $
*/

/**
	feature_detect(+Results:list, -SkillLevels:list) is det
	
	Interprets assessment result data, scores and ILA results, to establish levels of skills
	associated with each assessment measure.
	
	@param Results a list of result/3 objects
	@param Results a list of skill_level/2 objects, with structure: skill_level(Skill:atom, Level:int)
*/
feature_detect(Results, SkillLevels) :-
	maplist(process_result, Results, SkillLevels).

% ---------- IMPLEMENTATION ----------
	
% wrapper to catch processing failures and return with an error on faults
process_result(Result, skill_levels(ResultProbeSid, 0, SkillLevels)) :-
	result_to_skill_levels(Result, SkillLevels), 
	result_probe_sid(Result, ResultProbeSid),
	!.
process_result(Result, skill_levels(1, [])) :-
	print_message(warning, goal_failed(process_result, Result)).
	
% ISF can provide a (partial) PhoA value
result_to_skill_levels(Result, [skill_level(phonological_awareness, PhoALevel)]) :-
	result_measure(Result, isf),
	result_to_skill_level(Result, phonological_awareness, PhoALevel).
% currently LNF always yields LS.0	
result_to_skill_levels(Result, [skill_level(letter_sounds, 0)]) :-
	result_measure(Result, lnf).
% PSF yields PhoA
result_to_skill_levels(Result, [skill_level(phonological_awareness, PhoALevel)]) :-
	result_measure(Result, psf),
	result_to_skill_level(Result, phonological_awareness, PhoALevel).
% NWF yields LS and Bl
result_to_skill_levels(Result, SkillLevels) :-
	result_measure(Result, nwf),
	result_to_skill_level(Result, letter_sounds, LSLevel),
	result_to_skill_level(Result, blending, BlLevel),
	SkillLevels = [
		skill_level(letter_sounds, LSLevel), 
		skill_level(blending, BlLevel)
	].
% ORF yields RW, IW, RiW, AP and Flu
result_to_skill_levels(Result, SkillLevels) :-
	result_measure(Result, orf),
	result_to_skill_level(Result, regular_words, RWLevel),
	result_to_skill_level(Result, irregular_words, IWLevel),
	result_to_skill_level(Result, regularish_words, RiWLevel),
	result_to_skill_level(Result, advanced_phonics, APLevel),
	result_to_skill_level(Result, fluency, FluLevel),
	SkillLevels = [
		skill_level(regular_words, RWLevel),
		skill_level(irregular_words, IWLevel),
		skill_level(regularish_words, RiWLevel),
		skill_level(advanced_phonics, APLevel),
		skill_level(fluency, FluLevel)
	].
	
% ---------- SKILL LEVEL RULES ----------
	
% phonological awareness
% guard against division by zero: zero attempts mean a level of zero
result_to_skill_level(Result, phonological_awareness, 2) :-
	result_score(Result, Score),
	Score > 15,
	result_ila_value(Result, 'PsfNumAttemptedInitialSounds', NumAttemptedInitialSounds),
	result_ila_value(Result, 'PsfNumAttemptedMiddleSounds', NumAttemptedMiddleSounds),
	result_ila_value(Result, 'PsfNumAttemptedFinalSounds', NumAttemptedFinalSounds),
	result_ila_value(Result, 'PsfNumSegmentedInitialSounds', NumSegmentedInitialSounds),
	result_ila_value(Result, 'PsfNumSegmentedMiddleSounds', NumSegmentedMiddleSounds),
	result_ila_value(Result, 'PsfNumSegmentedFinalSounds', NumSegmentedFinalSounds),
	NumAttemptedSounds is NumAttemptedInitialSounds + NumAttemptedMiddleSounds + NumAttemptedFinalSounds,
	NumAttemptedSounds > 0, 
	NumSegmentedSounds is NumSegmentedInitialSounds + NumSegmentedMiddleSounds + NumSegmentedFinalSounds, 
	NumSegmentedSounds / NumAttemptedSounds > 0.65.
result_to_skill_level(Result, phonological_awareness, 1) :-
	result_ila_value(Result, 'PsfNumSegmentedInitialSounds', NumSegmentedInitialSounds),
	NumSegmentedInitialSounds > 2.
% ISF green also yields PhoA.1
result_to_skill_level(Result, phonological_awareness, 1) :-
	result_score(Result, Score),
	Score > 7.	
result_to_skill_level(_, phonological_awareness, 0).

% letter sounds
% guard against division by zero: zero attempts mean a level of zero
result_to_skill_level(Result, letter_sounds, 0) :-
	result_ila_value(Result, 'NwfNumLettersAssessed', 0).
result_to_skill_level(Result, letter_sounds, 2) :-
	result_ila_value(Result, 'NwfNumLettersAssessed', NumLettersAssessed),
	result_ila_value(Result, 'NwfNumLettersCorrect', NumLettersCorrect),
	NumLettersAssessed > 0,
	NumLettersCorrect / NumLettersAssessed > 0.9.
result_to_skill_level(Result, letter_sounds, 1) :-
	result_ila_value(Result, 'NwfNumLettersAssessed', NumLettersAssessed),
	result_ila_value(Result, 'NwfNumLettersCorrect', NumLettersCorrect),
	NumLettersAssessed > 0,
	NumLettersCorrect / NumLettersAssessed > 0.5.
result_to_skill_level(_, letter_sounds, 0).

% blending
result_to_skill_level(Result, blending, 2) :-
	result_to_skill_level(Result, letter_sounds, LSLevel),
	LSLevel > 0,
	result_ila_value(Result, 'NwfNumFullySoundedAndNoSBSCorrectWords', NumWordsCleanlyBlendedWithoutSoundingOut),
	NumWordsCleanlyBlendedWithoutSoundingOut >= 5.
result_to_skill_level(Result, blending, 1) :-
	result_to_skill_level(Result, letter_sounds, LSLevel),
	LSLevel > 0,
	result_ila_value(Result, 'NwfNumFullySoundedCorrectWords', NumWordsCleanlyBlendedOrSoundedOutAndCleanlyBlended),
	NumWordsCleanlyBlendedOrSoundedOutAndCleanlyBlended >= 5.
result_to_skill_level(_, blending, 0).

% regular words
result_to_skill_level(Result, regular_words, 0) :-
	result_ila_value(Result, 'OrfNumRegularWordsAssessed', 0).
result_to_skill_level(Result, regular_words, 2) :-
	result_ila_value(Result, 'OrfNumRegularWordsAssessed', NumRegularWordsAssessed),
	result_ila_value(Result, 'OrfNumRegularWordsMissed', NumRegularWordsMissed),
	NumRegularWordsAssessed > 6,
	NumRegularWordsMissed / NumRegularWordsAssessed < 0.1.
result_to_skill_level(Result, regular_words, 1) :-
	result_ila_value(Result, 'OrfNumRegularWordsAssessed', NumRegularWordsAssessed),
	result_ila_value(Result, 'OrfNumRegularWordsMissed', NumRegularWordsMissed),
	NumRegularWordsAssessed > 3,
	NumRegularWordsMissed / NumRegularWordsAssessed < 0.5.
result_to_skill_level(_, regular_words, 0).

% irregular words
result_to_skill_level(Result, irregular_words, 2) :-
	result_ila_value(Result, 'OrfNumIrregularWordsAssessed', NumIrregularWordsAssessed),
	result_ila_value(Result, 'OrfNumIrregularWordsMissed', NumIrregularWordsMissed),
	NumIrregularWordsAssessed > 6,
	NumIrregularWordsMissed / NumIrregularWordsAssessed < 0.1.
result_to_skill_level(Result, irregular_words, 1) :-
	result_ila_value(Result, 'OrfNumIrregularWordsAssessed', NumIrregularWordsAssessed),
	result_ila_value(Result, 'OrfNumIrregularWordsMissed', NumIrregularWordsMissed),
	NumIrregularWordsAssessed > 3,
	NumIrregularWordsMissed / NumIrregularWordsAssessed < 0.5.
result_to_skill_level(_, irregular_words, 0).

% regular-ish words
result_to_skill_level(_, regularish_words, @null).

% advanced phonics
result_to_skill_level(_, advanced_phonics, @null).

% fluency
result_to_skill_level(Result, fluency, 2) :-
	result_to_skill_level(Result, regular_words, 2),
	result_to_skill_level(Result, irregular_words, 2),
	result_grade(Result, Grade),
	result_score(Result, Score),
	dibels_bm(Grade, eoy, orf, green, GreenScore),
	Score >= GreenScore.
result_to_skill_level(Result, fluency, 1) :-
	result_to_skill_level(Result, regular_words, 2),
	result_to_skill_level(Result, irregular_words, 2),
	result_grade(Result, Grade),
	result_score(Result, Score),
	dibels_bm(Grade, eoy, orf, yellow, YellowScore),
	Score >= YellowScore.
result_to_skill_level(_, fluency, 0).


% ---------- TESTS ----------

load_results(Results) :-
	open('test/data/feature_input.json', read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_feature_request(JsonRequest, feature_request(Results)).
	
select_result(Results, Measure, Result) :-
	member(Result, Results),
	result_measure(Result, Measure).

:- begin_tests(feature).

test(feature_isf, [true(PhoALevel = 0), nondet]) :-
	load_results(Results),
	select_result(Results, isf, Result),
	result_to_skill_levels(Result, [
		skill_level(phonological_awareness, PhoALevel)
	]).
	
test(feature_isf_green, [true(PhoALevel = 1), nondet]) :-
	make_result(1002, 3, 9, 3, [], Result),!,
	result_to_skill_levels(Result, [
		skill_level(phonological_awareness, PhoALevel)
	]).
	
test(feature_lnf, [true(LSLevel = 0), nondet]) :-
	load_results(Results),
	select_result(Results, lnf, Result),
	result_to_skill_levels(Result, [
		skill_level(letter_sounds, LSLevel)
	]).
	
test(feature_psf, [true(PhoALevel = 2), nondet]) :-
	load_results(Results),
	select_result(Results, psf, Result),
	result_to_skill_levels(Result, [
		skill_level(phonological_awareness, PhoALevel)
	]).
	
test(feature_nwf, [true(LSLevel-BlLevel = 2-0), nondet]) :-
	load_results(Results),
	select_result(Results, nwf, Result),
	result_to_skill_levels(Result, [
		skill_level(letter_sounds, LSLevel),
		skill_level(blending, BlLevel)
	]).
	
test(feature_orf, [true([RW, IW, LC, AP, F] = [1, 2, @null, @null, 0]), nondet]) :-
	load_results(Results),
	select_result(Results, orf, Result),
	result_to_skill_levels(Result, [
		skill_level(regular_words, RW),
		skill_level(irregular_words, IW),
		skill_level(regularish_words, LC),
		skill_level(advanced_phonics, AP),
		skill_level(fluency, F)
	]).
	
test(feature_orf_fluency, [nondet]) :-
	open('test/data/feature_fluency_2008_08_28.json', read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_feature_request(JsonRequest, feature_request(Results)), 
	member(Result, Results), 
	result_score(Result, 20), 
	feature_detect([Result], [skill_levels(_, 0, SkillLevels)]),
	member(skill_level(fluency, 1), SkillLevels).

:- end_tests(feature).
