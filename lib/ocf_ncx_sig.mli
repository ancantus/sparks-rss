module type T = sig
  open Epub_types

  (** Utility functionality required for most bespoke OCF files *)
  include Ocf_xml_sig.T

  (** Complete OCF container document *)
  type doc = ocf_ncx elt

  val doc_toelt : doc -> Xml.elt
  (** Binding to outisde XML lib to render entire document *)

  (******* Attributes *******)

  val a_version : version wrap -> [> `Version] attrib
  (** Version of the NCX file *)

  val a_lang : language wrap -> [> `Language] attrib
  (** A language tag specifying the textual content of the element *)

  val a_xml_lang : language wrap -> [> `Xml_Language] attrib
  (** A language tag specifying the textual content of the element *)

  val a_content : text wrap -> [> `Content] attrib
  (** Content for the meta tag *)

  val a_name : text wrap -> [> `Name] attrib
  (** Name for the meta tag *)

  val a_scheme : text wrap -> [> `Scheme] attrib
  (** Scheme of the meta tag *)

  val a_id : id wrap -> [> `Id] attrib
  (** Unique Id for xml elements *)

  val a_class : text wrap -> [> `Class] attrib
  (** Class of a content object *)

  val a_src : path wrap -> [> `Src] attrib
  (** Source location of a file within the epub document *)

  val a_clipbegin : text wrap -> [> `ClipBegin] attrib
  (** SIML formatted time value for the begining of an audio clip *)

  val a_clipend : text wrap -> [> `ClipEnd] attrib
  (** SIML formatted time value for the end of an audio clip *)

  val a_playorder : int wrap -> [> `PlayOrder] attrib
  (** Order of play for the reader *)

  val a_value : int wrap -> [> `Value] attrib
  (** Numeric value associated with a NCX target *)

  type page_type = Front | Normal | Special

  val a_pagetype : page_type -> [`Type] attrib
  (** Type of page to link to *)

  (******* Elements *******)
  val ncx :
       ?a:[< ncx_attrib] attrib list
    -> [< version_attrib] attrib
    -> [< ncx_head] elt wrap
    -> [< doc_title] elt wrap
    -> [< doc_author] elt wrap_list
    -> [< navmap] elt wrap
    -> ?pagelist:[< pagelist] elt wrap
    -> [< navlist] elt wrap_list
    -> [> ocf_ncx] elt

  val head :
       [< ncx_head_children] elt wrap
    -> [< ncx_head_children] elt wrap_list
    -> [> ncx_head] elt

  val meta :
       ?scheme:[< `Scheme] attrib
    -> [< `Name] attrib
    -> [< `Content] attrib
    -> ncx_meta elt
  (** Arbitrary metadata for the NCX file *)

  val doc_title :
    ([< doc_title_attrib], [< ncx_content], [> doc_title]) e_req_list
  (** Title of the document *)

  val doc_author :
    ([< doc_author_attrib], [< ncx_content], [> doc_author]) e_req_list
  (** Author of the document *)

  val text_content :
    ([< default_content_attrib], [< txt], [> text_content]) e_single
  (** A text content type (the primary kind) *)

  val audio_content :
       ?a:[< default_content_attrib] attrib list
    -> [< `Src] attrib
    -> [`ClipBegin] attrib
    -> [`ClipEnd] attrib
    -> audio_content elt
  (** Audio clip content type *)

  val image_content :
       ?a:[< default_content_attrib] attrib list
    -> [< `Src] attrib
    -> image_content elt
  (* Image content type *)

  val navmap : ([< navmap_attrib], [< navpoint], [> navmap]) e_req_list
  (** Map of all navigation points (table of contents like) *)

  val navpoint :
       ?cls:[< class_attrib] attrib
    -> [< id_attrib] attrib
    -> [< playorder_attrib] attrib
    -> ?children:[< navpoint_children] elt wrap_list
    -> [< navlabel] elt wrap
    -> [< navcontent] elt wrap
    -> navpoint elt
  (** Navigatable element: can contain more of itself for tree like navigation structure *)

  val navlabel : ([< navlabel_attrib], [< ncx_content], [> navlabel]) e_req_list
  (* Label describing the navigatable content *)

  val navcontent :
    ?id:[< id_attrib] attrib -> [< src_attrib] attrib -> [> navcontent] elt
  (** Path within the epub doc to the file referenced by a navpoint *)

  val pagelist :
       ?a:[< pagelist_attrib] attrib list
    -> [< pagetarget] elt wrap
    -> [< pagelist_children] elt wrap_list
    -> [> pagelist] elt
  (** List to map a digital publication to phsyical page numbers *)

  val pagetarget :
       ?a:[< pagetarget_attrib] attrib list
    -> [< `Value] attrib
    -> [< playorder_attrib] attrib
    -> [< navlabel] elt wrap
    -> ?labels:[< navlabel] elt wrap_list
    -> [< navcontent] elt wrap
    -> pagetarget elt
  (** Link within the epub document for a specific page *)

  val navlist :
       ?a:[< navlist_attrib] attrib list
    -> ?children:[< navlist_children] elt wrap_list
    -> [< navlabel] elt wrap
    -> [< navtarget] elt wrap
    -> navlist elt
  (* Flat navigation list for distinct sets of navigatable elements *)

  val navtarget :
       ?a:[< navtarget_opt_attrib] attrib list
    -> [< id_attrib] attrib
    -> [< playorder_attrib] attrib
    -> [< navlabel] elt wrap
    -> ?labels:[< navlabel] elt wrap_list
    -> [< navcontent] elt wrap
    -> navtarget elt
  (* Link to a navigatable target *)
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
