module type T = sig
  open Epub_types

  (** An element for the container.xml *)
  type +'a elt

  (** An XML attribute *)
  type +'a attrib

  (** Complete OCF container document *)
  type doc = ocf_container elt

  module Xml : Xml_sigs.T

  (** wrapper for the basic XML type *)
  type 'a wrap = 'a Xml.W.t

  (** wrapper for a list of XML types *)
  type 'a wrap_list = 'a Xml.W.tlist

  (** Attributes *)
  val a_fullpath : text wrap -> [> `Path] attrib
  (** Path to the rootfile *)

  val a_mediatype : text wrap -> [> `Mediatype] attrib
  (** Type of the rootfile *)

  val a_version : text wrap -> [> `Version] attrib
  (** Version of the OCF container *)

  (** Helper functions for constructing XML elements *)

  (** XML element with no children *)
  type ('a, 'b) e_empty = ?a:'a attrib list -> unit -> 'b elt

  (** XML element with a single child *)
  type ('a, 'b, 'c) e_single = ?a:'a attrib list -> 'b elt wrap -> 'c elt

  (** XML element with a list of children (0 or more) *)
  type ('a, 'b, 'c) e_list = ?a:'a attrib list -> 'b elt wrap_list -> 'c elt

  (** XML element with a list of children where at least one is required *)
  type ('a, 'b, 'c) e_req_list =
    ?a:'a attrib list -> 'b elt wrap -> 'b elt wrap_list -> 'c elt

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

  (** XML meta information: doctype, and the like *)
  module Info : Xml_sigs.Info

  val doc_toelt : doc -> Xml.elt

  val toelt : 'a elt -> Xml.elt
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
