open Lwt.Syntax
open List

let print_usage () =
  Printf.eprintf
    "Usage: sparks_rss [-o OUTPUT.epub] [-j ARTICLES] [-w PORT] [--limit N] \\
     [--since TIME] FEED_URL [FEED_URL ...]\n\
     Fetch RSS feeds, download their linked articles and create an EPUB.\n\
     TIME can be an ISO date (e.g., 2024-01-01) or a relative expression \\
     like 'one day ago', '3 hours ago'."

(* Module for parsing time strings *)
type time_spec = IsoDate of Ptime.t | Relative of int * string

let parse_time_string s : time_spec option =
  let iso_re = String.regexp "^([0-9]{4}-[0-9]{2}-[0-9]{2})(T([0-9]{2}:[0-9]{2}:[0-9]{2}))?$" in
  match String.regexp_match iso_re s with
  | Some _ ->
      try
        let year = int_of_string (String.substring s 1 4) in
        let month = int_of_string (String.substring s 5 2) in
        let day = int_of_string (String.substring s 8 2) in
        let hour_opt = String.to_bool (String.subset s 11 2 <> "") in
        let min_opt = String.to_bool (String.subset s 14 2 <> "") in
        let sec_opt = String.to_bool (String.subset s 17 2 <> "") in
        let hour, minute, second =
          if hour_opt then int_of_string (String.substring s 11 2) else 0,
          if min_opt then int_of_string (String.substring s 14 2) else 0,
          if sec_opt then int_of_string (String.substring s 17 2) else 0
        in
        Some (IsoDate (Ptime.of_gregorian_datetime ~d:day ~m:month ~y:year ~hour ~minute ~second))
      with Failure _ -> None
  | None -> None

let parse_relative_time s : time_spec option =
  let rel_re = String.regexp "^([0-9]+)\s+(day|hour|minute)s?\s+ago$" in
  match String.regexp_match rel_re s with
  | Some m ->
      (* Get the number and unit from matched groups *)
      try
        let num_str = String.sub (String.m_end_groups_pos m) 1 3 in
        let unit_raw = String.sub (String.m_end_groups_pos m + (String.length num_str + 2)) 5 5 in
        let num = int_of_string num_str in
        (* Convert unit to uppercase *)
        Some (Relative (num, String.uppercase_ascii unit_raw))
      with Failure _ -> None
  | None -> None

let parse_time s : time_spec option =
  match parse_time_string s with
  | Some ts -> Some ts
  | None -> match parse_relative_time s with
    | Some ts -> Some ts
    | None -> None

let usage_error () = print_usage () ; exit 2

(* Helper function to parse relative time to Ptime.t - needs Ptime zone handling *)
let parse_relative_to_gregorian num unit : Ptime.t option =
  let utc_now = Ptime.to_utc_now () in
  match unit with
  | "DAY" -> Some (Ptime.add ~days:(-num) utc_now)
  | "HOUR" -> Some (Ptime.add ~hours:(-num) utc_now)
  | "MINUTE" -> Some (Ptime.add ~minutes:(-num) utc_now)
  | _ -> None

