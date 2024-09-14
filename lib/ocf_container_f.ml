module Make (Xml : Xml_sigs.T) = struct
  module Xml = Xml
  module W = Xml.W

  type 'a elt = Xml.elt

  type 'a attrib = Xml.attrib

  module Info = struct
    let content_type = "text/xml"

    let alternative_content_types = ["application/xml"]

    let version = "1.0"

    let standard = "https://www.w3.org/TR/epub-33"

    let namespace = "urn:oasis:names:tc:opendocument:xmlns:container"

    let doctype = Xml_print.compose_doctype "xml" []

    let emptytags = ["rootfile"; "link"]
  end

  type 'a wrap = 'a W.t

  type 'a wrap_list = 'a W.tlist

  (* internal building blocks *)
  let a_string = Xml.string_attrib

  type ('a, 'b) e_empty = ?a:'a attrib list -> unit -> 'b elt

  type ('a, 'b, 'c) e_single = ?a:'a attrib list -> 'b elt wrap -> 'c elt

  type ('a, 'b, 'c) e_list = ?a:'a attrib list -> 'b elt wrap_list -> 'c elt

  type ('a, 'b, 'c) e_req_list =
    ?a:'a attrib list -> 'b elt wrap -> 'b elt wrap_list -> 'c elt

  let e_empty tag ?a () = Xml.leaf ?a tag

  let _e_single tag ?a elt = Xml.node ?a tag (W.singleton elt)

  let _e_list tag ?a elt_list = Xml.node ?a tag elt_list

  let e_req_list tag ?a elt elt_list = Xml.node ?a tag (W.cons elt elt_list)

  (* Attributes *)
  let a_fullpath = a_string "full-path"

  let a_mediatype = a_string "media-type"

  let a_version = a_string "version"

  (* Elements *)
  let ocf_container ?a rootfiles links =
    let content =
      match links with
      | None ->
          W.singleton rootfiles
      | Some l ->
          W.cons rootfiles l
    in
    Xml.node ?a "container" content

  let rootfiles = e_req_list "rootfiles" ?a:None

  let rootfile = e_empty "rootfile"

  let links = e_req_list "links" ?a:None

  let link = e_empty "link"

  (*********************************)

  (** Inteface with XML document *)
  type doc = [`Ocf_Container] elt

  let doc_toelt x = x

  let toelt x = x
end
