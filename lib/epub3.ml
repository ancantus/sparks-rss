module C = Ocf_container_f.Make (Tyxml_xml)
module PC = Xml_print.Make_typed_fmt (Tyxml_xml) (C)
module P = Ocf_package_f.Make (Tyxml_xml)
module PP = Xml_print.Make_typed_fmt (Tyxml_xml) (P)
open Epub_types

type title = string

type file_contents = string

type epub_metadata =
  | Title of string
  | UniqueIdentifier of string
  | Language of string
  | ModifiedDatetime of string

type base_content = core_mediatype * string * string

type content =
  | Document of base_content * string
  | SupportDocument of base_content
  | CoverImage of base_content

type publication =
  { path: string
  ; metadata: string * string * Tyxml_xml.elt
  ; content: content list
  ; doc_count: int }

(** Replacement for Filesystem.temp_dir that's only in >5.0 OCAML *)
let temp_dir ?temp_dir ?perms prefix suffix =
  let base_dir =
    Option.value temp_dir ~default:(Filename.get_temp_dir_name ())
  in
  Random.self_init () ;
  let rand_str = Random.int 99999 |> Int.to_string in
  let path = base_dir ^ "/" ^ prefix ^ rand_str ^ suffix ^ "/" in
  Sys.mkdir path (Option.value ~default:0o777 perms) ;
  path

let write_xml_like_file xml_pp path doc =
  let file = open_out path in
  let fmt = Format.formatter_of_out_channel file in
  xml_pp fmt doc ; close_out file

let write_ocf_container = write_xml_like_file (PC.pp ~indent:true ())

let write_ocf_package = write_xml_like_file (PP.pp ~indent:true ())

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

let add_content pub newc =
  { path= pub.path
  ; metadata= pub.metadata
  ; content= newc :: pub.content
  ; doc_count= 1 + pub.doc_count }

let rec prepare_parent_dirs root path =
  let rec path_join s segments =
    match segments with
    | [] ->
        s
    | head :: [] ->
        s ^ head
    | head :: tail ->
        path_join (s ^ head ^ "/") tail
  in
  let mkdir path =
    if Sys.file_exists path then () else Sys.mkdir path 0o777
  in
  match String.split_on_char '/' path with
  | [] ->
      ()
  | _filename :: [] ->
      ()
  | dir :: tail ->
      let next_root = root ^ dir ^ "/" in
      mkdir next_root ;
      prepare_parent_dirs next_root (path_join "" tail)

let save_epub_content (pub : publication) path data =
  prepare_parent_dirs pub.path path ;
  let file = open_out_bin (pub.path ^ path) in
  try output_string file data ; close_out file
  with e -> close_out file ; raise e

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

let make_meta_inf root opf_path =
  let meta_inf_path = root ^ "/META-INF/" in
  Sys.mkdir meta_inf_path 0o777 ;
  ocf_container opf_path |> write_ocf_container (meta_inf_path ^ "container.xml")

let open_out_pub uuid title lang (opt_meta : epub_metadata list) =
  let epub_root = temp_dir ".epub3" uuid in
  let package_path = "content.opf" in
  make_meta_inf epub_root package_path ;
  let id, meta_elem = make_epub_metadata uuid title lang opt_meta in
  { path= epub_root
  ; metadata= (package_path, id, meta_elem)
  ; content= []
  ; doc_count= 0 }

let close_pub (pub : publication) =
  let package_path, _, _ = pub.metadata in
  make_ocf_package pub |> write_ocf_package (pub.path ^ package_path)
