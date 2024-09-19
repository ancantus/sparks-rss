module Make (Xml : Xml_sigs.T) = struct
  include Ocf_xml.Make (Xml)

  (** Inteface with XML document *)
  type doc = [`Ocf_Package] elt

  module Info = struct
    let content_type = "application/oebps-package+xml"

    let alternative_content_types = ["text/xml"; "application/xml"]

    let version = "1.0"

    let standard = "https://www.w3.org/TR/epub-33/#sec-package-doc"

    let namespace = "http://www.idpf.org/2007/opf"

    let doctype = Xml_print.compose_doctype "xml" []

    let emptytags = ["link"; "item"; "itemref"; "reference"]
  end

  let doc_toelt x = x

  (* Helper functions *)
  let dir_to_text d =
    (match d with `Ltr -> "ltr" | `Rtl -> "rtl" | `Auto -> "auto")
    |> Xml.W.return

  let mediatype_to_text m =
    ( match m with
    | `Gif ->
        "image/gif"
    | `Jpeg ->
        "image/jpeg"
    | `Png ->
        "image/gif"
    | `Svg ->
        "image/svg+xml"
    | `Webp ->
        "image/webp"
    | `Mpeg ->
        "audio/mpeg"
    | `Mp4 ->
        "audio/mp4"
    | `Ogg_Opus ->
        "audio/ogg; codecs=opus"
    | `Css ->
        "text/css"
    | `Tff ->
        "font/ttf"
    | `Sfnt ->
        "application/font-sfnt"
    | `Otf ->
        "font/otf"
    | `Eot ->
        "application/vnd.ms-opentype"
    | `Woff ->
        "font/woff"
    | `Woff2 ->
        "font/woff2"
    | `Xhtml ->
        "application/xhtml+xml"
    | `Javascript ->
        "application/javascript"
    | `Ncx ->
        "application/x-dtbncx+xml"
    | `Smil ->
        "application/smil+xml" )
    |> Xml.W.return

  let prefix_to_string = function key, url -> key ^ ": " ^ url

  let rec fold_wrapped_elements element_list elts =
    match elts with
    | [] ->
        element_list
    | None :: tail ->
        fold_wrapped_elements element_list tail
    | Some head :: tail ->
        fold_wrapped_elements (W.cons head element_list) tail

  (* Attributes *)
  let a_dir d = a_string "dir" (dir_to_text d)

  let a_id = a_string "id"

  let a_prefix p = List.map prefix_to_string p |> a_string_list "prefix"

  let a_lang = a_string "xml:lang"

  let a_unique_id = a_string "unique-identifier"

  let a_version = a_string "version"

  let a_mediatype m = a_string "media-type" (mediatype_to_text m)

  let a_namespace = function
    | prefix, url ->
        a_string ("xmlns:" ^ prefix) (W.return url)

  let a_property = a_string "property"

  let a_properties = a_string_list "properties"

  let a_href = a_string "href"

  let a_idref = a_string "idref"

  let a_toc = a_string "toc"

  (* Elements *)
  let ocf_package ?a metadata manifest spine guide bindings collection =
    let content =
      fold_wrapped_elements collection
        [bindings; guide; Some spine; Some manifest; Some metadata]
    in
    Xml.node ?a "package" content

  let metadata ?a id title lang dc_opt meta opf2_meta link =
    let content =
      fold_wrapped_elements
        (W.append link opf2_meta |> W.append meta |> W.append dc_opt)
        [Some lang; Some title; Some id]
    in
    Xml.node ?a "metadata" content

  let dc_identifier = e_single "dc:identifier"

  let dc_title = e_single "dc:title"

  let dc_language = e_single "dc:language"

  let meta = e_single "meta"

  let opf2_meta = e_single "meta"

  let metadata_link = e_empty "link"

  let manifest = e_req_list "manifest"

  let manifest_item = e_empty "item"

  let spine = e_req_list "spine"

  let itemref = e_empty "itemref"

  let guide = e_req_list "guide" ?a:None

  let reference = e_empty "reference"

  let collection ?a ?m collections links =
    let content = W.append links collections in
    match m with
    | None ->
        Xml.node ?a "metadata" content
    | Some metadata ->
        Xml.node ?a "metadata" (W.cons metadata content)
end