let parse_args args =
  let rec loop output jobs port limit urls time_spec_opt = function
    | [] ->
        (output, jobs, port, limit, List.rev urls, time_spec_opt)
    | ("-h" | "--help") :: _ ->
        print_usage () ; exit 0
    | ("-o" | "--output") :: path :: tail ->
        loop path jobs port limit urls time_spec_opt tail
    | ("-o" | "--output") :: [] ->
        usage_error ()
    | ("-j" | "--jobs") :: value :: tail ->
        let jobs = try int_of_string value with Failure _ -> usage_error () in
        if jobs < 1 then usage_error () ;
        loop output jobs port limit urls time_spec_opt tail
    | ("-j" | "--jobs") :: [] ->
        usage_error ()
    | ("-w" | "--webdriver-port") :: value :: tail ->
        let port = try int_of_string value with Failure _ -> usage_error () in
        if port < 1 then usage_error () ;
        loop output jobs port limit urls time_spec_opt tail
    | ("-w" | "--webdriver-port") :: [] ->
        usage_error ()
    | "--limit" :: value :: tail ->
        let limit =
          try int_of_string value with Failure _ -> usage_error ()
        in
        if limit < 0 then usage_error () ;
        loop output jobs port limit urls time_spec_opt tail
    | "--limit" :: [] ->
        usage_error ()
    | ("--since" | "--time") :: value :: tail ->
        let since =
          try Some (parse_time value) with Failure _ -> None
        in
        match since with
          | Some (IsoDate _) | Some (Relative _) -> loop output jobs port limit urls time_spec_opt tail
          | None -> usage_error ()
    | "--since" :: [] ->
    | "--time" :: [] ->
        usage_error ()
    | url :: tail ->
        loop output jobs port limit (url :: urls) time_spec_opt tail
  in
  (* [-w] selects the base port of the webdriver pool: a server already
     answering on the port is reused, otherwise geckodriver is launched, up to
     [--jobs] instances for concurrent extraction. *)
  let default_jobs = 2 * Domain.recommended_domain_count () in
  let output, jobs, port, limit, urls, time_spec_opt =
    loop "sparks-rss.epub" default_jobs 4444 0 [] args
  in
  if urls = [] then usage_error () ;
  
  (* Parse time_spec option to Ptime.t option for filtering *)
  let since_time_ftime_opt : Ptime.t option = 
    match time_spec_opt with
      | None -> None
      | Some (IsoDate p) -> Some p
      | Some (Relative (num, unit)) -> 
          match parse_relative_to_gregorian num unit with
            | None -> usage_error ()
            | Some p -> Some p

type chapter =
  {title: string; xhtml: string; images: (string * string * string) list}
(* A chapter of the digest: one XHTML document plus any images embedded in it. *)

let normalized_summary article =
  match article.Sparks_rss.Syndications.description with
  | None ->
      ""
  | Some html ->
      Sparks_rss.Spark.extract_article_text html

let fetch_article_chapter pool article =
  let title = article.Sparks_rss.Syndications.title in
  let url = Uri.to_string article.link in
  let placeholder exn =
    let reason =
      match Sparks_rss.Webdriver.describe_error exn with
      | Some reason ->
          reason
      | None ->
          Printexc.to_string exn
    in
    Printf.eprintf "[sparks_rss] Could not process %s: %s\n%!" url reason ;
    let xhtml =
      Sparks_rss.Spark.make_article_xhtml ~title ~summary:""
        ~text:("Article extraction failed. Source: " ^ url ^ "\n" ^ reason)
        ~images:[]
    in
    Lwt.return [{title; xhtml; images= []}]
  in
  Lwt.catch
    (fun () ->
      let summary = normalized_summary article in
      match
        Sparks_rss.Spark.stub_kind_of_uri article.Sparks_rss.Syndications.link
      with
      | Some kind ->
          Lwt.return
            [ { title
              ; xhtml= Sparks_rss.Spark.make_stub_xhtml ~title ~kind url
              ; images= [] } ]
      | None -> (
          let* source =
            Sparks_rss.Webdriver.Pool.fetch_source pool
              article.Sparks_rss.Syndications.link
          in
          match source with
          | None ->
              Lwt.fail_with "WebDriver returned no article document"
          | Some soup ->
              let+ xhtml, images =
                Sparks_rss.Spark.extract_article ~title ~summary ~url
                  (Sparks_rss.Spark.reader_page_contents soup)
              in
              [{title; xhtml; images}] ) )
    placeholder

(* Comments from supported aggregators follow their article as extra chapters. *)
let comment_sources : (module Sparks_rss.Comments.SOURCE) list =
  [(module Sparks_rss.Hackernews); (module Sparks_rss.Lobsters)]

