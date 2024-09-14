module type T = sig
  (** An XML element *)
  type +'a elt

  (** An XML attribute *)
  type +'a attrib

  module Xml : Xml_sigs.T

  (** wrapper for the basic XML type *)
  type 'a wrap = 'a Xml.W.t

  (** wrapper for a list of XML types *)
  type 'a wrap_list = 'a Xml.W.tlist

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

  (** XML meta information: doctype, and the like *)
  module Info : Xml_sigs.Info

  val toelt : 'a elt -> Xml.elt
  (** Hook to XML parsing / printing function for element wise operations *)
end
