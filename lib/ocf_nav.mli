val make_nav :
     title:string
  -> ln:string
  -> Epub_types.content list
  -> string * Tyxml.Html.doc
(** Make a navigation page out of the supplied documents *)
