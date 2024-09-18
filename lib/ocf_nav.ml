module H = Tyxml.Html
open Epub_types

(** The supported structural semantics of an epub doc as per https://www.w3.org/TR/epub-ssv-11/ *)
type structural_semantics =
  | Bodymatter
  | Cover
  | Frontmatter
  | Landmarks
  | TableOfContents

let build_html_attrib lang =
  Tyxml.Html.
    [ Tyxml.Html.Unsafe.uri_attrib "xmlns:epub" "http://www.idpf.org/2007/ops"
    ; a_lang lang
    ; a_xml_lang lang ]

let a_epub_type types =
  let to_string = function
    | Bodymatter ->
        "bodymatter"
    | Cover ->
        "cover"
    | Frontmatter ->
        "frontmatter"
    | Landmarks ->
        "landmarks"
    | TableOfContents ->
        "toc"
  in
  let is_empty = String.equal String.empty in
  List.fold_left
    (fun s t -> if is_empty s then to_string t else s ^ " " ^ to_string t)
    "" types
  |> H.Unsafe.string_attrib "epub:type"

let build_header ~title:t =
  H.(
    let t_elm = txt t |> title in
    head t_elm [meta ~a:[a_charset "utf-8"] ()] )

let build_toc ~title:t docs =
  let make_li path t = H.(li [a ~a:[a_href path] [txt t]]) in
  let make_list_elements l d =
    match d with Document ((_, _, p), t) -> make_li p t :: l | _ -> l
  in
  let toc_heading = H.(h1 [txt (t ^ ":")]) in
  H.(
    nav
      ~a:[a_epub_type [TableOfContents]; a_id "toc"]
      [toc_heading; List.fold_left make_list_elements [] docs |> ol] )

let build_landmarks ~title:t toc_path docs =
  let make_li path epub_type text =
    H.(li [a ~a:[a_href path; a_epub_type [epub_type]] [txt text]])
  in
  let rec bodymatter = function
    | [] ->
        []
    | Document ((_, _, p), _) :: _ ->
        [make_li p Bodymatter "Start Reading"]
    | _ :: tail ->
        bodymatter tail
  in
  let rec coverpage = function
    | [] ->
        []
    | CoverPage (_, _, p) :: _ ->
        [make_li p Cover "Cover"]
    | _ :: tail ->
        coverpage tail
  in
  let landmarks =
    coverpage docs
    @ [make_li toc_path TableOfContents t]
    @ (List.rev docs |> bodymatter)
    |> H.ol
  in
  H.(nav ~a:[a_epub_type [Landmarks]; a_id "landmarks"; a_hidden ()] [landmarks])

let build_body ~title:t toc_path docs =
  H.(
    body
      ~a:[a_epub_type [Frontmatter]]
      [build_toc ~title:t docs; build_landmarks ~title:t toc_path docs] )

let make_nav ~title:doc_title ~ln:lang docs =
  let toc_path = "nav.xhtml" in
  let doc =
    Tyxml.Html.(
      html ~a:(build_html_attrib lang)
        (build_header ~title:doc_title)
        (build_body ~title:doc_title toc_path docs) )
  in
  (toc_path, doc)
