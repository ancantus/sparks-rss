open Soup.Infix
open Lwt.Syntax

module HP = Xml_print.Make_typed_fmt (Tyxml_xml) (Tyxml.Html)

let select_images node = Soup.select "img" node |> Soup.to_list

let update_image_url = Soup.set_attribute "src"

let normalize_mimetype mimetype =
  mimetype |> String.split_on_char ';' |> List.hd |> String.trim
  |> String.lowercase_ascii

let image_extension mimetype =
  match normalize_mimetype mimetype with
  | "image/gif" ->
      Some ".gif"
  | "image/jpeg" | "image/jpg" ->
      Some ".jpg"
  | "image/png" ->
      Some ".png"
  | "image/svg+xml" ->
      Some ".svg"
  | "image/webp" ->
      Some ".webp"
  | _ ->
      None

let generate_image_name mimetype =
  Option.map
    (fun extension -> "images/" ^ Uuid.uuid4 () ^ extension)
    (image_extension mimetype)

let resolve_image_url ?base_url src =
  let uri = Uri.of_string src in
  match Uri.scheme uri with
  | Some ("http" | "https") ->
      Some (Uri.to_string uri)
  | _ ->
      Option.map
        (fun base -> Uri.resolve "https" (Uri.of_string base) uri |> Uri.to_string)
        base_url

let download_image url =
  let* result = Http.fetch_url url in
  match result with
  | Some (content, Some mimetype_str) -> (
    match (image_extension mimetype_str, generate_image_name mimetype_str) with
    | Some _, Some name ->
        let mimetype = normalize_mimetype mimetype_str in
        Lwt.return (Some (name, mimetype, content))
    | _ ->
        Lwt.return None )
  | _ ->
      Lwt.return None

let download_and_swap_images ?base_url html_images =
  Lwt.map (List.filter_map Fun.id)
    (Lwt_list.map_p
    (fun html_img ->
      match Soup.attribute "src" html_img with
      | None ->
          Soup.delete html_img ;
          Lwt.return None
      | Some src -> (
        match resolve_image_url ?base_url src with
        | None ->
            Soup.delete html_img ;
            Lwt.return None
        | Some url ->
            let* result = download_image url in
            match result with
            | Some (path, mimetype, content) ->
                update_image_url path html_img ;
                Lwt.return (Some (path, mimetype, content))
            | None ->
                Soup.delete html_img ;
                Lwt.return None ) )
    html_images)

let parse_fx_reader ?base_url (node : Soup.soup Soup.node) =
  let header = node $ ".header" in
  let content = node $ ".content" in
  let* images =
    (header |> select_images) @ (content |> select_images)
    |> download_and_swap_images ?base_url
  in
  Lwt.return ((header |> Soup.to_string) ^ (content |> Soup.to_string), images)

let normalize_text text =
  String.split_on_char ' ' (String.map (function '\n' | '\r' | '\t' -> ' ' | c -> c) text)
  |> List.filter (fun part -> part <> "")
  |> String.concat " "

let remove_noncontent_nodes soup =
  List.iter
    (fun selector -> List.iter Soup.delete (Soup.select selector soup |> Soup.to_list))
    ["script"; "style"; "noscript"]

let select_article_root soup =
  let rec first_match = function
    | [] ->
        None
    | selector :: tail -> (
      match Soup.select_one selector soup with
      | Some node ->
          Some node
      | None ->
          first_match tail )
  in
  first_match ["article"; "main"; "body"]

let extract_article_text html =
  let soup = Soup.parse html in
  remove_noncontent_nodes soup ;
  let text =
    match select_article_root soup with
    | Some node ->
        Soup.texts node
    | None ->
        Soup.texts soup
  in
  text |> String.concat " " |> normalize_text

let make_article_xhtml ~title ~summary ~text ~images =
  let module H = Tyxml.Html in
  let image_elements =
    List.map
      (fun (path, _, _) -> H.img ~src:path ~alt:"" ())
      images
  in
  let body =
    H.body
      ( [H.h1 [H.txt title]]
      @ (if summary = "" || summary = text then [] else [H.p [H.txt summary]])
      @ (if text = "" then [] else [H.p [H.txt text]])
      @ image_elements )
  in
  let doc =
    H.html
      ~a:
        [ H.Unsafe.string_attrib "xmlns" "http://www.w3.org/1999/xhtml"
        ; H.a_lang "en"
        ; H.a_xml_lang "en" ]
      (H.head (H.title (H.txt title)) [H.meta ~a:[H.a_charset "utf-8"] ()])
      body
  in
  Format.asprintf "%a" (HP.pp ~indent:true ()) doc

let extract_article ~title ~summary ~url html =
  let soup = Soup.parse html in
  remove_noncontent_nodes soup ;
  let text = extract_article_text html in
  let image_nodes =
    match select_article_root soup with
    | Some root ->
        select_images root
    | None ->
        select_images soup
  in
  let* images = download_and_swap_images ~base_url:url image_nodes in
  let text = if text = "" then summary else text in
  let xhtml = make_article_xhtml ~title ~summary ~text ~images in
  Lwt.return (xhtml, images)
