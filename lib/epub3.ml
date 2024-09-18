module C = Ocf_container_f.Make (Tyxml_xml)
module PC = Xml_print.Make_typed_fmt (Tyxml_xml) (C)
module P = Ocf_package_f.Make (Tyxml_xml)
module PP = Xml_print.Make_typed_fmt (Tyxml_xml) (P)
module HP = Xml_print.Make_typed_fmt (Tyxml_xml) (Tyxml.Html)
open Epub_types

type file_contents = string

type epub_metadata =
  | Title of string
  | UniqueIdentifier of string
  | Language of string
  | ModifiedDatetime of string

type publication =
  { archive: Zip.out_file
  ; primary_lang: string
  ; metadata: string * string * Tyxml_xml.elt
  ; content: content list
  ; doc_count: int }

let write_xml_like_file xml_pp pub path doc =
  let data = Format.asprintf "%a" xml_pp doc in
  Zip.add_entry data pub.archive path

let write_ocf_container = write_xml_like_file (PC.pp ~indent:false ())

let write_ocf_package = write_xml_like_file (PP.pp ~indent:true ())

let write_xhtml = write_xml_like_file (HP.pp ~indent:true ())

let ocf_container path =
  let opf_version = "1.0" in
  let opf_mediatype = "application/oebps-package+xml" in
  C.(
    ocf_container
      ~a:[a_version opf_version]
      (rootfiles
         (rootfile ~a:[a_fullpath path; a_mediatype opf_mediatype] ())
         [] )
      None )

(** Utility function for mapping items though a failable function and stripping back the results *)
let optional_map f items =
  let append_optional l o = match o with None -> l | Some i -> i :: l in
  let rec inner l items =
    match items with
    | [] ->
        l
    | i :: tail ->
        inner (f i |> append_optional l) tail
  in
  inner [] items

let dc_metadata = function
  | Title t ->
      Some P.(dc_title (txt t))
  | UniqueIdentifier i ->
      Some P.(dc_identifier (txt i))
  | Language l ->
      Some P.(dc_language (txt l))
  | _ ->
      None

let dc_meta_elements = optional_map dc_metadata

let package_metadata = function
  | ModifiedDatetime d ->
      Some P.(meta ~a:[a_property "dcterms:modified"] (txt d))
  | _ ->
      None

let package_meta_elements = optional_map package_metadata

let build_metadata uuid_id uuid title lang opt_meta =
  P.(
    metadata
      ~a:
        [ a_namespace ("dc", "http://purl.org/dc/elements/1.1/")
        ; a_namespace ("dcterms", "http://purl.org/dc/terms/") ]
      (dc_identifier ~a:[a_id uuid_id] (txt uuid))
      (dc_title (txt title))
      (dc_language (txt lang))
      (dc_meta_elements opt_meta)
      (package_meta_elements opt_meta)
      [] (* Legacy Metadata *)
      [] (* Links to metadata in other docs *) )

let add_content ?(rev = false) pub newc =
  { archive= pub.archive
  ; primary_lang= pub.primary_lang
  ; metadata= pub.metadata
  ; content= (if rev then pub.content @ [newc] else newc :: pub.content)
  ; doc_count= 1 + pub.doc_count }

let save_epub_content (pub : publication) path data =
  Zip.add_entry data pub.archive path

