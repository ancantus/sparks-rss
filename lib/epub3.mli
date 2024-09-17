open Epub_types

type title = string
(** A human readable title used in the table of contents *)

type file_contents = string
(** The read contents of a file to be saved to the epub publication *)

type epub_metadata =
  | Title of string
  | UniqueIdentifier of string
  | Language of string
  | ModifiedDatetime of string

(** Shared info for all content documents (MIME type, document unique id, path within epub file) *)
type base_content = core_mediatype * string * string

type content =
  | Document of base_content * string  (** basic content info, document title *)
  | SupportDocument of base_content
  | CoverImage of base_content

type publication =
  { path: string  (** Path to temporary dir where epub is being contructed *)
  ; metadata: string * string * Tyxml_xml.elt
        (** opf filename, identifier_id, and Metadata of the epub document *)
  ; content: content list
        (** Content (displayble components & supporting docs) within the epub doc *)
  ; doc_count: int  (** Number of toc splitable docs *) }

val save_xhtml_doc : publication -> title -> file_contents -> publication
(** Save an XHTML content document to an in-process epub document *)

val save_support_doc :
  publication -> path -> core_mediatype -> file_contents -> publication
(** Save a support document (image, stylesheet, or other linkable content) to an in-process epub document *)

val save_cover_image :
  publication -> path -> core_mediatype -> file_contents -> publication
(** Save a cover image to an in-process epub document *)

val open_out_pub : id -> title -> language -> epub_metadata list -> publication
(** Open an output writable EPUB3 publication. Use other functions to add data to the publication. Only valid when closed *)

val close_pub : publication -> unit
(** Close an open writable publication. *)
