module W = Webdriver_cohttp_lwt_unix
module S = Soup
open W.Infix

let describe_error exn =
  match exn with
  | W.Webdriver error ->
      Some (W.Error.to_string error)
  | _ ->
      None

(* Helper function for returning an optional wrapped promise *)
let lwt_some promise = bind (fun a -> return (Some a)) promise

let rec wait ?(timeout = 10000) ?(step = 100) cmd =
  W.Error.catch
    (fun () -> lwt_some cmd)
    ~errors:[`no_such_element]
    (fun _ ->
      W.sleep step
      >>= fun () ->
      if timeout < step then return None else wait ~timeout:(timeout - step) cmd
      )

let webdriver_fetch_source wait_for_contents url =
  let* () = W.goto url in
  let* contents = wait_for_contents in
  match contents with
  | None ->
      return None
  | Some _ ->
      let* entire_doc = W.source in
      return (Some (S.parse entire_doc))

(* The WebDriver specification only allows navigating to http/https URLs, so
   navigating to an "about:reader?url=..." page is rejected by the browser's
   remote agent ("navigation ... is not allowed in this context"). Firefox
   reader mode is driven by @mozilla/readability, so we instead run the
   vendored copy of that exact engine inside the loaded page and harvest the
   parsed article document. Pages that Readability cannot parse return [None]
   and the caller should fall back to the raw page source. *)
let readability_parse_script =
  Readability_js.readability_js
  ^ "\n\
     var article = new Readability(document.cloneNode(true)).parse(); return \
     article.content;"

let parse_reader_article =
  W.execute readability_parse_script
  |> map (fun json ->
         match Yojson.Safe.Util.to_string_option json with
         | Some content when content <> "" ->
             Some (S.parse content)
         | _ ->
             None )

let wait_for time = wait ~timeout:time (W.find_first `css "#NOT-A-VALID-CLASS")

let action_fetch_source url =
  webdriver_fetch_source (wait_for 5000) (Uri.to_string url)

(* Article extraction via the vendored @mozilla/readability engine, the same
   one Firefox reader mode uses. *)
let action_fetch_reader url =
  let* () = W.goto (Uri.to_string url) in
  parse_reader_article

(* geckodriver only supports a single browser session at a time; concurrent
   fetches would race each other's navigation. *)
let fetch_mutex = Lwt_mutex.create ()

let fetch_source ?(action = action_fetch_reader) port url =
  let host = "http://127.0.0.1:" ^ Int.to_string port in
  Lwt_mutex.with_lock fetch_mutex (fun () ->
      W.run ~host W.Capabilities.firefox_headless (action url) )

let fetch_sources ?(action = action_fetch_reader) port urls =
  let actions = List.map (fun url -> action url) urls in
  let collapse_actions promised_sources cmd =
    map2
      (fun sources opt_src ->
        match opt_src with None -> sources | Some s -> s :: sources )
      promised_sources cmd
  in
  let collapsed_actions = List.fold_left collapse_actions (return []) actions in
  let host = "http://127.0.0.1:" ^ Int.to_string port in
  Lwt_mutex.with_lock fetch_mutex (fun () ->
      W.run ~host W.Capabilities.firefox_headless collapsed_actions )
