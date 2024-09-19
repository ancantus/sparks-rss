open Epub_types

(** The read contents of a file to be saved to the epub publication *)
type file_contents = string

type epub_metadata =
  | Title of string
  | UniqueIdentifier of string
  | Language of string
  | ModifiedDatetime of string

type pub_metadata =
  { title: string
  ; unique_id: string
  ; primary_lang: string
  ; opt_meta: epub_metadata list
  ; package_path: string }

type publication =
  { archive: Zip.out_file  (** in progress epub zip file *)
  ; metadata: pub_metadata
  ; content: content list
        (** Content (displayble components & supporting docs) within the epub doc *)
  ; doc_count: int  (** Number of toc splitable docs *) }

val save_xhtml_doc : publication -> text -> file_contents -> publication
(** Save an XHTML content document to an in-process epub document *)

val save_support_doc :
  publication -> path -> core_mediatype -> file_contents -> publication
(** Save a support document (image, stylesheet, or other linkable content) to an in-process epub document *)

val save_cover_image :
  publication -> path -> core_mediatype -> file_contents -> publication
(** Save a cover image to an in-process epub document *)

val open_out_pub :
     unique_id:id
  -> title:string
  -> ln:string
  -> opt_meta:epub_metadata list
  -> string
  -> publication
(** Open an output writable EPUB3 publication. Use other functions to add data to the publication. Only valid when closed *)

val close_pub : publication -> unit
(** Close an open writable publication. *)
