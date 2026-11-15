module C = Ocf_container_f.Make (Tyxml_xml)
module PC = Xml_print.Make_typed_fmt (Tyxml_xml) (C)
module P = Ocf_package_f.Make (Tyxml_xml)
module PP = Xml_print.Make_typed_fmt (Tyxml_xml) (P)
module N = Ocf_ncx_f.Make (Tyxml_xml)
module NP = Xml_print.Make_typed_fmt (Tyxml_xml) (N)
module HP = Xml_print.Make_typed_fmt (Tyxml_xml) (Tyxml.Html)
open Epub_types

type file_contents = string

type epub_metadata =
  | Title of string
  | UniqueIdentifier of string
  | Language of string
  | ModifiedDatetime of string

type unique_id =
  | Uuid of string
  | Doi of string
  | Isbn of string
  | Isbn10 of string
  | Isbn13 of string

type pub_metadata =
  { title: string
  ; unique_id: unique_id
  ; primary_lang: string
  ; opt_meta: epub_metadata list
  ; package_path: string }

type publication =
  { archive: Zip.out_file
  ; output_path: string
  ; metadata: pub_metadata
  ; content: content list
  ; doc_count: int }

let write_xml_like_file xml_pp pub path doc =
  let data = Format.asprintf "%a" xml_pp doc in
  Zip.add_entry data pub.archive path

let write_ocf_container = write_xml_like_file (PC.pp ~indent:false ())

let write_ocf_package = write_xml_like_file (PP.pp ~indent:true ())

let write_ncx = write_xml_like_file (NP.pp ~indent:true ())

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

let rec make_id_txt = function
  | Uuid txt ->
      "urn:uuid:" ^ txt
  | Doi txt ->
      "urn:doi:" ^ txt
  | Isbn txt ->
      "urn:isbn:" ^ txt
  | Isbn10 txt ->
      Isbn txt |> make_id_txt
  | Isbn13 txt ->
      Isbn txt |> make_id_txt

let build_metadata identifier_id identifier title lang opt_meta =
  let is_digit = function '0' .. '9' -> true | _ -> false in
  let count_digits =
    String.fold_left (fun i c -> if is_digit c then i + 1 else i) 0
  in
  let rec make_id_meta id =
    match id with
    | Uuid _ ->
        []
    | Doi _ ->
        [ P.(
            meta
              ~a:
                [ a_refines ("#" ^ identifier_id)
                ; a_property "identifier-type"
                ; a_scheme "onix:codelist5" ]
              (txt "06") ) ]
    | Isbn10 _ ->
        [ P.(
            meta
              ~a:
                [ a_refines ("#" ^ identifier_id)
                ; a_property "identifier-type"
                ; a_scheme "onix:codelist5" ]
              (txt "02") ) ]
    | Isbn13 _ ->
        [ P.(
            meta
              ~a:
                [ a_refines ("#" ^ identifier_id)
                ; a_property "identifier-type"
                ; a_scheme "onix:codelist5" ]
              (txt "15") ) ]
    | Isbn txt -> (
      match count_digits txt with
      | 10 ->
          Isbn10 txt |> make_id_meta
      | 13 ->
          Isbn13 txt |> make_id_meta
      | _ ->
          failwith "ISBN identifier does not have 10 or 13 digits" )
  in
  P.(
    metadata
      ~a:
        [ a_namespace ("dc", "http://purl.org/dc/elements/1.1/")
        ; a_namespace ("dcterms", "http://purl.org/dc/terms/") ]
      (dc_identifier ~a:[a_id identifier_id] (make_id_txt identifier |> txt))
      (dc_title (txt title))
      (dc_language (txt lang))
      (dc_meta_elements opt_meta)
      (package_meta_elements opt_meta @ make_id_meta identifier)
      [] (* Legacy Metadata *)
      [] (* Links to metadata in other docs *) )

