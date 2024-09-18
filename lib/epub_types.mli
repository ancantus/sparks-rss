(** Attribute Types *)
type version = string
(** Version string of OCF package or other elements *)

(** MIME media type (rfc2046) *)
type mediatype = string

(** Path within the OCF container's filesystem. Relative to the root of the zipped directory *)
type path = string

(** String type within the OCF doc *)
type text = string

(** Key value used in the prefix system to shorthand a URL *)
type property = string

(** External resource *)
type url = string

(** Unique identifier within all OCF docs *)
type id = string

(** Base direction of textual content (under-supported) *)
type dir = [`Ltr | `Rtl | `Auto]

(** Custom extra mappings between a property and an external resource *)
type prefix = property * url

(** List of properties that has some defined vocabulary for each element *)
type properites = property list

(** A language tag specifying the textual content of the element *)
type language = string

(** XML namespace used to disambiguate symbols *)
type namespace = property * url

(** All possible publication resources that do not require fallbacks as per EPUB3 specification *)
type core_mediatype =
  [ (* Image types *)
    `Gif
  | `Jpeg
  | `Png
  | `Svg
  | `Webp
  | (* Video types *)
    `Mpeg
  | `Mp4
  | `Ogg_Opus
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
    `Xhtml
  | `Javascript
  | `Ncx
  | `Smil ]

(** Common attributes across multiple OCF elements *)
type id_attrib = [`Id]

type version_attrib = [`Version]

type namespace_attrib = [`Namespace]

type dir_attrib = [`Dir]

type href_attrib = [`Href]

type mediatype_attrib = [`Mediatype]

type properties_attrib = [`Properties]

type refines_attrib = [`Refines]

type language_attrib = [`Language]

(** Common elements across multiple OCF elements *)
type txt = [`PCDATA]

(****** OCF Container ******)
type ocf_container = [`Ocf_Container]

type ocf_container_attrib = [ | version_attrib]

type rootfiles = [`Rootfiles]

type rootfile = [`Rootfile]

type rootfile_attrib = [`Fullpath]

type links = [`Links]

type link = [`Link]

type link_attrib = [`Relationship]

(****** OCF Package *******)
type ocf_package = [`Ocf_Package]

type ocf_package_attrib = [version_attrib | `Unique_Identifier]

type metadata = [`Metadata]

type metadata_attrib = [ | namespace_attrib]

type dc_identifier = [`Dc_Identifier]

type dc_title = [`Dc_Title]

type dc_language = [`Dc_Language]

type dc_optional_element =
  [ dc_identifier
  | dc_title
  | dc_language
  | `Dc_Contributor
  | `Dc_Coverage
  | `Dc_Date
  | `Dc_Description
  | `Dc_Format
  | `Dc_Publisher
  | `Dc_Relation
  | `Dc_Rights
  | `Dc_Source
  | `Dc_Subject
  | `Dc_Type ]

type meta = [`Meta]

type meta_attrib =
  [ dir_attrib
  | id_attrib
  | refines_attrib
  | language_attrib
  | `Property
  | `Scheme ]

type opf2_meta = [`Opf2_Meta]

type opf2_meta_attrib = [`Opf2_Meta_Name | `Opf2_Meta_Content]

type metadata_link = [`Metadata_Link]

type metadata_link_attrib =
  [ href_attrib
  | id_attrib
  | mediatype_attrib
  | properties_attrib
  | refines_attrib
  | `Hreflang
  | `Rel ]

type manifest = [`Manifest]

type manifest_item = [`Manifest_Item]

type manifest_item_attrib =
  [ href_attrib
  | id_attrib
  | mediatype_attrib
  | properties_attrib
  | `Fallback
  | `Media_Overlay ]

type spine = [`Spine]

type spine_attrib = [id_attrib | `Page_Progression_Dir | `Table_Of_Contents]

type itemref = [`Itemref]

type itemref_attrib = [id_attrib | properties_attrib | `Idref | `Linear]

type guide = [`Guide]

type reference = [`Reference]

type reference_attrib = [href_attrib | `Type | `Title]

type bindings = [`Bindings]

type collection = [`Collection]

type collection_attrib = [dir_attrib | id_attrib | language_attrib | `Role]

(** Shared info for all content documents (MIME type, document unique id, path within epub file) *)
type base_content = core_mediatype * string * string

(** Classe of documents that are permitted in the EPUB doc *)
type content =
  | Document of base_content * string  (** basic content info, document title *)
  | SupportDocument of base_content
  | CoverImage of base_content
  | CoverPage of base_content
  | TableOfContents of base_content
