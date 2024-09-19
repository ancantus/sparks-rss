module Make (Xml : Xml_sigs.T) = struct
  include Ocf_xml.Make (Xml)

  (** Inteface with XML document *)
  type doc = [`Ncx] elt

  module Info = struct
    let content_type = "application/x-dtbncx+xml"

    let alternative_content_types = ["text/xml"; "application/xml"]

    let version = "1.0"

    let standard = "https://www.w3.org/TR/epub-33"

    let namespace = "http://www.daisy.org/z3986/2005/ncx/"

    let doctype = Xml_print.compose_doctype "xml" []

    let emptytags = ["meta"; "content"]
  end

  let doc_toelt x = x

  type page_type = Front | Normal | Special

  let to_list = function None -> [] | Some a -> [a]

  (* Attributes *)
  let a_version = a_string "version"

  let a_xml_lang = a_string "xml:lang"

  let a_lang = a_string "lang"

  let a_content = a_string "content"

  let a_name = a_string "name"

  let a_scheme = a_string "scheme"

  let a_id = a_string "id"

  let a_class = a_string "class"

  let a_src = a_string "src"

  let a_clipbegin = a_string "clipBegin"

  let a_clipend = a_string "clipEnd"

  let a_playorder = a_int "playOrder"

  let a_value = a_int "value"

  let a_pagetype t =
    let s =
      match t with
      | Front ->
          "front"
      | Normal ->
          "normal"
      | Special ->
          "special"
    in
    a_string "type" (W.return s)

  (* Elements *)
  let ncx ?(a = []) version head title authors navmap ?pagelist navlists =
    let rec to_wrapped_list output input =
      match input with
      | [] ->
          output
      | head :: tail ->
          to_wrapped_list (W.cons head output) tail
    in
    e_list "ncx" ~a:(version :: a)
      (to_wrapped_list
         W.(
           append authors
             (to_wrapped_list navlists (navmap :: to_list pagelist)) )
         [title; head] )

  let head = e_req_list ?a:None "head"

  let meta ?scheme name content =
    match scheme with
    | None ->
        e_empty "meta" ~a:[name; content] ()
    | Some s ->
        e_empty "meta" ~a:[name; content; s] ()

  let doc_title = e_req_list "docTitle"

  let doc_author = e_req_list "docAuthor"

  let text_content = e_single "text"

  let audio_content ?a:(opt_attrib = []) src cbegin cend =
    e_empty "audio" ~a:([src; cbegin; cend] @ opt_attrib) ()

  let image_content ?a:(opt_attrib = []) src =
    e_empty "image" ~a:(src :: opt_attrib) ()

  let navmap = e_req_list "navMap"

  let navpoint ?cls id order ?(children = W.nil ()) label content =
    let attribs = to_list cls @ [id; order] in
    e_list "navPoint" ~a:attribs W.(cons label (cons content children))

  let navlabel = e_req_list "navLabel"

  let navcontent ?id src = e_empty "content" ~a:(src :: to_list id) ()

  let pagelist = e_req_list "pageList"

  let pagetarget ?a:(opt_attrib = []) value order label ?(labels = W.nil ())
      content =
    e_list "pageTarget"
      ~a:([value; order] @ opt_attrib)
      W.(append (cons label labels) (singleton content))

  let navlist ?a ?(children = W.nil ()) label target =
    e_list "navList" ?a W.(cons label (cons target children))

  let navtarget ?a:(opt_attrib = []) value order label ?(labels = W.nil ())
      content =
    e_list "navTarget"
      ~a:([value; order] @ opt_attrib)
      W.(append (cons label labels) (singleton content))
end
