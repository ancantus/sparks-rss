open Lwt.Syntax

let print_usage () =
  Printf.eprintf
    "Usage: sparks_rss [-o OUTPUT.epub] [-j ARTICLES] FEED_URL [FEED_URL ...]\n\
     Fetch RSS feeds, download their linked articles and create an EPUB.\n"

let usage_error () = print_usage () ; exit 2

let parse_args args =
  let rec loop output jobs urls = function
    | [] ->
        (output, jobs, List.rev urls)
    | ("-h" | "--help") :: _ ->
        print_usage () ; exit 0
    | ("-o" | "--output") :: path :: tail ->
        loop path jobs urls tail
    | ("-o" | "--output") :: [] ->
        usage_error ()
    | ("-j" | "--jobs") :: value :: tail ->
        let jobs = try int_of_string value with Failure _ -> usage_error () in
        if jobs < 1 then usage_error () ;
        loop output jobs urls tail
    | ("-j" | "--jobs") :: [] ->
        usage_error ()
    | url :: tail ->
        loop output jobs (url :: urls) tail
  in
  let output, jobs, urls = loop "sparks-rss.epub" 4 [] args in
  if urls = [] then usage_error () ;
  (output, jobs, urls)

let normalized_summary article =
  match article.Sparks_rss.Syndications.description with
  | None ->
      ""
  | Some html ->
      Sparks_rss.Spark.extract_article_text html

let fetch_article article =
  let title = article.Sparks_rss.Syndications.title in
  let summary = normalized_summary article in
  let url = Uri.to_string article.link in
  let stub kind =
    Lwt.return (Sparks_rss.Spark.make_stub_xhtml ~title ~kind url, [])
  in
  let fallback () =
    let xhtml =
      Sparks_rss.Spark.make_article_xhtml ~title ~summary ~text:summary
        ~images:[]
    in
    Lwt.return (xhtml, [])
  in
  Lwt.catch
    (fun () ->
      let* response = Sparks_rss.Http.fetch_url url in
      match response with
      | Some (content, Some mimetype) -> (
        match Sparks_rss.Spark.stub_kind_of_mimetype mimetype with
        | Some kind ->
            stub kind
        | None ->
            Sparks_rss.Spark.extract_article ~title ~summary ~url content )
      | Some (content, None) ->
          Sparks_rss.Spark.extract_article ~title ~summary ~url content
      | None ->
          fallback () )
    (fun _ -> fallback ())

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

let run output jobs feed_urls =
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
  if articles = [] then
    failwith "The supplied feeds contained no linked articles" ;
  let processed =
    Lwt_main.run
      (Sparks_rss.Bounded.map_p ~max_concurrent:jobs fetch_article articles)
  in
  let publication_id = Sparks_rss.Epub3.Uuid (Sparks_rss.Uuid.uuid4 ()) in
  let publication =
    Sparks_rss.Epub3.open_out_pub ~unique_id:publication_id
      ~title:"Spark RSS Digest" ~ln:"en" ~opt_meta:[] output
  in
  List.fold_left2 write_article publication articles processed
  |> Sparks_rss.Epub3.close_pub

let () =
  try
    let output, jobs, feed_urls = parse_args (List.tl (Array.to_list Sys.argv)) in
    run output jobs feed_urls
  with exn ->
    Printf.eprintf "sparks_rss: %s\n" (Printexc.to_string exn) ;
    exit 1
