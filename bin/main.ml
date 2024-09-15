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
(* open Sparks_rss.Epub_types *)
module MC = Sparks_rss.Ocf_container_f.Make (Tyxml_xml)
module PC = Xml_print.Make_typed_fmt (Tyxml_xml) (MC)
module MP = Sparks_rss.Ocf_package_f.Make (Tyxml_xml)
module PP = Xml_print.Make_typed_fmt (Tyxml_xml) (MP)

let opf_path = "content.opf"

let opf_mediatype = "application/oebps-package+xml"

let () =
  let container =
    MC.ocf_container
      ~a:[MC.a_version "1.0"]
      MC.(
        rootfiles
          (rootfile ~a:[a_fullpath opf_path; a_mediatype opf_mediatype] ())
          [] )
      None
  in
  let unique_identifier = "uuid_id" in
  let package_uuid = "urn:uuid:f7508264-d5c3-4508-8d84-7e52a1295cc2" in
  let package =
    MP.ocf_package
      ~a:[MP.a_unique_id unique_identifier; MP.a_version "3.0"]
      MP.(
        metadata
          ~a:
            [ a_namespace ("dc", "http://purl.org/dc/elements/1.1/")
            ; a_namespace ("dcterms", "http://purl.org/dc/terms/") ]
          (dc_identifier ~a:[a_id unique_identifier] (txt package_uuid))
          (dc_title (txt "Test RSS News Feed"))
          (dc_language (txt "en"))
          [] (* Other Dublin Core metadata *)
          [meta ~a:[a_property "dcterms:modified"] (txt "2024-09-13T03:20:08Z")]
          [] (* Legacy Metadata *)
          [] (* Links to metadata in other docs *) )
      MP.(
        manifest
          (manifest_item
             ~a:
               [ a_id "toc"
               ; a_href "toc.xhtml"
               ; a_mediatype `Xhtml
               ; a_properties ["nav"] ]
             () )
          [ manifest_item
              ~a:
                [ a_id "cover"
                ; a_href "cover.jpeg"
                ; a_mediatype `Jpeg
                ; a_properties ["cover-image"] ]
              ()
          ; manifest_item
              ~a:
                [a_id "id139"; a_href "index_split_000.html"; a_mediatype `Xhtml]
              ()
          ; manifest_item
              ~a:[a_id "id91"; a_href "images/00089.jpg"; a_mediatype `Jpeg]
              ()
          ; manifest_item
              ~a:
                [a_id "id138"; a_href "index_split_001.html"; a_mediatype `Xhtml]
              ()
          ; manifest_item
              ~a:[a_id "page_css"; a_href "pages_styles.css"; a_mediatype `Css]
              ()
          ; manifest_item
              ~a:[a_id "css"; a_href "stylesheet.css"; a_mediatype `Css]
              () ] )
      MP.(
        spine
          (itemref ~a:[a_idref "toc"] ())
          [itemref ~a:[a_idref "id139"] (); itemref ~a:[a_idref "id138"] ()] )
      None (* Legacy guide elements *)
      None (* Deprecated bindings element *)
      [] (* Collection elements *)
  in
  let container_s = Format.asprintf "%a" (PC.pp ~indent:true ()) container in
  let package_s = Format.asprintf "%a" (PP.pp ~indent:true ()) package in
  print_endline container_s ; print_endline package_s
