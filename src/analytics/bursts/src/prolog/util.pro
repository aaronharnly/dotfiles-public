/** <module> Utility predicates

@version $Id: util.pro,v 1.13 2008/10/24 22:38:59 jds Exp $

*/

% flag in the (thread-safe) global database that defines the current log level.  
% message_hook/3 clauses can then decide what to do with the log_level.
:- flag(log_level, _, normal).

message_hook(_, detail, _) :-
	flag(log_level, LogLevel, LogLevel),
	LogLevel \= detail.
	
% get the current date and time
current_date_time(Date, Time) :-
	get_time(TimeStamp),
	stamp_date_time(TimeStamp, DateTime, local),
	date_time_value(year, DateTime, Year),
	date_time_value(month, DateTime, Month),
	date_time_value(day, DateTime, Day),
	date_time_value(hour, DateTime, Hour),
	date_time_value(minute, DateTime, Minute),
	date_time_value(second, DateTime, Second),
	concat_atom([Year, Month, Day], '-', Date),
	concat_atom([Hour, Minute, Second], ':', Time).


% counts the number of tokens per type in a list, returns in order of descending frequency
count_tokens(A-B, A-NumTokens) :-
	length(B, NumTokens).
	
pair_pred(<, _-B1, _-B2) :-
	B1 > B2.
pair_pred(>, _-B1, _-B2) :-
	B1 < B2.
pair_pred(=, _, _).	

count_keys(Keys, SortedKeyCounts) :-
	msort(Keys, SortedKeys),
	pairs_keys_values(Pairs, SortedKeys, _), 
	group_pairs_by_key(Pairs, GroupedKeys), 
	maplist(count_tokens, GroupedKeys, CountedKeys), 
	predsort(pair_pred, CountedKeys, SortedKeyCounts).
	
convert_equal_to_hypen(A=B,A-B).
% ---------- TESTS ----------
:- begin_tests(util).

% NB duplicate counts are removed!  so [7,1] is not in the output, since 4 already has a count of 1
test(count_keys) :-
	count_keys([1, 1, 1, 0, 4, 2, 1, 0, 2, 0, 7], 
		[1-4, 0-3, 2-2, 4-1]).
		
test(compare_lists) :-
	List1 = [1, 4, 9, 10, 12],
	List2 = [1, 4, 9, 10, 12],
	List3 = [1, 4, 9, 10, 11],
	subtract(List1, List2, []),
	not(subtract(List1, List3, [])).
	
:- end_tests(util).