let save_xhtml_doc (pub : publication) title data =
  let doc_id = Printf.sprintf "id%05d" pub.doc_count in
  let doc_path = Printf.sprintf "index_count_%03d.xhtml" pub.doc_count in
  save_epub_content pub doc_path data ;
  add_content pub (Document ((`Xhtml, doc_id, doc_path), title))

let save_support_doc (pub : publication) doc_path mimetype data =
  let doc_id = Printf.sprintf "id%05d" pub.doc_count in
  save_epub_content pub doc_path data ;
  add_content pub (SupportDocument (mimetype, doc_id, doc_path))

let save_cover_image (pub : publication) doc_path mimetype data =
  let doc_id = Printf.sprintf "id%05d" pub.doc_count in
  let assert_image_mimetype = function
    | `Gif ->
        ()
    | `Jpeg ->
        ()
    | `Png ->
        ()
    | `Svg ->
        ()
    | `Webp ->
        ()
    | _ ->
        failwith "Expected image: found nonimage MIME type"
  in
  assert_image_mimetype mimetype ;
  save_epub_content pub doc_path data ;
  add_content pub (CoverImage (mimetype, doc_id, doc_path))

let build_manifest_item = function
  | Document ((mime, id, path), _) ->
      P.(manifest_item ~a:[a_id id; a_href path; a_mediatype mime] ())
  | SupportDocument (mime, id, path) ->
      P.(manifest_item ~a:[a_id id; a_href path; a_mediatype mime] ())
  | CoverImage (mime, id, path) ->
      P.(
        manifest_item
          ~a:
            [ a_id id
            ; a_href path
            ; a_mediatype mime
            ; a_properties ["cover-image"] ]
          () )
  | CoverPage (mime, id, path) ->
      P.(manifest_item ~a:[a_id id; a_href path; a_mediatype mime] ())
  | TableOfContents (mime, id, path) ->
      P.(manifest_item ~a:[a_id id; a_href path; a_mediatype mime] ())

let build_manifest docs =
  let items = List.map build_manifest_item docs in
  match items with
  | head :: tail ->
      P.manifest head tail
  | [] ->
      failwith
        "Unable to build manfiest: must supply at least one publication \
         document"

let build_spine_item = function
  | Document ((_, id, _), _) ->
      Some P.(itemref ~a:[a_idref id] ())
  | CoverPage (_, id, _) ->
      Some P.(itemref ~a:[a_idref id] ())
  | TableOfContents (_, id, _) ->
      Some P.(itemref ~a:[a_idref id] ())
  | _ ->
      None

let build_spine docs =
  let items = optional_map build_spine_item docs in
  match items with
  | head :: tail ->
      P.spine head tail
  | [] ->
      failwith "Unable to build spine: must have at least one xhtml document"

let make_ocf_package pub =
  let epub_version = "3.0" in
  let _, identifier_id, meta_elem = pub.metadata in
  P.(
    ocf_package
      ~a:[a_unique_id identifier_id; a_version epub_version]
      meta_elem
      (build_manifest pub.content)
      (build_spine pub.content) None (* Legacy guide elements *)
      None (* Deprecated bindings element *)
      [] (* Collection elements *) )

let make_epub_metadata uuid title lang opt_meta =
  let identifier_id = "uuid-id" in
  (identifier_id, build_metadata identifier_id uuid title lang opt_meta)

let make_meta_inf pub opf_path =
  let container_path = "/META-INF/container.xml" in
  ocf_container opf_path |> write_ocf_container pub container_path

let make_mimetype_file pub =
  Zip.add_entry "application/epub+zip" pub.archive "mimetype"

let make_toc pub =
  let path, nav_doc =
    Ocf_nav.make_nav ~title:"Table of Contents" ~ln:pub.primary_lang pub.content
  in
  write_xhtml pub path nav_doc ;
  TableOfContents (`Xhtml, "toc", path) |> add_content ~rev:true pub

let open_out_pub ~unique_id:uuid ~title ~ln:lang
    ~(opt_meta : epub_metadata list) dst =
  let package_path = "content.opf" in
  let id, meta_elem = make_epub_metadata uuid title lang opt_meta in
  let pub =
    { archive= Zip.open_out dst
    ; primary_lang= lang
    ; metadata= (package_path, id, meta_elem)
    ; content= []
    ; doc_count= 0 }
  in
  make_meta_inf pub package_path ;
  make_mimetype_file pub ;
  pub

let close_pub (pub : publication) =
  let package_path, _, _ = pub.metadata in
  make_toc pub
  |> (* Table of contents dynamically created from all the documents *)
  make_ocf_package
  |> write_ocf_package pub package_path ;
  Zip.close_out pub.archive
