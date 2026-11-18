let is_news_host host =
  host = "news.ycombinator.com"
  || String.ends_with ~suffix:".news.ycombinator.com" host

let item_path uri =
  let path = String.lowercase_ascii (Uri.path uri) in
  if String.length path > 1 && path.[String.length path - 1] = '/' then
    String.sub path 0 (String.length path - 1)
  else path

let digits_only text =
  String.length text > 0
  && String.for_all (function '0' .. '9' -> true | _ -> false) text

let item_id uri =
  match Option.map String.lowercase_ascii (Uri.host uri) with
  | Some host when is_news_host host && item_path uri = "/item" -> (
    match Uri.get_query_param uri "id" with
    | Some id when digits_only id ->
        Some id
    | _ ->
        None )
  | _ ->
      None

let is_item_url uri = item_id uri |> Option.is_some

type comment = Comments.t

let text_of node = String.trim (String.concat "" (Soup.texts node))

(* One comment is a [tr.athing.comtr] row: the author and age live in the
   comment header ([span.comhead], the author being the first [user?id=]
   link) and the body in a [div.commtext]. Rows missing either, such as
   deleted comments, are skipped. *)
let parse_comment row =
  match (Soup.select_one "span.comhead" row, Soup.select_one "div.commtext" row)
  with
  | Some header, Some body -> (
      let author =
        Soup.select "a" header |> Soup.to_list
        |> List.find_opt (fun link ->
               match Soup.attribute "href" link with
               | Some href ->
                   String.starts_with ~prefix:"user?id=" href
               | None ->
                   false )
        |> Option.map text_of
      in
      let age =
        match Soup.select_one "span.age" header with
        | Some age ->
            text_of age
        | None ->
            ""
      in
      match author with
      | Some author ->
          Some {Comments.author; age; text= Soup.to_string body}
      | None ->
          None )
  | _ ->
      None

let parse_comments html =
  Soup.parse html |> Soup.select "tr.athing.comtr" |> Soup.to_list
  |> List.filter_map parse_comment

(* The item page is fetched once and parsed whole. Hacker News currently
   serves every comment of the thread in that first response; if it ever
   paginates, only the first page is rendered. *)
let fetch_comments uri =
  match Ezcurl.get ~url:(Uri.to_string uri) () with
  | Ok c ->
      Some (parse_comments c.body)
  | Error _ ->
      None
