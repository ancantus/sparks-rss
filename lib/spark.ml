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
        (fun base ->
          Uri.resolve "https" (Uri.of_string base) uri |> Uri.to_string )
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
    (Lwt_list.map_s
       (fun html_img ->
         match Soup.attribute "src" html_img with
         | None ->
             Soup.delete html_img ; Lwt.return None
         | Some src -> (
           match resolve_image_url ?base_url src with
           | None ->
               Soup.delete html_img ; Lwt.return None
           | Some url -> (
               let* result = download_image url in
               match result with
               | Some (path, mimetype, content) ->
                   update_image_url path html_img ;
                   Lwt.return (Some (path, mimetype, content))
               | None ->
                   Soup.delete html_img ; Lwt.return None ) ) )
       html_images )

let parse_fx_reader ?base_url (node : Soup.soup Soup.node) =
  let header = node $ ".header" in
  let content = node $ ".content" in
  let* images =
    (header |> select_images) @ (content |> select_images)
    |> download_and_swap_images ?base_url
  in
  Lwt.return ((header |> Soup.to_string) ^ (content |> Soup.to_string), images)

let normalize_text text =
  text |> String.to_seq
  |> Seq.filter (fun c ->
         let code = Char.code c in
         code = 0x09 || code = 0x0A || code = 0x0D || code >= 0x20 )
  |> String.of_seq
  |> String.map (function '\n' | '\r' | '\t' -> ' ' | c -> c)
  |> String.split_on_char ' '
  |> List.filter (fun part -> part <> "")
  |> String.concat " "

let remove_noncontent_nodes soup =
  List.iter
    (fun selector ->
      List.iter Soup.delete (Soup.select selector soup |> Soup.to_list) )
    [ "script"
    ; "style"
    ; "noscript"
    ; (* Unsupported embedded media: their fallback text would otherwise leak
         into the extracted article. Linked media are stubbed out instead. *)
      "video"
    ; "audio"
    ; "embed"
    ; "iframe"
    ; "object" ]

(* Unsupported content is replaced by a placeholder page for the time being. *)
type stub_kind = Pdf | Video

let is_pdf_uri uri =
  String.ends_with ~suffix:".pdf" (String.lowercase_ascii (Uri.path uri))

let video_file_extensions = [".mp4"; ".webm"; ".m4v"; ".mov"; ".ogv"; ".avi"]

let video_hosts = ["youtube.com"; "youtu.be"; "vimeo.com"; "dailymotion.com"]

let is_video_uri uri =
  let path = String.lowercase_ascii (Uri.path uri) in
  let host = Option.map String.lowercase_ascii (Uri.host uri) in
  List.exists
    (fun ext -> String.ends_with ~suffix:ext path)
    video_file_extensions
  ||
  match host with
  | None ->
      false
  | Some host ->
      List.exists
        (fun known ->
          host = known || String.ends_with ~suffix:("." ^ known) host )
        video_hosts

let stub_kind_of_uri uri =
  if is_pdf_uri uri then Some Pdf
  else if is_video_uri uri then Some Video
  else None

let stub_kind_of_mimetype mimetype =
  match normalize_mimetype mimetype with
  | "application/pdf" ->
      Some Pdf
  | mimetype ->
      if String.length mimetype >= 6 && String.sub mimetype 0 6 = "video/" then
        Some Video
      else None

let reader_page_contents soup =
  (* Firefox reader mode embeds the parsed article in a readability content
     node; fall back to the whole document if it cannot be found. *)
  match Soup.select_one "[id^=readability-page-]" soup with
  | Some node ->
      Soup.to_string node
  | None ->
      Soup.to_string soup

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

let normalize_preformatted_text text =
  let buffer = Buffer.create (String.length text) in
  let rec normalize_newlines i =
    if i < String.length text then
      match text.[i] with
      | '\r' ->
          Buffer.add_char buffer '\n' ;
          normalize_newlines
            (if i + 1 < String.length text && text.[i + 1] = '\n' then i + 2
             else i + 1)
      | ch ->
          Buffer.add_char buffer ch ;
          normalize_newlines (i + 1)
  in
  normalize_newlines 0 ;
  let text = Buffer.contents buffer in
  let is_blank line = String.trim line = "" in
  let lines = String.split_on_char '\n' text in
  let rec drop_blank_start = function
    | line :: rest when is_blank line ->
        drop_blank_start rest
    | lines ->
        lines
  in
  let lines = drop_blank_start lines |> List.rev |> drop_blank_start |> List.rev in
  let leading_space line =
    let rec loop i =
      if i < String.length line && (line.[i] = ' ' || line.[i] = '\t') then
        loop (i + 1)
      else String.sub line 0 i
    in
    loop 0
  in
  let common_prefix left right =
    let rec loop i =
      if i < String.length left && i < String.length right
         && left.[i] = right.[i]
      then loop (i + 1)
      else String.sub left 0 i
    in
    loop 0
  in
  let common_indent =
    lines |> List.filter (fun line -> not (is_blank line))
    |> List.map leading_space
    |> function
    | [] ->
        ""
    | first :: rest ->
        List.fold_left common_prefix first rest
  in
  let strip_prefix line =
    if String.starts_with ~prefix:common_indent line then
      String.sub line (String.length common_indent)
        (String.length line - String.length common_indent)
    else line
  in
  let trim_right line =
    let rec last_nonspace i =
      if i >= 0 && (line.[i] = ' ' || line.[i] = '\t') then
        last_nonspace (i - 1)
      else i
    in
    String.sub line 0 (last_nonspace (String.length line - 1) + 1)
  in
  lines
  |> List.map (fun line ->
         if is_blank line then "" else line |> strip_prefix |> trim_right )
  |> String.concat "\n"

