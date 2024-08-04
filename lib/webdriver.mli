val fetch_source : int -> Uri.t -> Soup.soup Soup.node option Lwt.t
(* [fetch_source port url] fetches a single web page's HTML source given a firefox webdriver at the given port. Firefox reader mode to get easily parsable pages. *)

val fetch_sources : int -> Uri.t list -> Soup.soup Soup.node list Lwt.t
(* [fetch_sources port urls] fetches multiple web pages' HTML source. Optimization of `fetch_source` to re-use connections to the webdriver *)
