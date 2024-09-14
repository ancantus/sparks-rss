(** Attribute Types *)
type version = string
(** Version string of OCF package or other elements *)

(** MIME media type (rfc2046) *)
type mediatype = string

(** Path within the OCF container's filesystem. Relative to the root of the zipped directory *)
type path = string

(** String type within the OCF doc *)
type text = string

(** Unique identifier within all OCF docs *)
type id = string

(** Base direction of textual content (under-supported) *)
type dir = [`Ltr | `Rtl | `Auto]

(** List of properties that has some defined vocabulary for each element *)
type properites = string list

(** All possible publication resources that do not require fallbacks as per EPUB3 specification *)
type coretypes =
  [ (* Image types *)
    `Gif
  | `Jpeg
  | `Png
  | `Svg
  | `Webp
  | (* Video types *)
    `Mpeg
  | `Mp4
  | `Oog_Opus
  | (* Styling *)
    `Css
  | (* Fonts *)
    `Tff
  | `Sfnt
  | `Otf
  | `Eot
  | `Woff
  | `Woff2
  | (* Content Docs / Other *)
    `Xhmtl
  | `Javascript
  | `Ncx
  | `Smil ]

(****** OCF Container ******)
type ocf_container = [`Ocf_Container]

type ocf_container_attrib = [`Version]

type rootfiles = [`Rootfiles]

type rootfile = [`Rootfile]

type rootfile_attrib = [`Fullpath | `Mediatype]

type links = [`Links]

type link = [`Link]

type link_attrib = [`Href | `Mediatype | `Relationship]

(****** OCF Package *******)
type ocf_package = [`Ocf_Package]
