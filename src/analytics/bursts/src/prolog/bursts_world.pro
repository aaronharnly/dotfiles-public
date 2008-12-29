/** <module> Bursts World Knowledge

Global knowledge for the various experts that compose the burst expert system
@version $Id: bursts_world.pro,v 1.22 2008/11/08 20:10:51 jds Exp $
*/

/**
	skill(?SkillSid:int, ?Name:atom, ?Abbrev:string, ?Desc:string) is det
	
	Name and description of a skill
	
	@param SkillSid the database ID of the skill
	@param Name the internal name of the skill
	@param Abbrev the abbreviated name of the skill
	@param Desc The full, printable name and possibly description of the skill
*/
skill(1, phonological_awareness, "PhoA", "Phonological Awareness").
skill(2, letter_sounds, "LS", "Letter-Sound Correspondences").
skill(3, blending, "Bl", "Blending").
skill(4, regular_words, "RW", "Regular Words").
skill(5, irregular_words, "IW", "Irregular Words").
skill(6, regularish_words, "RiW", "Regular-ish Words").
skill(7, advanced_phonics, "AP", "Advanced Phonics").
skill(8, fluency, "Flu", "Oral Reading Fluency").
skill(9, comprehension, "Comp", "Reading Comprehension").
skill(10, vocabulary_oral_language, "VOL", "Vocabulary and Oral Language").

/**
	measure(?MeasureSid:int, ?Name:atom, ?Abbrev:string, ?Desc:string) is det
	
	Name and description of a DIBELS measure
	
	@param MeasureSid the database ID of the measure
	@param Name the internal name of the DIBELS measure
	@param Abbrev the abbreviated name of the measure
	@param Desc The full, printable name and possibly description of the measure
*/
measure(1, isf, "ISF", "Initial Sound Fluency").
measure(2, lnf, "LNF", "Letter Naming Fluency").
measure(3, psf, "PSF", "Phoneme Segmentation Fluency").
measure(4, nwf, "NWF", "Nonsense Word Fluency").
measure(5, orf, "ORF", "Oral Reading Fluency").
measure(6, rtf, "RTF", "Retelling Fluency").
measure(7, wuf, "WUF", "Word Use Fluency").

/**
	skill_measure(?Skill:atom, ?Measure:string) is det
	
	Lists the DIBELS measure corresponding to each reading skill
	
	@param Skill the internal name of the skill
	@param Measure the internal name of the measure
*/
skill_measure(phonological_awareness, psf).
skill_measure(letter_sounds, nwf).
skill_measure(blending, nwf).
skill_measure(regular_words, orf).
skill_measure(irregular_words, orf).
skill_measure(fluency, orf).
% a default when there is no explicit mapping.  Bounce everything to ORF for now.
% FIXME jds remove this when all skills are mapped to measures.
skill_measure(_, orf).

/**
	instructible(?Skill:atom, ?Instructible:bool) is multi.
	
	Specifies whether a given skill is currently addressed by the bursts system.
	When used as a generator, by passing in a value for Instructible, it at least one skill will be returned.
	
	@param Skill an atom denoting the name of a skill
	@param Instructible <code>true</code> if the skill is covered, <code>false</code> otherwise.
*/

instructible(phonological_awareness, true).
instructible(letter_sounds, true).
instructible(blending, true).
instructible(regular_words, true).
instructible(irregular_words, true).
instructible(regularish_words, true).
instructible(advanced_phonics, false).
instructible(fluency, false).
instructible(comprehension, false).
instructible(vocabulary_oral_language, false).

/**
	depends_immediately(?Skill:atom, ?PriorSkill:atom) is nondet
	
	Succeeds if, in the skill graph, there is an edge from Skill to PriorSkill.
	
	@param Skill any skill
	@param PriorSkill an immediately preceding skill in the graph
*/
depends_immediately(blending, phonological_awareness).
depends_immediately(blending, letter_sounds).
depends_immediately(regular_words, blending).
depends_immediately(irregular_words, blending).
depends_immediately(regularish_words, blending).
depends_immediately(advanced_phonics, blending).
depends_immediately(fluency, regular_words).
depends_immediately(fluency, irregular_words).
depends_immediately(fluency, regularish_words).
depends_immediately(fluency, advanced_phonics).
depends_immediately(comprehension, fluency).
depends_immediately(comprehension, vocabulary_oral_language).

