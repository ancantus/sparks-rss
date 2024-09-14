module Make (Xml : Xml_sigs.T) = struct
  include Ocf_xml.Make (Xml)

  (** Inteface with XML document *)
  type doc = [`Ocf_Container] elt

  module Info = struct
    let content_type = "text/xml"

    let alternative_content_types = ["application/xml"]

    let version = "1.0"

    let standard = "https://www.w3.org/TR/epub-33"

    let namespace = "urn:oasis:names:tc:opendocument:xmlns:container"

    let doctype = Xml_print.compose_doctype "xml" []

    let emptytags = ["rootfile"; "link"]
  end

  let doc_toelt x = x

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
end
