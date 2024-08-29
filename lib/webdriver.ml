module W = Webdriver_cohttp_lwt_unix
module S = Soup
open W.Infix

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

let reader_url url = "about:reader?url=" ^ Uri.to_string url

let reader_contents =
  W.find_first `xpath "//div[contains(@id, 'readability-page-')]"

let action_fetch_reader url =
  webdriver_fetch_source (wait reader_contents) (reader_url url)

let wait_for time = wait ~timeout:time (W.find_first `css "#NOT-A-VALID-CLASS")

let action_fetch_source url =
  webdriver_fetch_source (wait_for 5000) (Uri.to_string url)

let fetch_source ?(action = action_fetch_reader) port url =
  let host = "http://127.0.0.1:" ^ Int.to_string port in
  W.run ~host W.Capabilities.firefox_headless (action url)

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
  W.run ~host W.Capabilities.firefox_headless collapsed_actions
