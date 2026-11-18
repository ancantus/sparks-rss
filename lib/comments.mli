type t =
  { author : string
  ; reply_to : string option
  ; age : string
  ; text : string }
(** A flattened aggregator comment. [reply_to] is the direct parent author's
    username when the comment is a reply. [text] contains raw comment-body
    HTML. *)

module type SOURCE = sig
  val is_item_url : Uri.t -> bool
  (** [true] when [uri] identifies a comment thread served by this source. *)

  val fetch_comments : Uri.t -> t list option
  (** Fetch and parse a thread. [None] indicates a fetch failure. *)
end
