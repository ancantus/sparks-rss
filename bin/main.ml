let () =
  let articles =
    Sparks_rss.Syndications.from_file
      "/home/restep/projects/sparks_rss/resources/rss"
  in
  List.iter
    (fun (a : Sparks_rss.Syndications.article) ->
      Uri.to_string a.link |> print_endline )
    articles
