/** <module> Bursts Web Service

An HTTP/JSON front-end for the various burst algorithms
@version $Id: bursts_server.pro,v 1.41 2008/12/10 16:09:03 aharnly Exp $

*/

:- use_module(library('http/thread_httpd')).
:- use_module(library('http/http_dispatch')).
:- use_module(library('http/json')).
:- use_module(library('http/http_client')).
:- use_module(library('http/http_json')).
:- use_module(library('http/html_write')).
:- use_module(library('http/http_parameters')).

server(Port) :-
		initialize,
        http_server(http_dispatch, [port(Port)]).
		
initialize :-
	open('test/data/content_input.json', read, InStream),
	json_read(InStream, JsonContentPush),
	json_to_content_push(JsonContentPush, ContentPush),
	load_content(ContentPush).

% the real handlers
:- http_handler('/group', group_handler_wrapper, []).
:- http_handler('/feature', feature_handler_wrapper, []).
:- http_handler('/burst', burst_handler_wrapper, []).
:- http_handler('/contentPush', content_handler_wrapper, []).

% interactive handlers
:- http_handler('/interactive', interactive_handler, []).
:- http_handler('/css/interactive.css', http_reply_file('src/css/interactive.css',[]), []).
:- http_handler('/dummy', dummy_handler, []).

% the test handlers
:- http_handler('/group_test', test_group_handler, []).
:- http_handler('/feature_test', test_feature_handler, []).
:- http_handler('/burst_test', test_burst_handler, []).
:- http_handler('/content_test', test_content_handler, []).
% tests the sending of a static json file
:- http_handler('/group_static', http_reply_file('test/data/group_output.json', [mime_type('application/json')]), []).

% ---------- HTTP SERVER HANDLERS ----------

handler_wrapper(Request, Handler) :-
	member(host(Host), Request),
	member(path(Path), Request),
	current_date_time(Date, Time),
	print_message(informational, format('~w ~w ~w ~w', [Date, Time, Host, Path])),
	http_read_json(Request, JsonRequest),
	print_message(detail, JsonRequest),
	catch(
		call(Handler, JsonRequest), 
		Error,
		print_message(error, Error)).

group_handler_wrapper(Request) :-
	handler_wrapper(Request, group_handler).
feature_handler_wrapper(Request) :-
	handler_wrapper(Request, feature_handler).
burst_handler_wrapper(Request) :-
	handler_wrapper(Request, burst_handler).
content_handler_wrapper(Request) :-
	handler_wrapper(Request, content_handler).

group_handler(JsonRequest) :-
	json_to_group_request(JsonRequest, group_request(NumGroups, StudentsPerGroup, _, Students)),
	group(NumGroups, StudentsPerGroup, Students, Groups),
	groups_to_json(Groups, JsonResponse),
	reply_json(JsonResponse).
	
feature_handler(JsonRequest) :-
	json_to_feature_request(JsonRequest, feature_request(Results)),
	feature_detect(Results, SkillLevels),
	skill_levels_to_json(SkillLevels, JsonResponse),
	reply_json(JsonResponse).
	
burst_handler(JsonRequest) :-
	json_to_burst_request(JsonRequest, burst_request(Students, InstructionHistory, NumDays)),
	generate_burst(Students, InstructionHistory, NumDays, Burst),
	burst_to_json(Burst, JsonResponse),
	reply_json(JsonResponse).
	
content_handler(JsonRequest) :-
	json_to_content_push(JsonRequest, ContentPush),
	load_content(ContentPush),
	JsonResponse = json([wasError=0]),
	reply_json(JsonResponse).
content_handler(_) :-
	JsonResponse = json([wasError=1]),
	reply_json(JsonResponse).

% Test handlers
test_group_handler(Request) :-
	http_read_json(Request, _),
	open('test/data/group_output.json', read, InStream),
	json_read(InStream, Output),
	close(InStream),
	reply_json(Output).
	
test_feature_handler(Request) :-
	http_read_json(Request, _),
	open('test/data/feature_output.json', read, InStream),
	json_read(InStream, Output),
	close(InStream),
	reply_json(Output).
	
