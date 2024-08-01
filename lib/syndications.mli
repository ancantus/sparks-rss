(** Article from an RSS feed *)
type article =
  { title: string
  ; description: string option
  ; pubdate: Ptime.t option
  ; link: Uri.t
  ; comments: Uri.t option }

val from_file : string -> article list
(** [from_file string] loads a list of articles from an RSS feed on the filesystem *)

val from_str : string -> article list
(** [from_str string] loads a list of articles from an RSS formatted XML string *)

val from_url : Uri.t -> article list
(** [from_url] loads a list of articles from an RSS feed from a web URL *)
