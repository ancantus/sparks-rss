let is_lobsters_host = function
  | Some host ->
      String.lowercase_ascii host = "lobste.rs"
  | None ->
      false

let is_short_id text =
  String.length text = 6
  && String.for_all
       (function 'a' .. 'z' | '0' .. '9' -> true | _ -> false)
       (String.lowercase_ascii text)

let is_item_url uri =
  if not (is_lobsters_host (Uri.host uri)) then false
  else
    match String.split_on_char '/' (Uri.path uri) with
    | [""; "s"; short_id] -> is_short_id short_id
    | [""; "s"; short_id; slug] -> is_short_id short_id && slug <> ""
    | _ -> false

let text_of node = String.trim (String.concat "" (Soup.texts node))

let parse_comment ~reply_to node =
  match
    (Soup.select_one ".byline" node, Soup.select_one "time" node,
     Soup.select_one ".comment_text" node)
  with
  | Some byline, time, Some body ->
      let author =
        Soup.select "a" byline |> Soup.to_list
        |> List.find_map (fun link ->
               match Soup.attribute "href" link with
               | Some href when String.starts_with ~prefix:"/~" href ->
                   let username = text_of link in
                   if username = "" then None else Some username
               | _ -> None )
      in
      Option.map
        (fun author ->
          let age = Option.fold ~none:"" ~some:text_of time in
          {Comments.author= author; reply_to; age; text= Soup.to_string body} )
        author
  | _ ->
      None

let parse_comments html =
  let comment_nodes =
    Soup.parse html |> Soup.select "div" |> Soup.to_list
    |> List.filter (fun node ->
           match Soup.attribute "id" node with
           | Some id -> String.starts_with ~prefix:"c_" id
           | None -> false )
  in
  let author_by_id = Hashtbl.create (List.length comment_nodes) in
  let comment_id node =
    Option.bind (Soup.attribute "id" node) (fun id ->
        if String.starts_with ~prefix:"c_" id then Some id else None )
  in
  let rec parent_id node =
    match Soup.parent node with
    | None ->
        None
    | Some parent -> (
      match (Soup.name parent, Soup.attribute "class" parent) with
      | "ol", Some classes
        when List.mem "comments" (String.split_on_char ' ' classes) ->
          Option.bind (Soup.parent parent) (fun subtree ->
              Soup.children subtree |> Soup.elements |> Soup.to_list
              |> List.find_map comment_id )
      | _ ->
          parent_id parent )
  in
  List.fold_left
    (fun comments node ->
      let reply_to =
        Option.bind (parent_id node) (Hashtbl.find_opt author_by_id)
      in
      match parse_comment ~reply_to node with
      | None ->
          comments
      | Some comment ->
          Option.iter
            (fun id -> Hashtbl.replace author_by_id id comment.Comments.author)
            (comment_id node) ;
          comment :: comments )
    [] comment_nodes
  |> List.rev

let fetch_comments uri =
  match Ezcurl.get ~url:(Uri.to_string uri) () with
  | Ok response ->
      Some (parse_comments response.body)
  | Error _ ->
      None
