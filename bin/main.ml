let webdriver_port = 4444

(*let test_url =
  Uri.of_string "https://www.scrapingbee.com/blog/ocaml-web-scraping/"*)

let () =
  let articles =
    Sparks_rss.Syndications.from_file
      "/home/restep/projects/sparks_rss/resources/rss_short"
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
