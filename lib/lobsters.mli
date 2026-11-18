val is_item_url : Uri.t -> bool
(** [true] for Lobsters story URLs of the form [/s/<short_id>[/<slug>]]. *)

val parse_comments : string -> Comments.t list
(** Extract visible comments from a Lobsters story page in document order. *)

val fetch_comments : Uri.t -> Comments.t list option
(** Fetch and parse a Lobsters story page; [None] indicates a fetch failure. *)
