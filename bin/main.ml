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
module M = Sparks_rss.Ocf_container_f.Make (Tyxml_xml)
module P = Xml_print.Make_typed_fmt (Tyxml_xml) (M)

let opf_path = "content.opf"

let opf_mediatype = "application/oebps-package+xml"

let () =
  let container =
    M.ocf_container
      ~a:[M.a_version "1.0"]
      (M.rootfiles
         (M.rootfile ~a:[M.a_fullpath opf_path; M.a_mediatype opf_mediatype] ())
         [] )
      None
  in
  let s = Format.asprintf "%a" (P.pp ()) container in
  print_endline s
