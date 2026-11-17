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
   and the caller treats extraction as failed. *)
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

(* geckodriver only supports a single browser session at a time, so article
   fetches are run against a pool of driver endpoints, one mutex each, and
   handed out round-robin. The pool either reuses servers that already answer
   on the ports or launches geckodriver itself; the tool owns the processes it
   launched and reaps them on shutdown. *)
module Pool = struct
  open Lwt.Syntax

  type driver =
    { host : string
    ; lock : Lwt_mutex.t
        (* geckodriver serves one session at a time *)
    ; proc : Lwt_process.process_none option }

  type t = { drivers : driver array; mutable cursor : int }

  let ready port =
    let url = Printf.sprintf "http://127.0.0.1:%d/status" port in
    let* response = Http.fetch_url url in
    match response with
    | None ->
        Lwt.return false
    | Some (body, _) ->
        let value_ready json =
          let open Yojson.Safe.Util in
          try member "value" json |> member "ready" |> to_bool with _ -> false
        in
        (try
           Lwt.return (value_ready (Yojson.Safe.from_string body))
         with _ ->
           Lwt.return false )

  let find_binary () =
    match Sys.getenv_opt "PATH" with
    | None ->
        None
    | Some path ->
        List.find_opt
          (fun dir -> Sys.file_exists (Filename.concat dir "geckodriver"))
          (String.split_on_char ':' path)
        |> Option.map (fun dir -> Filename.concat dir "geckodriver")

  (* Launch geckodriver on [port] and wait for it to answer its status
     endpoint. [None] when the binary is missing or the server does not come
     up (e.g. the port is already taken by another process). *)
  let spawn ?(timeout_ms = 10_000) port =
    match find_binary () with
    | None ->
        Lwt.return None
    | Some binary -> (
        let proc =
          Lwt_process.open_process_none
            ~stdout:`Dev_null
            ~stderr:`Dev_null
            ("geckodriver", [| binary; "--port"; Int.to_string port |])
        in
        let rec poll remaining =
          match proc#state with
          | Lwt_process.Exited _ ->
              Lwt.return false
          | Lwt_process.Running when remaining <= 0 ->
              Lwt.return false
          | Lwt_process.Running -> (
              let* up = ready port in
              if up then Lwt.return true
              else
                let* () = Lwt_unix.sleep 0.25 in
                poll (remaining - 250) )
        in
        let* started = poll timeout_ms in
        match started with
        | true ->
            Lwt.return
              (Some
                 { host= "http://127.0.0.1:" ^ Int.to_string port
                 ; lock= Lwt_mutex.create ()
                 ; proc= Some proc } )
        | false ->
            proc#kill Sys.sigkill ;
            let* _ = proc#close in
            Lwt.return None )

  let report message =
    Printf.eprintf "[sparks_rss] %s\n%!" message

  let create ~size ~base_port =
    let rec setup index accepted =
      if index >= size then Lwt.return accepted
      else
        let port = base_port + index in
        let* already_up = ready port in
        if already_up then (
          report (Printf.sprintf "Reusing webdriver server on port %d" port) ;
          setup (index + 1)
            (Array.append accepted
               [| { host= "http://127.0.0.1:" ^ Int.to_string port
                  ; lock= Lwt_mutex.create ()
                  ; proc= None } |] ) )
        else
          let* launched = spawn port in
          match launched with
          | Some driver ->
              report (Printf.sprintf "Launched geckodriver on port %d" port) ;
              setup (index + 1) (Array.append accepted [| driver |])
          | None ->
              report
                (Printf.sprintf
                   "Could not use a webdriver on port %d; skipping it" port ) ;
              setup (index + 1) accepted
    in
    let* drivers = setup 0 [||] in
    if Array.length drivers = 0 then
      report "No WebDriver available; article extraction will fail" ;
    Lwt.return { drivers; cursor= 0 }

  let size pool = Array.length pool.drivers

  let fetch_source ?(action = action_fetch_reader) pool url =
    if Array.length pool.drivers = 0 then Lwt.return None
    else
      let driver = pool.drivers.(pool.cursor mod Array.length pool.drivers) in
      pool.cursor <- pool.cursor + 1 ;
      Lwt_mutex.with_lock driver.lock (fun () ->
          W.run ~host:driver.host W.Capabilities.firefox_headless (action url) )

  let reap proc =
    (match proc#state with
    | Lwt_process.Running ->
        proc#kill Sys.sigterm
    | Lwt_process.Exited _ ->
        () ) ;
    let rec wait_for_exit remaining =
      match proc#state with
      | Lwt_process.Exited _ ->
          Lwt.return ()
      | Lwt_process.Running when remaining <= 0 ->
          proc#kill Sys.sigkill ;
          Lwt.return ()
      | Lwt_process.Running ->
          let* () = Lwt_unix.sleep 0.25 in
          wait_for_exit (remaining - 250)
    in
    let* () = wait_for_exit 5_000 in
    let* _ = proc#close in
    Lwt.return ()

  let shutdown pool =
    let spawned =
      Array.to_list pool.drivers |> List.filter_map (fun d -> d.proc)
    in
    match spawned with [] -> Lwt.return () | procs -> Lwt_list.iter_s reap procs
end
