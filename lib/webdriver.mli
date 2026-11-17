module W = Webdriver_cohttp_lwt_unix

val describe_error : exn -> string option
(* [describe_error exn] is a human readable reason when [exn] originates from a
   WebDriver command failure, and [None] otherwise. *)

val action_fetch_reader : Uri.t -> Soup.soup Soup.node option W.cmd
(* [action_fetch_reader url] webdriver action to extract an article's HTML using
   the vendored @mozilla/readability engine (see vendor/readability), the same
   engine Firefox reader mode uses. Returns [None] for pages the engine cannot
   parse. *)

val action_fetch_source : Uri.t -> Soup.soup Soup.node option W.cmd
(* [action_fetch_source url] webdriver action to fetch a URL's HTML source with
   firefox, without reader mode. *)

module Pool : sig
  type t

  val create : size:int -> base_port:int -> t Lwt.t
  (* [create ~size ~base_port] is a pool of up to [size] webdriver server
     endpoints, for ports [base_port] upwards. A port whose server already
     answers the webdriver status endpoint is reused; otherwise geckodriver is
     launched on it (found on [PATH]). Ports that cannot serve a driver are
     skipped. Launched processes belong to the pool and must be released with
     {!shutdown}. An empty pool means no webdriver is available and callers
     should fall back to plain HTTP. *)

  val size : t -> int
  (* [size pool] is the number of usable drivers in [pool]. *)

  val fetch_source :
       ?action:(Uri.t -> Soup.soup Soup.node option W.cmd)
    -> t
    -> Uri.t
    -> Soup.soup Soup.node option Lwt.t
  (* [fetch_source ?action pool url] extracts [url] through the next driver of
     [pool] in round-robin order. Each geckodriver serves a single browser
     session at a time, so concurrent calls routed to the same driver are
     serialised. Returns [None] when the pool is empty or the action did not
     produce a document. *)

  val shutdown : t -> unit Lwt.t
  (* [shutdown pool] terminates and reaps the geckodriver processes the pool
     launched. Servers that were only reused are left running. *)
end
