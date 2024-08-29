open Soup.Infix

let parse_fx_reader (node : Soup.soup Soup.node) =
  let header = node $ ".header" in
  let content = node $ ".content" in
  (header |> Soup.to_string) ^ (content |> Soup.to_string)
