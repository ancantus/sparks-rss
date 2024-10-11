open Soup.Infix
open Lwt.Syntax

let select_images node = Soup.select "img" node |> Soup.to_list

(* Image tags should always have a url: this throws if not the case *)
let get_image_url a = Soup.attribute "src" a |> Option.get

let get_image_urls = List.map get_image_url

let update_image_url = Soup.set_attribute "src"

let generate_image_name mimetype =
  let base_name = Uuid.uuid4 () in
  match mimetype with
  | "image/gif" ->
      Some ("images/" ^ base_name ^ ".gif")
  | "image/jpeg" ->
      Some ("images/" ^ base_name ^ ".jpeg")
  | "image/png" ->
      Some ("images/" ^ base_name ^ ".png")
  | "image/svg+xml" ->
      Some ("images/" ^ base_name ^ ".svg")
  | "image/webp" ->
      Some ("images/" ^ base_name ^ ".webp")
  | _ ->
      None

let download_image url =
  let* result = Http.fetch_url url in
  match result with
  | Some (content, Some mimetype_str) -> (
    match generate_image_name mimetype_str with
    | Some name ->
        Lwt.return (Some (name, mimetype_str, content))
    | None ->
        Lwt.return None )
  | _ ->
      Lwt.return None

let download_and_swap_images html_images =
  Lwt_list.map_p
    (fun html_img ->
      let* result = get_image_url html_img |> download_image in
      match result with
      | Some (path, mimetype, content) ->
          update_image_url path html_img ;
          Lwt.return (path, mimetype, content)
      | None ->
          Lwt.return ("images/unknown.jpg", "image/jpeg", "") )
    html_images

let parse_fx_reader (node : Soup.soup Soup.node) =
  let header = node $ ".header" in
  let content = node $ ".content" in
  let* images =
    (header |> select_images) @ (content |> select_images)
    |> download_and_swap_images
  in
  Lwt.return ((header |> Soup.to_string) ^ (content |> Soup.to_string), images)
