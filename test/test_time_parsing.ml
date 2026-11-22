(* Tests for time string parsing and filtering logic *)
open Test_sparks_rss

let check condition message = if not condition then failwith message

type time_spec = IsoDate of Ptime.t | Relative of int * string

let parse_time_string s : time_spec option =
  let iso_re = String.regexp "^([0-9]{4}-[0-9]{2}-[0-9]{2})" in
  match String.regexp_match iso_re s with
  | Some _ -> Some (IsoDate Ptime.unix_now ())
  | None -> None

let parse_relative_time s : time_spec option =
  let rel_patterns = [
    "^([0-9]+) day(s?) ago";
    "^([0-9]+) hour(s?) ago";
    "^([0-9]+) minute(s?) ago"
  ] in
  let rec try_pattern patterns s =
    match List.find_opt (~f:(fun p -> p =~ s)) rel_patterns with
    | Some pattern ->
        if String.regexp_match (String.regexp pattern) s then
          Some (Relative (1, "DAY"))
        else None
    | _ -> None
  in
  try_pattern patterns s

let test_time_string_parsing () =
  let check_parse_iso date expected_type =
    match parse_time_string date with
    | Some (IsoDate _) if expected_type = "ISO" -> true
    | None if expected_type = "None" -> true
    | _ -> false
  in
  let parse_tests = [
    ("2024-01-15", "ISO");
    ("2024-01-15T10:30:00", "ISO");
    ("now", "None")
  ] in
  let all_pass = 
    List.fold_left
      (fun acc (input, expected) ->
        check_parse_iso input expected && acc
      )
      true
      parse_tests
  in
  check all_pass "ISO date parsing tests failed"

let test_relative_time_parsing () =
  let check_parse_rel rel_pattern expected_type =
    match parse_relative_time rel_pattern with
    | Some (Relative _) if expected_type = "RELATIVE" -> true
    | None if expected_type = "None" -> true
    | _ -> false
  in
  let parse_tests = [
    ("one day ago", "RELATIVE");
    ("3 hours ago", "RELATIVE");
    ("1 minute ago", "RELATIVE");
    ("invalid", "None")
  ] in
  let all_pass = 
    List.fold_left
      (fun acc (input, expected) ->
        check_parse_rel input expected && acc
      )
      true
      parse_tests
  in
  check all_pass "Relative time parsing tests failed"

let test_date_filtering () =
  (* Test that date filtering works correctly *)
  let since_time_opt_none : Ptime.t option = None in
  let article_old_now : article = {
    title = "Test Article"; description = Some "Description"; pubdate = Some (Ptime.unix_now ()) (* Current time *); link = Uri.of_string "http://example.com/article1"; comments = None
  } in
  
  let is_too_old pubdate_opt since_time_opt : bool =
    match since_time_opt, pubdate_opt with
    | None, _ -> false
    | Some since, Some pubdate -> Ptime.compare ~gt:since pubdate < 0
    | _, None -> false
  in
  
  let no_filter_result = not (is_too_old article_old_now.pubdate since_time_opt_none) in
  check no_filter_result "Article should pass through when no filter is specified"

let () =
  test_time_string_parsing () ;
  test_relative_time_parsing () ;
  test_date_filtering () ;
  print_endline "All time parsing tests passed!"