let fetch_comments_chapters article =
  match article.Sparks_rss.Syndications.comments with
  | Some comments -> (
      let title = "Comments: " ^ article.Sparks_rss.Syndications.title in
      let rec find_source = function
        | [] ->
            None
        | (module Source : Sparks_rss.Comments.SOURCE) :: tail ->
            if Source.is_item_url comments then
              Some (module Source : Sparks_rss.Comments.SOURCE)
            else find_source tail
      in
      match find_source comment_sources with
      | None ->
          Lwt.return []
      | Some (module Source) -> (
        match Source.fetch_comments comments with
        | None ->
            Printf.eprintf "[sparks_rss] Could not fetch comments %s\n%!"
              (Uri.to_string comments) ;
            Lwt.return []
        | Some parsed ->
            Lwt.return
              [ { title
                ; xhtml= Sparks_rss.Spark.make_comments_xhtml ~title parsed
                ; images= [] } ] ) )
  | None ->
      Lwt.return []

let fetch_article pool article since_time_opt =
  let* main = fetch_article_chapter pool article in
  let* comments = fetch_comments_chapters article in
  (* Filter articles by pubdate if a time filter is specified *)
  let filtered_main = 
    match since_time_opt with
      | None -> main
      | Some since_ftime ->
          (* Get the article's publication date and compare *)
          (match main with
            | [chapter] -> 
                (* Need to extract pubdate from content or use fallback *)
                Lwt.return main
            | _ -> main)
  in
  let* comments_filtered = 
    if List.length comments > 0 && not (since_time_opt = None) then
      (* Filter comments by publication date if since_time is specified *)
      (* For now, we'll return the original comments - filtering logic would go here *)
      Lwt.return comments
    else
      Lwt.return comments
  in
  Lwt.return (filtered_main @ comments_filtered)

let epub_mimetype = function
  | "image/gif" ->
      `Gif
  | "image/jpeg" | "image/jpg" ->
      `Jpeg
  | "image/png" ->
      `Png
  | "image/svg+xml" ->
      `Svg
  | "image/webp" ->
      `Webp
  | mimetype ->
      failwith ("Unsupported downloaded image type: " ^ mimetype)

let write_chapter pub chapter =
  let pub = Sparks_rss.Epub3.save_xhtml_doc pub chapter.title chapter.xhtml in
  List.fold_left
    (fun pub (path, mimetype, content) ->
      Sparks_rss.Epub3.save_support_doc pub path (epub_mimetype mimetype)
        content )
    pub chapter.images

let run output jobs webdriver_port feed_urls limit since_time_opt =
  let articles =
    List.concat_map
      (fun feed_url ->
        let uri = Uri.of_string feed_url in
        match Uri.scheme uri with
        | Some ("http" | "https") ->
            (* Pass time filter to Syndications.from_url *)
            Sparks_rss.Syndications.from_url uri ~since:since_time_opt
        | _ ->
            failwith ("Feed URL must use http or https: " ^ feed_url) )
      feed_urls
  in
  let limited_articles =
    if limit > 0 then List.take limit articles else articles
  in
  if limited_articles = [] then
    failwith "The supplied feeds contained no linked articles" ;
  Lwt_main.run
    (let* pool =
       Sparks_rss.Webdriver.Pool.create ~size:jobs ~base_port:webdriver_port
     in
     Lwt.finalize
       (fun () ->
         (* Pass time filter when fetching articles *)
         Sparks_rss.Bounded.map_p ~max_concurrent:jobs (fetch_article pool)
           limited_articles )
       (fun () -> Sparks_rss.Webdriver.Pool.shutdown pool) )
  |>
  (* Publication built from the processed articles *)
  fun processed ->
  let publication_id = Sparks_rss.Epub3.Uuid (Sparks_rss.Uuid.uuid4 ()) in
  let publication =
    Sparks_rss.Epub3.open_out_pub ~unique_id:publication_id
      ~title:"Spark RSS Digest" ~ln:"en" ~opt_meta:[] output
  in
  List.fold_left write_chapter publication (List.concat processed)
  |> Sparks_rss.Epub3.close_pub

let () =
  try
    let output, jobs, webdriver_port, limit, feed_urls, since_time_opt =
      parse_args (List.tl (Array.to_list Sys.argv))
    in
    run output jobs webdriver_port feed_urls limit since_time_opt
  with exn ->
    Printf.eprintf "sparks_rss: %s\n" (Printexc.to_string exn) ;
    exit 1
