module W = Webdriver_cohttp_lwt_unix

val action_fetch_reader : Uri.t -> Soup.soup Soup.node option W.cmd
(* [action_fetch_reader url] webdriver action to fetch a URL's HTML source using firefox reader *)

val action_fetch_source : Uri.t -> Soup.soup Soup.node option W.cmd
(* [action_fetch_reader url] webdriver action to fetch a URL's HTML source using firefox *)

val fetch_source :
     ?action:(Uri.t -> Soup.soup Soup.node option W.cmd)
  -> int
  -> Uri.t
  -> Soup.soup Soup.node option Lwt.t
(* [fetch_source ?action port url] fetches a single web page's HTML source given a firefox webdriver at the given port. Default action is firefox reader mode. *)

val fetch_sources :
     ?action:(Uri.t -> Soup.soup Soup.node option W.cmd)
  -> int
  -> Uri.t list
  -> Soup.soup Soup.node list Lwt.t
(* [fetch_sources port urls] fetches multiple web pages' HTML source. Optimization of `fetch_source` to re-use connections to the webdriver. *)
