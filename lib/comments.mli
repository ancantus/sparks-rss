type t = { author : string; age : string; text : string }
(** A flattened aggregator comment. [text] contains raw comment-body HTML. *)

module type SOURCE = sig
  val is_item_url : Uri.t -> bool
  (** [true] when [uri] identifies a comment thread served by this source. *)

  val fetch_comments : Uri.t -> t list option
  (** Fetch and parse a thread. [None] indicates a fetch failure. *)
end
