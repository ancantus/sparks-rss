module type T = sig
  open Epub_types

  (** Utility functionality required for most bespoke OCF files *)
  include Ocf_xml_sig.T

  (** Complete OCF container document *)
  type doc = ocf_container elt

  (** XML meta information: doctype, and the like *)
  module Info : Xml_sigs.Info

  val doc_toelt : doc -> Xml.elt
  (** Binding to outisde XML lib to render entire document *)

  (******* Attributes *******)

  val a_fullpath : text wrap -> [> `Path] attrib
  (** Path to the rootfile *)

  val a_mediatype : text wrap -> [> `Mediatype] attrib
  (** Type of the rootfile *)

  val a_version : text wrap -> [> `Version] attrib
  (** Version of the OCF container *)

  (******* Elements *******)

  val ocf_container :
       ?a:ocf_container_attrib attrib list
    -> [< rootfiles] elt wrap
    -> [< links] elt wrap_list option
    -> [> ocf_container] elt
  (** OCF `container.xml` that identifies the package documents *)

  val rootfiles :
    [< rootfile] elt wrap -> [< rootfile] elt wrap_list -> [> rootfiles] elt
  (** List of package document root files (minumum one). More than one is probably poorly supported. *)

  val rootfile : ([< rootfile_attrib], [> rootfile]) e_empty
  (** Description of a root package document. Should specify all attributes *)

  val links : [< link] elt wrap -> [< link] elt wrap_list -> [> links] elt
  (** List of links to identify the resources required to process the OCF zip container *)

  val link : ([< link_attrib], [> link]) e_empty
  (** Link to a resource to process the OCF container *)
end

module Make (Xml : Xml_sigs.T) : sig
  module type T =
    T
      with type 'a Xml.W.t = 'a Xml.W.t
       and type 'a Xml.W.tlist = 'a Xml.W.tlist
       and type ('a, 'b) Xml.W.ft = ('a, 'b) Xml.W.ft
       and type Xml.uri = Xml.uri
       and type Xml.attrib = Xml.attrib
       and type Xml.elt = Xml.elt
end
