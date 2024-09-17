(*let test_url =
  Uri.of_string "https://www.scrapingbee.com/blog/ocaml-web-scraping/"*)
(*
let webdriver_port = 4444
let () =
  let articles =
    Sparks_rss.Syndications.from_file
      "/home/restep/projects/sparks-rss/resources/rss_short"
  in
  let links =
    List.map (fun (a : Sparks_rss.Syndications.article) -> a.link) articles
  in
  try
    let parsed_links =
      Lwt_main.run (Sparks_rss.Webdriver.fetch_sources webdriver_port links)
    in
    List.iter
      (fun n -> Sparks_rss.Spark.parse_fx_reader n |> print_endline)
      parsed_links
  with Webdriver_cohttp_lwt_unix.Webdriver e ->
    Printf.fprintf stderr "[FAIL] Webdriver error: %s\n%!"
      (Webdriver_cohttp_lwt_unix.Error.to_string e) ;
    Printexc.print_backtrace stderr ;
    Printf.fprintf stderr "\n%!"

*)
let src = "/home/restep/projects/sparks-rss/resources/frankenstein_epub/"

let docs =
  [ ("index_split_003.html", "tolower() with AVX-512 - Tony Finch")
  ; ("index_split_004.html", "ps aux without forking") ]

let support =
  [ ("images/00089.jpg", `Jpeg)
  ; ("page_styles.css", `Css)
  ; ("stylesheet.css", `Css) ]

let cover_img = ("cover.jpeg", `Jpeg)

let load_file path =
  let file = open_in_bin (src ^ path) in
  let s = really_input_string file (in_channel_length file) in
  close_in file ; s

let save_document pub d =
  let path, title = d in
  load_file path |> Sparks_rss.Epub3.save_xhtml_doc pub title

let save_support pub s =
  let path, mimetype = s in
  Sparks_rss.Epub3.save_support_doc pub path mimetype (load_file path)

let save_cover_image pub i =
  let path, mimetype = i in
  Sparks_rss.Epub3.save_cover_image pub path mimetype (load_file path)

let () =
  let pub_id = "urn:uuid:f7508264-d5c3-4508-8d84-7e52a1295cc2" in
  let pub_title = "Hacker News Test EPUB" in
  let fold_pub f list pub = List.fold_left f pub list in
  Sparks_rss.Epub3.open_out_pub ~unique_id:pub_id ~title:pub_title ~ln:"en"
    ~opt_meta:[ModifiedDatetime "2024-09-13T03:20:08Z"]
    "/tmp/test.epub"
  |> fold_pub save_document docs
  |> fold_pub save_support support
  |> (fun p -> save_cover_image p cover_img)
  |> Sparks_rss.Epub3.close_pub
