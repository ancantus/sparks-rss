module Make (Xml : Xml_sigs.T with type ('a, 'b) W.ft = 'a -> 'b) :
  Ocf_container_sig.Make(Xml).T
    with type +'a elt = Xml.elt
     and type +'a attrib = Xml.attrib