let add_content ?(rev = false) pub newc =
  { archive= pub.archive
  ; output_path= pub.output_path
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
      P.(
        manifest_item
          ~a:[a_id id; a_href path; a_mediatype mime; a_properties ["nav"]]
          () )
  | NavigationCenter (mime, id, path) ->
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
  let rec find_ncx_id = function
    | [] ->
        None
    | NavigationCenter (_, id, _) :: _ ->
        Some id
    | _ :: tail ->
        find_ncx_id tail
  in
  let ncx_id = find_ncx_id docs in
  let spine_attrib = match ncx_id with None -> [] | Some s -> [P.a_toc s] in
  let items = optional_map build_spine_item docs in
  match items with
  | head :: tail ->
      P.spine ~a:spine_attrib head tail
  | [] ->
      failwith "Unable to build spine: must have at least one xhtml document"

let make_ocf_package pub =
  let make_identifier_id = function
    | Uuid _ ->
        "uuid-id"
    | Doi _ ->
        "doi-id"
    | Isbn _ ->
        "isbn-id"
    | Isbn10 _ ->
        "isbn-10-id"
    | Isbn13 _ ->
        "isbn-13-id"
  in
  let identifier_id = make_identifier_id pub.metadata.unique_id in
  let epub_version = "3.0" in
  P.(
    ocf_package
      ~a:[a_unique_id identifier_id; a_version epub_version]
      (build_metadata identifier_id pub.metadata.unique_id pub.metadata.title
         pub.metadata.primary_lang pub.metadata.opt_meta )
      (build_manifest pub.content)
      (build_spine pub.content) None (* Legacy guide elements *)
      None (* Deprecated bindings element *)
      [] (* Collection elements *) )

let make_meta_inf pub opf_path =
  let container_path = "META-INF/container.xml" in
  ocf_container opf_path |> write_ocf_container pub container_path

let make_mimetype_file pub =
  (* EPUB requires this to be the first ZIP entry and stored verbatim. *)
  Zip.add_entry "application/epub+zip" pub.archive ~level:0 "mimetype"

let read_u16 data offset =
  Char.code (Bytes.get data offset)
  lor (Char.code (Bytes.get data (offset + 1)) lsl 8)

let read_u32 data offset =
  Int64.logor (Int64.of_int (read_u16 data offset))
    (Int64.shift_left (Int64.of_int (read_u16 data (offset + 2))) 16)

let write_u16 data offset value =
  Bytes.set data offset (Char.chr (value land 0xFF)) ;
  Bytes.set data (offset + 1) (Char.chr ((value lsr 8) land 0xFF))

let write_u32 data offset value =
  write_u16 data offset (Int64.to_int value land 0xFFFF) ;
  write_u16 data (offset + 2)
    (Int64.to_int (Int64.shift_right_logical value 16) land 0xFFFF)

let has_signature data offset signature =
  Int64.equal (read_u32 data offset) signature

let find_eocd data =
  let rec find offset lower_bound =
    if offset < lower_bound then failwith "Invalid ZIP: end record not found"
    else if has_signature data offset 0x06054b50L then offset
    else find (offset - 1) lower_bound
  in
  find (Bytes.length data - 22) (max 0 (Bytes.length data - 65_557))

(* Camlzip reserves an unused Zip64 extra field in every local file header.
   EPUB forbids extra fields on its first, stored `mimetype` entry. *)
let remove_mimetype_extra_field path =
  let channel = open_in_bin path in
  let data = Bytes.of_string (really_input_string channel (in_channel_length channel)) in
  close_in channel ;
  if not (has_signature data 0 0x04034b50L) then
    failwith "Invalid ZIP: local header for mimetype not found" ;
  let filename_length = read_u16 data 26 in
  let extra_length = read_u16 data 28 in
  let filename = Bytes.sub_string data 30 filename_length in
  if filename <> "mimetype" then failwith "Invalid EPUB: mimetype is not first" ;
  if extra_length = 0 then ()
  else if
    extra_length <> 20
    || read_u16 data (30 + filename_length) <> 0
    || read_u16 data (32 + filename_length) <> 16
  then failwith "Unexpected ZIP extra field on EPUB mimetype entry"
  else (
    let extra_start = 30 + filename_length in
    let removed = extra_length in
    let patched = Bytes.create (Bytes.length data - removed) in
    Bytes.blit data 0 patched 0 extra_start ;
    Bytes.blit data (extra_start + removed) patched extra_start
      (Bytes.length data - extra_start - removed) ;
    write_u16 patched 28 0 ;
    let eocd = find_eocd patched in
    let cd_offset = Int64.to_int (read_u32 patched (eocd + 16)) - removed in
    let entry_count = read_u16 patched (eocd + 10) in
    let rec update_entries offset remaining =
      if remaining > 0 then (
        if not (has_signature patched offset 0x02014b50L) then
          failwith "Invalid ZIP: central directory entry not found" ;
        let name_length = read_u16 patched (offset + 28) in
        let extra_length = read_u16 patched (offset + 30) in
        let comment_length = read_u16 patched (offset + 32) in
        let local_offset = Int64.to_int (read_u32 patched (offset + 42)) in
        if local_offset > 0 then
          write_u32 patched (offset + 42)
            (Int64.of_int (local_offset - removed)) ;
        update_entries
          (offset + 46 + name_length + extra_length + comment_length)
          (remaining - 1) )
    in
    update_entries cd_offset entry_count ;
    write_u32 patched (eocd + 16) (Int64.of_int cd_offset) ;
    let temp = Filename.temp_file ~temp_dir:(Filename.dirname path) "epub-" ".zip" in
    Fun.protect
      ~finally:(fun () -> if Sys.file_exists temp then Sys.remove temp)
      (fun () ->
        let output = open_out_bin temp in
        output_bytes output patched ;
        close_out output ;
        Sys.rename temp path ) )

let make_navpoints docs =
  let rec find_navpoints l d =
    match d with
    | [] ->
        List.mapi (fun i (p, t) -> (i + 1, p, t)) l
    | Document ((_, _, path), title) :: tail ->
        find_navpoints ((path, title) :: l) tail
    | _ :: tail ->
        find_navpoints l tail
  in
  let make_navpoint path seq title =
    let id = "ncx-" ^ Int.to_string seq in
    N.(
      navpoint (a_id id) (a_playorder seq)
        (txt title |> text_content |> fun t -> navlabel t [])
        (a_src path |> navcontent) )
  in
  find_navpoints [] docs |> List.map (fun (s, p, t) -> make_navpoint p s t)

let build_ncx pub =
  let version = "2005-1" in
  N.(
    ncx
      ~a:[a_xml_lang pub.metadata.primary_lang]
      (a_version version)
      (head
         (meta (a_name "dtb:uid")
            (make_id_txt pub.metadata.unique_id |> a_content) )
         [] )
      (txt pub.metadata.title |> text_content |> fun t -> doc_title t [])
      [] (* Author list TODO *)
      ( match make_navpoints pub.content with
      | head :: tail ->
          navmap head tail
      | _ ->
          failwith
            "NCX file creation failure: requires at least one linkable \
             document." )
      [] (* Nav List *) )

let make_ncx ?(path = "toc.ncx") pub =
  build_ncx pub |> write_ncx pub path ;
  NavigationCenter (`Ncx, "ncx", path) |> add_content pub

let make_toc pub =
  let path, nav_doc =
    Ocf_nav.make_nav ~title:"Table of Contents" ~ln:pub.metadata.primary_lang
      pub.content
  in
  write_xhtml pub path nav_doc ;
  TableOfContents (`Xhtml, "toc", path) |> add_content ~rev:true pub

let open_out_pub ~unique_id:uuid ~title ~ln:lang
    ~(opt_meta : epub_metadata list) dst =
  let modified_datetime =
    let timestamp = Unix.gmtime (Unix.gettimeofday ()) in
    ModifiedDatetime
      (Printf.sprintf "%04d-%02d-%02dT%02d:%02d:%02dZ"
         (timestamp.tm_year + 1900) (timestamp.tm_mon + 1) timestamp.tm_mday
         timestamp.tm_hour timestamp.tm_min timestamp.tm_sec )
  in
  let opt_meta =
    let existing =
      List.find_opt (function ModifiedDatetime _ -> true | _ -> false) opt_meta
    in
    Option.value existing ~default:modified_datetime
    :: List.filter (function ModifiedDatetime _ -> false | _ -> true) opt_meta
  in
  let package_path = "content.opf" in
  let pub =
    { archive= Zip.open_out dst
    ; output_path= dst
    ; metadata=
        {unique_id= uuid; title; primary_lang= lang; opt_meta; package_path}
    ; content= []
    ; doc_count= 0 }
  in
  make_mimetype_file pub ;
  make_meta_inf pub package_path ;
  pub

let close_pub pub =
  make_ncx pub |> make_toc
  |> (* Table of contents dynamically created from all the documents *)
  make_ocf_package
  |> write_ocf_package pub pub.metadata.package_path ;
  Zip.close_out pub.archive ;
  remove_mimetype_extra_field pub.output_path