/** depends(?Skill:atom, ?PriorSkill:atom) is nondet

	Succeeds if the development of Skill depends on PriorSkill, however remotely.
	
	@param Skill any skill
	@param PriorSkill a skill that is required for the acquisition of the later skill
*/
depends(Skill, PriorSkill) :-
	depends_immediately(Skill, PriorSkill).
depends(Skill, PriorSkill) :-
	depends_immediately(Skill, ImmediatelyPriorSkill),
	depends(ImmediatelyPriorSkill, PriorSkill).
	
/** base_skill (?Skill:atom) is nondet

	Unifies Skill with a skill that has no dependencies.  Resatisfiable.
	
	@param Skill a skill having no priors
*/
base_skill(Skill) :-
	skill(_, Skill, _, _),
	not(depends_immediately(Skill, _)).
	
/** final_skill (?Skill:atom) is nondet

	Unifies Skill with a skill that has no successors.  Resatisfiable.
	
	@param Skill a skill having no successors
*/
final_skill(Skill) :-
	skill(_, Skill, _, _),
	not(depends_immediately(_, Skill)).
	
/** sister_skills (?Skill1:atom, ?Skill2:atom) is nondet

	Unifies Skill with two skills that are immediate dependents of a subsequent skill 
	in the dependency graph.  
	Resatisfiable.
	
	@param Skill1 is a skill
	@param Skill2 is a skill
*/
sister_skills(Skill1, Skill2) :-
	depends_immediately(LaterSkill, Skill1),
	depends_immediately(LaterSkill, Skill2),
	Skill1 \= Skill2.
	
/** nearby_skills(?Skill1:atom, ?Skill2:atom) is nondet

	Succeeds if Skill2 is either a sister of or is immediately dependent on Skill1, in that order. 
	Resatisfiable.
	
	@param Skill1 is a skill
	@param Skill2 is a skill
*/
nearby_skill(Skill1, Skill2) :-
	sister_skills(Skill1, Skill2).
nearby_skill(Skill1, Skill2) :-
	depends_immediately(Skill2, Skill1).
	
/** num_outliers(+GroupSize, -NumOutliers) is det

	Specifies the number of possible outliers for a given group size
	
	@param GroupSize the number of students in the group to be created
	@param NumOutliers the number of outliers for this group size
*/
num_outliers(GroupSize, 0) :-
	GroupSize < 4.
num_outliers(GroupSize, 1) :-
	GroupSize > 3,
	GroupSize < 6.
num_outliers(GroupSize, 2) :-
	GroupSize > 5.
	
/** skill_mastered(SkillLevel:int) is det

	True if the skill level indicates mastery of the skill.
	
	@param SkillLevel a skill level in the range [0, 2] or a skill/4 predicate
*/
skill_mastered(2).
skill_mastered(skill_level(_, 2, _)).

skill_not_mastered(SkillLevel) :-
	not(skill_mastered(SkillLevel)).
	
/**
	strand(?StrandSid:int, ?Name:atom, ?Abbrev:string, ?Desc:string) is det
	
	Name and description of a strand
	
	@param StrandSid the database ID of the skill
	@param Name the internal name of the strand
	@param Abbrev the abbreviated name of the strand
	@param Desc The full, printable name and possibly description of the strand
*/
strand(1, phonological_awareness, 'PhoA', 'Phonological Awareness').
strand(2, phonemic_awareness, 'PheA', 'Phonemic Awareness').
strand(3, letter_sounds, 'LS', 'Letter Sounds').
strand(4, sounding_out, 'SO', 'Sounding Out').
strand(6, connected_text, 'CT', 'Connected Text').
strand(7, irregular_words, 'IW', 'Irregular Words').
strand(8, letter_combinations, 'LCb', 'Letter Combinations').
strand(9, advanced_phonics, 'AP', 'Advanced Phonics').
strand(10, fluency, 'Flu', 'Fluency').