test_burst_handler(Request) :-
	http_read_json(Request, _),
	open('test/data/burst_output.json', read, InStream),
	json_read(InStream, Output),
	close(InStream),
	reply_json(Output).
	
test_content_handler(Request) :-
	http_read_json(Request, _),
	reply_json(json([wasError=0])).
% Interactive handlers
interactive_handler(Request) :-
  http_parameters(
    Request, 
    [
      service(Service,[optional(true),default('')]),
      jsonInput(JsonInput,[optional(true),default('{}')])
    ]
  ),
  request_base(Request,Protocol,Host,Port),
  fetch_interactive_output(Protocol,Host,Port,Service,JsonInput,JsonOutput),
  interactive_page(Service,JsonInput,JsonOutput,Head,Body),
  reply_html_page(Head,Body).

request_base(Request,Protocol,Host,Port) :-
  member(protocol(Protocol),Request),
  member(host(Host),Request),
  member(port(Port),Request).

fetch_interactive_output(_,_,_,'',_,''). % no service, no output.
fetch_interactive_output(_,_,_,_,'',''). % no input, no output. (maybe we should let the service handle blank input)

fetch_interactive_output(Protocol,Host,Port,Service,JsonInput,JsonOutput) :-
  service_url(Protocol,Host,Port,Service,URL),
  atom_json_term(JsonInput,JsonInputTerm,[]),
  http_post(URL, json(JsonInputTerm), JsonOutputRaw,[]),
  write(user_error,JsonOutputRaw),
  catch(
    atom_json_term(JsonOutput,JsonOutputRaw,[as(atom)]),
    Error,
    JsonOutput = ['The service "',Service,'" did not return parseable JSON.\nRaw output:\n',JsonOutputRaw]
  ).

service_url(Protocol,Host,Port,Service,URL) :-
  name(Protocol,ProtocolString),
  name(Host,HostString),
  name(Port,PortString),
  service_path(Service,Path),
  name(Path,PathString),
  append([ProtocolString,"://",HostString,":",PortString,PathString],URLString),
  name(URL,URLString).

service_path(dummy,'/dummy') :- !.
service_path(group,'/group') :- !.
service_path(feature,'/feature') :- !.
service_path(burst,'/burst') :- !.
service_path(contentPush,'/contentPush') :- !.

dummy_handler(Request) :-
	http_read_json(Request, JsonRequest),
  reply_json(json([x=25,y=50])).


% ------------------ Interactive page -----------------------
% Constructs the HTML head and body for the interactive page, given the raw json content
% and the selected service name, if any.
interactive_page(ServiceName,JsonInput,JsonOutput,Head,Body) :-
  service_radios(['dummy','group','feature','burst','contentPush'],ServiceName,ServiceRadioElements),
  Head = [ 
    title('Interactive Bursts Algorithm'),
    link([rel=stylesheet,href='/css/interactive.css'],[])
  ],
  Body = [ 
      h1('Interactive Bursts Algorithm'),
      div(
        [id=input],
        form(
          [action='/interactive',method='post',name='interactive_options',id='interactive_options'],
          [
            'Input JSON:',br([]),
            textarea([name=jsonInput,rows=40,cols=80],JsonInput),
            br([]),
            div(['Send to service: ', br([]) | ServiceRadioElements]),
            input([type=submit,value='Submit'],[])
          ]
        )
      ),
      div(
        [id='output'],
        [
          'Output:',br([]),
          textarea([name=jsonOutput,rows=40,cols=80],JsonOutput)
        ]
      )
    ].

% Sets whether the 'checked' attribute should be set on a radio button with the given value.
service_radio_is_checked(Value,Value,[checked=checked]) :- !.
service_radio_is_checked(Value,SelectedValue,[]).

% Constructs the radio button and label elements for a given service name.
service_radio(Value,SelectedValue,Radio,Label) :-
  service_radio_is_checked(Value,SelectedValue,Checked),
  Radio = input([type=radio,name=service,id=Value,value=Value|Checked],[]),
  Label = label([for=Value],Value).

