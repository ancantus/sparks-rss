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

let make_articles (channel : Rss.channel) =
  let rec inner items articles =
    match items with
    | [] ->
        articles
    | head :: tail ->
        inner tail
          ( match make_article head with
          | None ->
              articles
          | Some a ->
              a :: articles )
  in
  inner (Rss.sort_items_by_date channel.ch_items) []

let load_channel f target =
  match f target with
  | c, [] ->
      make_articles c
  | _, errors ->
      failwith (List.fold_left ( ^ ) "" errors)

let from_file = load_channel Rss.channel_of_file

let from_str = load_channel Rss.channel_of_string

let from_url url =
  match Ezcurl.get ~url:(Uri.to_string url) () with
  | Ok c ->
      from_str c.body
  | Error (_, s) ->
      failwith s