/**
	strand_to_teach(?Skill:atom, ?Level:int, ?Grade:atom, ?Strand:atom) is det
	
	Mapping of skills levels to strands
	
	@param Skill the name of the skill
	@param Level the skill level
	@param Grade is the grade of the student
	@param Strand the name of the strand to teach
*/
strand_to_teach(phonological_awareness, 0, k, phonological_awareness).
strand_to_teach(phonological_awareness, _, _, phonemic_awareness).
strand_to_teach(letter_sounds, _, _, letter_sounds).
strand_to_teach(blending, _, _, sounding_out).
strand_to_teach(regular_words, _, _, connected_text).
strand_to_teach(irregular_words, _, _, irregular_words).
strand_to_teach(regularish_words, _, _, letter_combinations).
strand_to_teach(advanced_phonics, _, _, advanced_phonics).

/**
	pace(?PaceSid:int, ?Name:atom)
	
	Name of a pace level
	
	@param PaceSid is the Sid of the pace
	@param Name is the name of the pace
*/
pace(1, cool).
pace(2, warm).
pace(3, hot).

/** 
	grade(?GradeSid:int, ?Name:atom)
	
	The name of a grade
	
	@param GradeSid is the Sid of the grade
	@param Name is the name of the grade
*/
grade(1, preK).
grade(2, k).
grade(3, 1).
grade(4, 2).
grade(5, 3).
grade(6, 4).
grade(7, 5).
grade(8, 6).

/**
	dibels_bm(?Grade:atom, ?Period:atom, ?Measure:atom, ?BMLevel:atom, ?Score:int)
	
	DIBELS benchmark threshold levels
	
	@param Grade is an atom in the set {k, 1, 2, 3 ... }
	@param Period is an atom in the set {boy, moy, eoy}
	@param Measure as above
	@param BMLevel is an atom in the set {blue, green, yellow, red}
	@param Score is the cutpoint for the level
*/
dibels_bm(k, boy, isf, green, 8).
dibels_bm(1, eoy, orf, green, 40).
dibels_bm(1, eoy, orf, yellow, 20).
dibels_bm(2, eoy, orf, green, 90).
dibels_bm(2, eoy, orf, yellow, 70).
dibels_bm(3, eoy, orf, green, 110).
dibels_bm(3, eoy, orf, yellow, 80).
dibels_bm(4, eoy, orf, green, 118).
dibels_bm(4, eoy, orf, yellow, 96).
dibels_bm(5, eoy, orf, green, 124).
dibels_bm(5, eoy, orf, yellow,103).
dibels_bm(6, eoy, orf, green, 125).
dibels_bm(6, eoy, orf, yellow,104).

%% Unit tests
:- begin_tests(bursts_world).

% a quick smoke-test to make sure we have the skills
test(skill) :-
	findall(Skill, skill(_, Skill, _, _), Skills),
    Skills = [
		phonological_awareness,
		letter_sounds,
		blending,
		regular_words,
		irregular_words,
		regularish_words,
		advanced_phonics,
		fluency,
		comprehension,
		vocabulary_oral_language
		].
		
% ensure the sanity of the skills dependency graph
test(depends_immediately, [nondet]) :-
	depends_immediately(blending, phonological_awareness),
	depends_immediately(fluency, regular_words),
	not(depends_immediately(advanced_phonics, fluency)).
	
% test indirect dependencies in the skills graph
test(depends, [nondet]) :-
	depends(fluency, letter_sounds),
	depends(comprehension, vocabulary_oral_language),
	not(depends(regular_words, comprehension)).
	
% test sister skills
test(sister, [nondet]) :-
	sister_skills(phonological_awareness, letter_sounds),
	sister_skills(irregular_words, regularish_words),
	not(sister_skills(blending, blending)).
	
% test near-by skills
test(nearby_skill, [nondet]) :-
	nearby_skill(phonological_awareness, letter_sounds),
	nearby_skill(phonological_awareness, blending),
	nearby_skill(irregular_words, regular_words),
	nearby_skill(irregular_words, fluency),
	not(nearby_skill(irregular_words, comprehension)),
	not(nearby_skill(blending, letter_sounds)).
	
% identify base skills (skills with no priors)
test(base_skills) :-
	findall(Skill, base_skill(Skill), Skills),
	Skills = [phonological_awareness, letter_sounds, vocabulary_oral_language].
	
% identify final skills (skills with no dependents)
test(final_skills) :-
	findall(Skill, final_skill(Skill), Skills),
	Skills = [comprehension].

:- end_tests(bursts_world).