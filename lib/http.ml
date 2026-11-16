open Lwt.Syntax
open Cohttp_lwt_unix
open Cohttp

let return_success content_type content =
  Lwt.map (fun r -> Some (r, content_type)) content

let rec get ?(redirects = 5) uri =
  let* resp, body = Client.get uri in
  let status = Response.status resp in
  let code = Cohttp.Code.code_of_status status in
  let location = Header.get (Response.headers resp) "Location" in
  if redirects > 0 && List.mem code [301; 302; 303; 307; 308] then
    match location with
    | Some next ->
        let* () = Cohttp_lwt.Body.drain_body body in
        get ~redirects:(redirects - 1)
          (Uri.resolve "https" uri (Uri.of_string next))
    | None ->
        Lwt.return (resp, body)
  else Lwt.return (resp, body)

let fetch_url url =
  Lwt.catch
    (fun () ->
      let* resp, body = get (Uri.of_string url) in
      let content_type = Header.get (Response.headers resp) "Content-Type" in
      match Response.status resp with
      | `OK ->
          Cohttp_lwt.Body.to_string body |> return_success content_type
      | _ ->
          let* () = Cohttp_lwt.Body.drain_body body in
          Lwt.return None )
    (fun _ -> Lwt.return None)
