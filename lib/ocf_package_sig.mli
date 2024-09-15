module type T = sig
  open Epub_types

  (** Utility functionality required for most bespoke OCF files *)
  include Ocf_xml_sig.T

  (** Complete OCF container document *)
  type doc = ocf_package elt

  val doc_toelt : doc -> Xml.elt
  (** Binding to outisde XML lib to render entire document *)

  (******* Attributes *******)
  val a_dir : dir -> [> `Dir] attrib
  (** Base direction of textual content (under-supported) *)

  val a_id : id wrap -> [> `Id] attrib
  (** Unique identifier within all OCF docs *)

  val a_prefix : prefix list -> [> `Prefix] attrib
  (** Custom extra mappings between a property and an external resource *)

  val a_lang : language wrap -> [> `Language] attrib
  (** A language tag specifying the textual content of the element *)

  val a_unique_id : id wrap -> [> `Unique_Identifier] attrib
  (** Id of the element that provides the authoritative `dc::identifier` attribute *)

  val a_version : version wrap -> [> `Version] attrib
  (** Version of a element: usually specifying a particular schema *)

  val a_mediatype : core_mediatype -> [> `Mediatype] attrib
  (** MIME type of the referenced file *)

  val a_namespace : namespace -> [> `Namespace] attrib
  (** XML namespace definition used within children *)

  val a_property : property wrap -> [`Property] attrib
  (** Reference name to a longer namespace-like URL *)

  val a_properties : property list -> [`Properties] attrib
  (** Space seperated list of properties *)

  val a_href : path wrap -> [`Href] attrib
  (** Link to an file within the OCF package *)

  val a_idref : id wrap -> [`Idref] attrib
  (** ID attribute referenced by the element *)

  (******* Elements *******)
  val ocf_package :
       ?a:ocf_package_attrib attrib list
    -> [< metadata] elt wrap
    -> [< manifest] elt wrap
    -> [< spine] elt wrap
    -> [< guide] elt wrap option
    -> [< bindings] elt wrap option
    -> [< collection] elt wrap_list
    -> [> ocf_package] elt
  (** Description of the entire OCF package document *)

  val metadata :
       ?a:metadata_attrib attrib list
    -> [< dc_identifier] elt wrap
    -> [< dc_title] elt wrap
    -> [< dc_language] elt wrap
    -> [< dc_optional_element] elt wrap_list
    -> [< meta] elt wrap_list
    -> [< opf2_meta] elt wrap_list
    -> [< metadata_link] elt wrap_list
    -> [> metadata] elt
  (** Meta information for the package *)

  val dc_identifier : ([< id_attrib], [< txt], [> dc_identifier]) e_single
  (** Unique identifier for EPUB publication *)

  val dc_title : ([< id_attrib], [< txt], [> dc_title]) e_single
  (** Title for the EPUB publication *)

  val dc_language : ([< id_attrib], [< txt], [> dc_language]) e_single
  (** Language of the content for the EPUB publication *)

  val meta : ([< meta_attrib], [< txt], [> meta]) e_single
  (** Arbitrary property to value map *)

  val opf2_meta : ([< opf2_meta_attrib], [< txt], [> opf2_meta]) e_single
  (** OPF2 version of the `meta` info (incompatible schema) *)

  val metadata_link : ([< metadata_link_attrib], [> metadata_link]) e_empty
  (** Links other resources to metadata records *)

  val manifest : ([< id_attrib], [< manifest_item], [> manifest]) e_req_list
  (** Exhaustive list of all publication resources used in the rendering of the content *)

  val manifest_item : ([< manifest_item_attrib], [> manifest_item]) e_empty
  (** A link to a single publication resource *)

  val spine : ([< spine_attrib], [< itemref], [> spine]) e_req_list
  (** Ordered list of manifest items that represent the default reading order *)

  val itemref : ([< itemref_attrib], [> itemref]) e_empty
  (** Reference to a manifest item *)

  val guide :
    [< reference] elt wrap -> [< reference] elt wrap_list -> [> guide] elt
  (** Legacy machine parsable navigation key structured for EPUB2 *)

  val reference : ([< reference_attrib], [> reference]) e_empty
  (** Link to a navigatable component *)

  val collection :
       ?a:collection_attrib attrib list
    -> ?m:[> metadata] elt wrap
    -> [< collection] elt wrap_list
    -> [< metadata_link] elt wrap_list
    -> [> collection] elt
  (** Definiton of a related group of resources *)
end

module Make (Xml : Xml_sigs.T) : sig
  module type T =
    T
      with type 'a Xml.W.t = 'a Xml.W.t
       and type 'a Xml.W.tlist = 'a Xml.W.tlist
       and type ('a, 'b) Xml.W.ft = ('a, 'b) Xml.W.ft
       and type Xml.attrib = Xml.attrib
       and type Xml.elt = Xml.elt
end
