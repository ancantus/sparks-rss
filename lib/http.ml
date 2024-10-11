open Lwt.Syntax
open Cohttp_lwt_unix
open Cohttp

let return_success content_type content =
  Lwt.map (fun r -> Some (r, content_type)) content

let fetch_url url =
  let* resp, body = Client.get (Uri.of_string url) in
  let content_type = Header.get (Response.headers resp) "Content-Type" in
  match Response.status resp with
  | `OK ->
      Cohttp_lwt.Body.to_string body |> return_success content_type
  | `Code 200 ->
      Cohttp_lwt.Body.to_string body |> return_success content_type
  | _ ->
      Lwt.return None