% Constructs the list of service radio buttons and labels, given a list of names and a selected name.
service_radios(Values,SelectedValue,Elements) :-
  service_radios_acc(Values,SelectedValue,[],Elements).
service_radios_acc([],SelectedValue,Acc,Acc).
service_radios_acc([HeadValue|TailValues],SelectedValue,Acc,Final) :-
  service_radio(HeadValue,SelectedValue,HeadRadio,HeadLabel),
  service_radios_acc(TailValues,SelectedValue,[HeadRadio,HeadLabel,br([])|Acc],Final).

% ---------------- Utilities ------------------

/**
	json_equal(?A:term, ?B:term) is det
	
	Succeeds if A and B are equivalent JSON values
	
	@param A a Prolog term representing a JSON structure
	@param B a Prolog term representing a JSON structure
*/
%% if A is not nested json, therefore B cannot so be, therefore A must permute into B.
json_equal(json(A), json(B)) :-
	not(member(json(_), A)) ->	
		permutation(A, B), !.
json_equal(json([]), json([])).
json_equal(json([Name=json(J1)|RestA]), json(B)) :- 
	member(Name=json(J2), B),
	json_equal(json(J1), json(J2)),
	delete(B, Name=json(J2), RestB),
	json_equal(json(RestA), json(RestB)).
json_equal(json([Name=Value | RestA]), json(B)) :-
	not(Value = json(_)),
	member(Name=Value, B),
	delete(B, Name=Value, RestB),
	json_equal(json(RestA), json(RestB)).
	
% ---------- JSON TO PROLOG CONVERSION PREDICATES ----------
json_to_group_request(json(A), GroupRequest) :-
	member(maxNbOfGroups=NumGroups, A),
	member(maxStudentsPerGroups=StudentsPerGroup, A),
	member(forceUnderperfStudentsIntoGroups=ForceUnderperf, A),
	member(students=Students_json, A),
	maplist(json_to_student, Students_json, Students),
	GroupRequest = group_request(NumGroups, StudentsPerGroup, ForceUnderperf, Students).
	
json_to_student(json(A), Student) :-
	member(sid=Sid, A),
	member(classeSid=ClasseSid, A),
	member(gradeSid=GradeSid, A),
	member(lastSupportRecTypeSid=LastInstRec, A),
	member(skills=Skills_json, A),
	maplist(json_to_skill_level, Skills_json, SkillLevels), 
	exclude(null_skill_level, SkillLevels, NonNullSkillLevels),
	member(scores=Scores_json, A),
	maplist(json_to_score, Scores_json, Scores),
	(
		% if there's instruction history in the json, then marshal it out
		(	member(instructionHistory=History_json, A),
			maplist(json_to_instruction, History_json, InstructionHistory)
		)
		% otherwise simply set the history to empty
	;	InstructionHistory = []
	),
	make_student(Sid, ClasseSid, GradeSid, LastInstRec, NonNullSkillLevels, Scores, InstructionHistory, Student).
	
json_to_skill_level(json(A), SkillLevel) :-
	member(sid=Sid, A),
	member(bestLevel=BestLevel, A),
	member(lastLevel=LastLevel, A),
	make_skill_level(Sid, BestLevel, LastLevel, SkillLevel).
	
null_skill_level(SkillLevel) :-
	skill_level_best(SkillLevel, @null).
	
json_to_score(json(A), Score) :-
	member(measure=Measure, A),
	member(score=ScoreAttained, A),
	make_score(Measure, ScoreAttained, Score).
	
group_to_json(group(ClasseSid, StudentSids, Skills), json(A)) :-
	maplist(skill_sid, Skills, SkillSids),
	sort(SkillSids, SortedSkillSids),
	A = [classeSid=ClasseSid, studentSids=StudentSids, skills=SortedSkillSids].
	
groups_to_json(Groups, json([groups=Groups_json])) :-
	maplist(group_to_json, Groups, Groups_json).

