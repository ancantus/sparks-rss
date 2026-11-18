val is_item_url : Uri.t -> bool
(* [is_item_url uri] is [true] when [uri] points at a single Hacker News
   discussion item, i.e. a news.ycombinator.com [/item?id=<digits>] URL. *)

val item_id : Uri.t -> string option
(* [item_id uri] is the Hacker News item id of [uri] when [is_item_url uri].
   Useful for alternative comment sources such as the Algolia API. *)

type comment = Comments.t
(** One comment of a Hacker News thread. [text] is the raw HTML of the comment
    body; [age] is the site's own rendering of the comment time and may be
    empty. *)

val parse_comments : string -> comment list
(* [parse_comments html] extracts the comments rendered on a Hacker News item
   page in document order. Comments without a body or author, such as deleted
   ones, are skipped. *)

val fetch_comments : Uri.t -> comment list option
(* [fetch_comments uri] fetches the Hacker News item page [uri] and parses its
   comments. Only the first page of results is fetched: no pagination is
   followed, which naturally bounds the rendered thread. [None] when the fetch
   fails. *)