let soup_to_xhtml node =
  let module H = Tyxml.Html in
  let allowed_tags =
    [ "a"; "abbr"; "article"; "b"; "blockquote"; "br"; "caption"
    ; "code"; "dd"; "del"; "div"; "dl"; "dt"; "em"; "figcaption"
    ; "figure"; "h1"; "h2"; "h3"; "h4"; "h5"; "h6"; "hr"; "i"
    ; "img"; "ins"; "kbd"; "li"; "mark"; "ol"; "p"; "pre"; "q"
    ; "s"; "samp"; "section"; "small"; "span"; "strong"; "sub"
    ; "sup"; "table"; "tbody"; "td"; "th"; "thead"; "tfoot"; "time"
    ; "tr"; "u"; "ul"; "var" ]
  in
  let void_tags = ["br"; "hr"; "img"] in
  let safe_attributes =
    [ "alt"; "class"; "cite"; "colspan"; "datetime"; "dir"; "height"
    ; "href"; "id"; "lang"; "rowspan"; "src"; "start"; "title"; "width"
    ; "epub:type" ]
  in
  let attributes element =
    Soup.fold_attributes
      (fun attrs name value ->
        let name = String.lowercase_ascii name in
        if List.mem name safe_attributes then
          H.Unsafe.string_attrib name value :: attrs
        else attrs )
      [] element
  in
  let rec convert node =
    if Soup.is_text node then
      match Soup.leaf_text node with Some text -> [H.txt text] | None -> []
    else
      match Soup.element node with
      | None ->
          Soup.children node |> Soup.to_list |> List.concat_map convert
      | Some element ->
          let name = Soup.name element |> String.lowercase_ascii in
          if name = "pre" then
            let code_text =
              Soup.texts (Soup.coerce element) |> String.concat ""
              |> normalize_preformatted_text
            in
            let code_attrs =
              match Soup.select_one "code" element with
              | Some code -> attributes code
              | None -> []
            in
            let pre_style =
              H.Unsafe.string_attrib "style"
                "white-space: pre-wrap; overflow-wrap: anywhere; font-size: 0.8em; line-height: 1.2; margin: 0.5em 0"
            in
            [ H.Unsafe.node "pre" ~a:(attributes element @ [pre_style])
                [H.Unsafe.node "code" ~a:code_attrs [H.txt code_text]] ]
          else
            let children =
              Soup.children element |> Soup.to_list |> List.concat_map convert
            in
            if not (List.mem name allowed_tags) then children
          else if List.mem name void_tags then
            [H.Unsafe.leaf name ~a:(attributes element) ()]
          else [H.Unsafe.node name ~a:(attributes element) children]
  in
  convert node

let make_article_xhtml_with_body ~body_content ~title ~summary ~text ~images =
  let module H = Tyxml.Html in
  let image_elements =
    List.map (fun (path, _, _) -> H.img ~src:path ~alt:"" ()) images
  in
  let body =
    H.body
      ( [H.h1 [H.txt title]]
      @ (if summary = "" || summary = text then [] else [H.p [H.txt summary]])
      @ ( match body_content with
        | Some content -> content
        | None -> if text = "" then [] else [H.p [H.txt text]] )
      @ image_elements )
  in
  let doc =
    H.html
      ~a:
        [ H.Unsafe.string_attrib "xmlns" "http://www.w3.org/1999/xhtml"
        ; H.Unsafe.string_attrib "xmlns:epub" "http://www.idpf.org/2007/ops"
        ; H.a_lang "en"
        ; H.a_xml_lang "en" ]
      (H.head (H.title (H.txt title)) [H.meta ~a:[H.a_charset "utf-8"] ()])
      body
  in
  (* Pretty-print indentation becomes literal content inside [<pre>] blocks. *)
  Format.asprintf "%a" (HP.pp ~indent:false ()) doc

let make_article_xhtml ~title ~summary ~text ~images =
  make_article_xhtml_with_body ~body_content:None ~title ~summary ~text ~images

let make_stub_xhtml ~title ~kind url =
  let description =
    match kind with Pdf -> "PDF document" | Video -> "video"
  in
  make_article_xhtml ~title ~summary:""
    ~text:
      (Printf.sprintf
         "This article is a %s, which cannot be embedded in this edition yet. \
          It is available at: %s"
         description url )
    ~images:[]

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
  let body_content =
    match select_article_root soup with
    | Some root ->
        Some (soup_to_xhtml (Soup.coerce root))
    | None ->
        Some (soup_to_xhtml (Soup.coerce soup))
  in
  let xhtml =
    make_article_xhtml_with_body ~body_content ~title
      ~summary ~text ~images
  in
  Lwt.return (xhtml, images)