json_to_feature_request(json(A), FeatureRequest) :-
	member(results=Results_json, A),
	maplist(json_to_result, Results_json, Results),
	FeatureRequest = feature_request(Results).
	
json_to_result(json(A), Result) :-
	member(resultProbeSid=ResultProbeSid, A),
	member(measureSid=MeasureSid, A),
	member(score=Score, A),
	member(gradeSidResult=GradeSid, A),
	member(ilaDescriptives=json(ILA), A),
	maplist(convert_equal_to_hypen, ILA, ILAList),
	list_to_assoc(ILAList, ILADescriptives),
	make_result(ResultProbeSid, MeasureSid, Score, GradeSid, ILADescriptives, Result).
	
skill_levels_to_json(SkillLevels, json([results=SkillLevels_json])) :-
	maplist(skills_to_json, SkillLevels, SkillLevels_json).
	
skills_to_json(skill_levels(ResultProbeSid, WasError, Skills), json([resultProbeSid=ResultProbeSid, skills=Skills_json, wasError=WasError])) :-
	maplist(skill_to_json, Skills, Skills_json).
	
skill_to_json(skill_level(Skill, Level), json([sid=SkillSid, level=Level])) :-
	skill(SkillSid, Skill, _, _).

json_to_content(json(A), Content) :-
	member(pace=PaceSid, A),
	pace(PaceSid, Pace),
	member(strand=StrandSid, A),
	strand(StrandSid, Strand, _, _),
	member(sequence=Sequence, A),
	make_content(Strand, Pace, Sequence, Content).
	
json_to_instruction(json(A), Instruction) :-
	member(processedDate=Date, A),
	member(skills=SkillSids, A),
	member(measures=MeasureSids, A),
	member(content=Content, A),
	maplist(json_to_content, Content, ContentElements),
	make_instruction(Date, SkillSids, MeasureSids, ContentElements, Instruction).
	
json_to_burst_request(json(A), BurstRequest) :-
	member(students=Students_json, A),
	member(instructionHistory=History_json, A),
	maplist(json_to_student, Students_json, Students),
	maplist(json_to_instruction, History_json, InstructionHistory),
	BurstRequest = burst_request(Students, InstructionHistory, 1).
	
content_to_json(Content, json(A)) :-
	content_strand(Content, Strand),
	strand(StrandSid, Strand, _, _),
	content_pace(Content, Pace),
	pace(PaceSid, Pace),
	content_sequence(Content, Sequence),
	A = [
		pace = PaceSid,
		strand = StrandSid,
		sequence = Sequence
	].
	
compare_content(Delta, Content1, Content2) :-
	content_strand(Content1, Strand1),
	content_strand(Content2, Strand2),
	strand(StrandSid1, Strand1, _, _),
	strand(StrandSid2, Strand2, _, _),
	compare(Delta, StrandSid1, StrandSid2).
	
skill_low_outliers(LowOutliers, SkillSid, SkillWithOutliers) :-
  catch(
    [
  	skill(SkillSid, Skill, _, _),
  	member(low_outliers(Skill, LowOutliersForSkill),LowOutliers),!,
  	maplist(student_sid, LowOutliersForSkill, LowOutlierSidsForSkill),
  	SkillWithOutliers = json([sid = SkillSid, lowOutliers = LowOutliersSidsForSkill])
    ],
    Error,
    SkillWithOutliers = json([sid = SkillSid, lowOutliers = []])
  ).
skill_low_outliers(_, SkillSid, SkillWithOutliers) :-
	SkillWithOutliers = json([sid = SkillSid, lowOutliers = []]).
	
