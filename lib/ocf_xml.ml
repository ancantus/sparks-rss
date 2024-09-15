module Make (Xml : Xml_sigs.T) = struct
  module Xml = Xml
  module W = Xml.W

  type 'a elt = Xml.elt

  type 'a attrib = Xml.attrib

  type 'a wrap = 'a W.t

  type 'a wrap_list = 'a W.tlist

  (* internal building blocks *)
  let a_string = Xml.string_attrib

  let a_string_list label items =
    let rec space_sep_string acc items =
      match items with
      | [] ->
          acc
      | head :: [] ->
          acc ^ head
      | head :: tail ->
          space_sep_string (acc ^ head) tail
    in
    a_string label (space_sep_string "" items |> Xml.W.return)

  let txt = Xml.pcdata

  type ('a, 'b) e_empty = ?a:'a attrib list -> unit -> 'b elt

  type ('a, 'b, 'c) e_single = ?a:'a attrib list -> 'b elt wrap -> 'c elt

  type ('a, 'b, 'c) e_list = ?a:'a attrib list -> 'b elt wrap_list -> 'c elt

  type ('a, 'b, 'c) e_req_list =
    ?a:'a attrib list -> 'b elt wrap -> 'b elt wrap_list -> 'c elt

  let e_empty tag ?a () = Xml.leaf ?a tag

  let e_single tag ?a elt = Xml.node ?a tag (W.singleton elt)

  let e_list tag ?a elt_list = Xml.node ?a tag elt_list

  let e_req_list tag ?a elt elt_list = Xml.node ?a tag (W.cons elt elt_list)

  let toelt x = x
end
