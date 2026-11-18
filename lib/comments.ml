type t =
  { author : string
  ; reply_to : string option
  ; age : string
  ; text : string }

module type SOURCE = sig
  val is_item_url : Uri.t -> bool
  val fetch_comments : Uri.t -> t list option
end