burst_to_json(Burst, json(A)) :-
	burst_skills(Burst, Skills),
	maplist(skill_sid, Skills, SkillSids),
	sort(SkillSids, SortedSkillSids),
	burst_measures(Burst, Measures),
	maplist(measure_sid, Measures, MeasureSids),
	% we want distinct measures; the built-in sort predicate removes duplicates
	sort(MeasureSids, DistinctMeasureSids),
	burst_content(Burst, Content),
	predsort(compare_content, Content, SortedContent),
	maplist(content_to_json, SortedContent, Content_json),
	burst_low_outliers(Burst, LowOutliers),
	maplist(skill_low_outliers(LowOutliers), SortedSkillSids, SkillSidsLowOutliers),
	burst_high_outliers(Burst, HighOutliers),
	maplist(student_sid, HighOutliers, HighOutliersSids),
	burst_trace(Burst, Trace),
	A = [
		skills = SkillSidsLowOutliers,
		measures = DistinctMeasureSids,
		content = Content_json,
		highOutliers = HighOutliersSids,
		trace = Trace
	].
	
json_to_content_slot(json(A), ContentSlot) :-
	member(strandId=StrandId, A),
	member(seq=Sequence, A),
	member(paceId=PaceId, A),
	make_content_slot(StrandId, Sequence, PaceId, ContentSlot).
	
json_to_content_push(json(A), ContentPush) :-
	member(contentSlotting=ContentSlotsJson, A),
	maplist(json_to_content_slot, ContentSlotsJson, ContentSlots),
	ContentPush = ContentSlots.
	
% ---------- TESTS ----------

:- begin_tests(bursts_server, [setup(start_bursts_server), cleanup(stop_bursts_server)]).

start_bursts_server :-
	server(11201).
	
stop_bursts_server :-
	http_stop_server(11201, []).
	
test(get_json) :-
	open('test/data/group_output.json', read, InStream),
	json_read(InStream, Output),
	close(InStream),
	http_get('http://localhost:11201/group_static', ServerOutput, []),
	json_equal(ServerOutput, Output).
	
test(test_group_handler, [sto(rational_trees)]) :-
	open('test/data/group_input.json', read, InStream),
	json_read(InStream, Input),
	close(InStream),
	open('test/data/group_output.json', read, InStream),
	json_read(InStream, Output),
	close(InStream),
	http_post('http://localhost:11201/group_test', json(Input), ServerOutput, []),
	json_equal(ServerOutput, Output).
	
test(test_feature_handler, [sto(rational_trees)]) :-
	open('test/data/feature_input.json', read, InStream),
	json_read(InStream, Input),
	close(InStream),
	open('test/data/feature_output.json', read, InStream),
	json_read(InStream, Output),
	close(InStream),
	http_post('http://localhost:11201/feature_test', json(Input), ServerOutput, []),
	json_equal(ServerOutput, Output).
	
test(test_burst_handler, [sto(rational_trees)]) :-
	open('test/data/burst_input.json', read, InStream),
	json_read(InStream, Input),
	close(InStream),
	open('test/data/burst_output.json', read, InStream),
	json_read(InStream, Output),
	close(InStream),
	http_post('http://localhost:11201/burst_test', json(Input), ServerOutput, []),
	json_equal(ServerOutput, Output).
	

test(test_content_handler, [sto(rational_trees)]) :-
	open('test/data/content_input.json', read, InStream),
	json_read(InStream, Input),
	close(InStream),
	http_post('http://localhost:11201/content_test', json(Input), ServerOutput, []),
	json_equal(ServerOutput, json([wasError=0])).

	
% smoke test of a real handler
test(test_real_handler, [sto(rational_trees)]) :-
	open('test/data/group_input.json', read, InStream),
	json_read(InStream, Input),
	close(InStream),
	http_post('http://localhost:11201/group', json(Input), ServerOutput, []),
	ServerOutput = json([groups=[json([classeSid=724932, studentSids=[686108101, 65410997, 80597108, 766104116, 7486597], skills=[1, 2]]), json([classeSid=844945, studentSids=[69697105, 667110101, 838121116, 744110104, 746101105], skills=[2, 3]]), json([classeSid=724932, studentSids=[7486697, 65611097, 65697117, 765115117, 71897108], skills=[1, 3]])]]).
	
:- end_tests(bursts_server).

:- begin_tests(json).

% simple case of non-nested json structure
test(json_equal_flat) :-
	A = json([first_name=genevieve, middle_name=xara, last_name=stewart]),
	B = json([middle_name=xara, first_name=genevieve, last_name=stewart]),
	json_equal(A, B).
	
