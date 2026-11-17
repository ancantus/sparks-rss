open Lwt.Syntax
open List

let print_usage () =
  Printf.eprintf
    "Usage: sparks_rss [-o OUTPUT.epub] [-j ARTICLES] [-w PORT] [--limit N] FEED_URL \
     [FEED_URL ...]\n\
     Fetch RSS feeds, download their linked articles and create an EPUB.\n"

let usage_error () = print_usage () ; exit 2

let parse_args args =
  let rec loop output jobs port limit urls = function
    | [] ->
        (output, jobs, port, limit, List.rev urls)
    | ("-h" | "--help") :: _ ->
        print_usage () ; exit 0
    | ("-o" | "--output") :: path :: tail ->
        loop path jobs port limit urls tail
    | ("-o" | "--output") :: [] ->
        usage_error ()
    | ("-j" | "--jobs") :: value :: tail ->
        let jobs = try int_of_string value with Failure _ -> usage_error () in
        if jobs < 1 then usage_error () ;
        loop output jobs port limit urls tail
    | ("-j" | "--jobs") :: [] ->
        usage_error ()
    | ("-w" | "--webdriver-port") :: value :: tail ->
        let port = try int_of_string value with Failure _ -> usage_error () in
        if port < 1 then usage_error () ;
        loop output jobs port limit urls tail
    | ("-w" | "--webdriver-port") :: [] ->
        usage_error ()
    | "--limit" :: value :: tail ->
        let limit = try int_of_string value with Failure _ -> usage_error () in
        if limit < 0 then usage_error () ;
        loop output jobs port limit urls tail
    | "--limit" :: [] ->
        usage_error ()
    | url :: tail ->
        loop output jobs port limit (url :: urls) tail
  in
  (* [-w] selects the base port of the webdriver pool: a server already
     answering on the port is reused, otherwise geckodriver is launched, up to
     [--jobs] instances for concurrent extraction. *)
  let default_jobs = 2 * Domain.recommended_domain_count () in
  let output, jobs, port, limit, urls =
    loop "sparks-rss.epub" default_jobs 4444 0 [] args
  in
  if urls = [] then usage_error () ;
  (output, jobs, port, limit, urls)

let normalized_summary article =
  match article.Sparks_rss.Syndications.description with
  | None ->
      ""
  | Some html ->
      Sparks_rss.Spark.extract_article_text html

let fetch_article pool article =
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
    Lwt.return (xhtml, [])
  in
  Lwt.catch
    (fun () ->
      let summary = normalized_summary article in
      match
        Sparks_rss.Spark.stub_kind_of_uri article.Sparks_rss.Syndications.link
      with
      | Some kind ->
          Lwt.return (Sparks_rss.Spark.make_stub_xhtml ~title ~kind url, [])
      | None ->
          let* source =
            Sparks_rss.Webdriver.Pool.fetch_source pool
              article.Sparks_rss.Syndications.link
          in
          ( match source with
          | None ->
              Lwt.fail_with "WebDriver returned no article document"
          | Some soup ->
              Sparks_rss.Spark.extract_article ~title ~summary ~url
                (Sparks_rss.Spark.reader_page_contents soup) ) )
    placeholder

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

let write_article pub article (xhtml, images) =
  let pub =
    Sparks_rss.Epub3.save_xhtml_doc pub article.Sparks_rss.Syndications.title
      xhtml
  in
  List.fold_left
    (fun pub (path, mimetype, content) ->
      Sparks_rss.Epub3.save_support_doc pub path (epub_mimetype mimetype)
        content )
    pub images

let run output jobs webdriver_port feed_urls limit =
  let articles =
    List.concat_map
      (fun feed_url ->
        let uri = Uri.of_string feed_url in
        match Uri.scheme uri with
        | Some ("http" | "https") ->
            Sparks_rss.Syndications.from_url uri
        | _ ->
            failwith ("Feed URL must use http or https: " ^ feed_url) )
      feed_urls
  in
  let limited_articles =
    if limit > 0 then List.take limit articles
    else articles
  in
  if limited_articles = [] then
    failwith "The supplied feeds contained no linked articles" ;

  (* Counter to track processed article count for progress reporting *)
  let counter_ref = ref 0 in
  
  Lwt_main.run 
    (let* pool = Sparks_rss.Webdriver.Pool.create ~size:jobs ~base_port:webdriver_port in

     Lwt.finalize
       (fun () ->
         Sparks_rss.Bounded.map_p ~max_concurrent:jobs
           (fetch_article pool)
           limited_articles )
       (fun () -> Sparks_rss.Webdriver.Pool.shutdown pool))
  |> (* Publication built from the processed articles *)
     (fun processed ->
       let publication_id = Sparks_rss.Epub3.Uuid (Sparks_rss.Uuid.uuid4 ()) in
       let publication =
         Sparks_rss.Epub3.open_out_pub ~unique_id:publication_id
           ~title:"Spark RSS Digest" ~ln:"en" ~opt_meta:[] output
       in
       List.fold_left2 write_article publication limited_articles processed
       |> Sparks_rss.Epub3.close_pub )

let () =
  try
    let output, jobs, webdriver_port, limit, feed_urls =
      parse_args (List.tl (Array.to_list Sys.argv))
    in
    run output jobs webdriver_port feed_urls limit
  with exn ->
    Printf.eprintf "sparks_rss: %s\n" (Printexc.to_string exn) ;
    exit 1
