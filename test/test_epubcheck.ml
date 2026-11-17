let quote = Filename.quote

let validator_command () =
  match Sys.getenv_opt "EPUBCHECK_JAR" with
  | Some jar ->
      Some ("java -jar " ^ quote jar)
  | None -> (
    match Sys.getenv_opt "EPUBCHECK" with
    | Some command ->
        Some (quote command)
    | None ->
        if Sys.command "command -v epubcheck >/dev/null 2>&1" = 0 then
          Some "epubcheck"
        else None )

let make_epub path =
  let pub =
    Sparks_rss.Epub3.open_out_pub
      ~unique_id:(Sparks_rss.Epub3.Uuid (Sparks_rss.Uuid.uuid4 ()))
      ~title:"EPUBCheck integration fixture" ~ln:"en" ~opt_meta:[] path
  in
  Sparks_rss.Epub3.save_xhtml_doc pub "Fixture article"
    (Sparks_rss.Spark.make_article_xhtml ~title:"Fixture article" ~summary:""
       ~text:"Validator fixture." ~images:[] )
  |> Sparks_rss.Epub3.close_pub

let () =
  match validator_command () with
  | None ->
      Printf.printf "EPUBCheck not installed; skipping integration check.\n%!"
  | Some command ->
      let path = Filename.temp_file "sparks-rss-epubcheck-" ".epub" in
      Fun.protect
        ~finally:(fun () -> if Sys.file_exists path then Sys.remove path)
        (fun () ->
          make_epub path ;
          let status = Sys.command (command ^ " " ^ quote path) in
          if status <> 0 then failwith "EPUBCheck rejected the generated EPUB" )