% embedded json in a different place and itself having different order (breaks the simple permutation case).
test(json_equal_nested, [nondet]) :-
	A = json([first_name=genevieve, middle_name=xara, last_name=stewart, brother=json([first_name=django, middle_name=francesco, last_name=stewart])]),
	B = json([first_name=genevieve, brother=json([middle_name=francesco, first_name=django, last_name=stewart]),middle_name=xara, last_name=stewart]),
	json_equal(A, B).
	
% a negative case to make sure we detect non-matching structures
test(json_equal_nested_neg, [fail]) :-
	A = json([first_name=genevieve, middle_name=xara, last_name=stewart, brother=json([first_name=django, middle_name=francesco, last_name=stewart])]),
	B = json([first_name=genevieve, brother=json([middle_name=francesco, first_name=jango, last_name=stewart]),middle_name=xara, last_name=stewart]),
	json_equal(A, B).
	
% conversion between json and native prolog student
test(json_to_student, [nondet]) :-
	json_to_student(json([
		sid=123, 
		classeSid=456, 
		gradeSid=3,
		lastSupportRecTypeSid=2,
		skills=[json([sid=2, bestLevel=2, lastLevel=0])], 
		scores=[json([measure=1, score=35]), json([measure=2, score=17])]]), S),
	student_sid(S, 123),
	student_classe_sid(S, 456),
	student_grade(S, 1),
	student_last_inst_rec(S, 2),
	student_skill_levels(S, [skill_level(letter_sounds, 2, 0)]),
	student_scores(S, [score(isf, 35), score(lnf, 17)]).
	
% conversion between json and native prolog student, excluding null skill levels
test(json_to_student_no_nulls, [nondet]) :-
	json_to_student(json([
		sid=123, 
		classeSid=456, 
		gradeSid=3,
		lastSupportRecTypeSid=2,
		skills=[
			json([sid=2, bestLevel=2, lastLevel= @null]), 
			json([sid=3, bestLevel= @null, lastLevel=0]), 
			json([sid=4, bestLevel= @null, lastLevel= @null])
		], 
		scores=[json([measure=1, score=35]), json([measure=2, score=17])]]), 
	S),
	student_skill_levels(S, [skill_level(letter_sounds, 2, @null)]).
	
% conversion between json and native prolog skill
test(json_to_skill_level, [nondet]) :-
	json_to_skill_level(json([sid=10, bestLevel=2, lastLevel=1]), SkillLevel),
	skill_level_name(SkillLevel, vocabulary_oral_language),
	skill_level_best(SkillLevel, 2),
	skill_level_last(SkillLevel, 1).
	
% conversion between json and native prolog score
test(json_to_score, [nondet]) :-
	json_to_score(json([measure=3, score=40]), Score),
	score_measure(Score, psf),
	score_score(Score, 40).

