type article =
  { title: string
  ; description: string option
  ; pubdate: Ptime.t option
  ; link: Uri.t
  ; comments: Uri.t option }

let make_article (i : Rss.item) =
  match i.item_link with
  | None ->
      None
  | Some link ->
      Some
        { title= Option.value i.item_title ~default:"UNKNOWN TITLE"
        ; description= i.item_desc
        ; pubdate= i.item_pubdate
        ; link
        ; comments= i.item_comments }

let make_articles since_time_opt (channel : Rss.channel) =
  let rec inner items articles =
    match items with
    | [] -> articles
    | head :: tail ->
      let article = make_article head in
      inner tail
        ( match article
          | None ->
              articles
          | Some a ->
              if not (is_too_old a.pubdate since_time_opt) then
                a :: articles
            else
              articles)
  in
  inner (Rss.sort_items_by_date channel.ch_items) []

let is_too_old (pubdate: Ptime.t option) (since_time_opt: Ptime.t option): bool =
  (* Return false if no since_time filter is specified *)
  match since_time_opt, pubdate with
  | None, _ -> false
  | Some since, Some pubdate -> 
      (* Article is too old if pubdate < since */
      Ptime.compare ~gt:since pubdate < 0
  | _, None -> false

(* Load channel from file and apply time filter *)
let load_channel f target =
  match f target with
  | c, [] ->
      make_articles Option.none c
  | _, errors ->
      failwith (List.fold_left (^) "" errors)

let from_file = load_channel Rss.channel_of_file

(* Load channel from string and apply time filter *)
let from_str = load_channel Rss.channel_of_string

(* Load channel from URL and apply time filter *)
let from_url url since_time_opt =
  match Ezcurl.get ~url:(Uri.to_string url) () with
  | Ok c ->
      from_str c.body since_time_opt
  | Error (_, s) ->
      failwith s