% conversion of the whole request packet
test(json_to_group_request, [nondet]) :-
	open('test/data/group_input.json', read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_group_request(JsonRequest, group_request(3, 5, 0, Students)),
	length(Students, 74).
	
% conversion of the grouping response to json
test(groups_to_json, [nondet]) :-
	open('test/data/group_input.json', read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_group_request(JsonRequest, group_request(NumGroups, StudentsPerGroup, 0, Students)),
	group(NumGroups, StudentsPerGroup, Students, Groups),
	groups_to_json(Groups, json(Response)),!,
	member(groups=[json(Group)|_], Response),
	member(classeSid=724932, Group),
	member(studentSids=[686108101, 65410997, 80597108, 766104116, 7486597], Group).
	
% conversion between json and native prolog result
test(json_to_result, [nondet]) :-
	json_to_result(json([resultProbeSid=1002, measureSid=4, score=28, gradeSidResult=2, ilaDescriptives=json(['Psf1'=28, 'Nwf2'=12])]), Result),
	result_probe_sid(Result, 1002),
	result_measure(Result, nwf),
	result_score(Result, 28),
	result_grade(Result, k),
	result_ila(Result, ILA),
	get_assoc('Psf1', ILA, 28).
	
% conversion of the whole feature request packet
test(json_to_feature_request, [nondet]) :-
	open('test/data/feature_input.json', read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_feature_request(JsonRequest, feature_request(Results)),
	length(Results, 5).
	
% conversion of the feature response to json
test(skill_levels_to_json, [nondet]) :-
	open('test/data/feature_output.json', read, InStream),
	json_read(InStream, JsonCorrectResponse),
	close(InStream),
	test_feature('test/data/feature_input.json', JsonResponse),
	json_equal(JsonResponse, JsonCorrectResponse).

% conversion between json and native prolog content
test(json_to_content, [nondet]) :-
	json_to_content(json([pace=1, strand=2, sequence=36]), Content),
	content_strand(Content, phonemic_awareness),
	content_sequence(Content, 36),
	content_pace(Content, cool).
	
% conversion between json and native prolog instruction
test(json_to_instruction, [nondet]) :-
	json_to_instruction(json([
		skills=[4, 2], 
		content=[json([pace=1, strand=2, sequence=36]), json([pace=1, strand=1, sequence=30])], 
		processedDate = '2008-06-19 02:34:28',
		measures=[3, 1]]),
		Instruction),
	instruction_measure(Instruction, 2, isf),
	instruction_skills(Instruction, [regular_words, letter_sounds]).
	
% conversion of the whole burst request packet
test(json_to_burst_request, [nondet]) :-
	open('test/data/burst_input.json', read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_burst_request(JsonRequest, burst_request(Students, InstructionHistory, 1)),
	length(Students, 4),
	length(InstructionHistory, 7).
		
% conversion of the burst response to json
test(burst_to_json, [nondet]) :-
	open('test/data/burst_output.json', read, InStream),
	json_read(InStream, JsonCorrectResponse),
	close(InStream),
	test_burst('test/data/burst_input.json', JsonResponse),
	json_equal(JsonResponse, JsonCorrectResponse).
	
% conversion between json and native prolog slot entry
test(json_to_content_slot, [nondet]) :-
	json_to_content_slot(json([strandId=1, seq=18, paceId=2]), ContentSlot),
    content_slot_strand(ContentSlot, phonological_awareness),
	content_slot_sequence(ContentSlot, 18),
	content_slot_pace(ContentSlot, warm).
	
% conversion of the whole content push from json to prolog
test(json_to_content_push, [nondet]) :-
	open('test/data/content_input.json', read, InStream),
	json_read(InStream, JsonContentPush),
	json_to_content_push(JsonContentPush, ContentPush),
	length(ContentPush, 884),
	close(InStream).
	
% load the content slotting into the global database
test(load_content, [sto(rational_trees), nondet]) :-
	open('test/data/content_input.json', read, InStream),
	json_read(InStream, JsonContentPush),
	json_to_content_push(JsonContentPush, ContentPush),
	load_content(ContentPush),
	findall(content_slot(Strand, Sequence, Pace), content_slot(Strand, Sequence, Pace), ContentSlots),
	length(ContentSlots, 884).
	
:- end_tests(json).

% non-plunit tests, for tracing/debugging
test_group(Filename, json(Response)) :-
	open(Filename, read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_group_request(JsonRequest, group_request(NumGroups, StudentsPerGroup, 0, Students)),
	group(NumGroups, StudentsPerGroup, Students, Groups),!,
	maplist(format('~w~n'), Groups),
	groups_to_json(Groups, Response).

test_feature(Filename, Response) :-
	open(Filename, read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_feature_request(JsonRequest, feature_request(Results)),
	feature_detect(Results, SkillLevels),
	skill_levels_to_json(SkillLevels, Response).

test_burst(Filename, Response) :-
	open(Filename, read, InStream),
	json_read(InStream, JsonRequest),
	close(InStream),
	json_to_burst_request(JsonRequest, burst_request(Students, InstructionHistory, 1)),!,
	generate_burst(Students, InstructionHistory, 1, Burst),
	burst_to_json(Burst, Response).

	



