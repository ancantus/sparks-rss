let batches size items =
  let rec take remaining collected rest =
    if remaining = 0 then (List.rev collected, rest)
    else
      match rest with
      | [] ->
          (List.rev collected, [])
      | item :: tail ->
          take (remaining - 1) (item :: collected) tail
  in
  let rec loop items =
    match items with
    | [] ->
        []
    | _ ->
        let batch, rest = take size [] items in
        batch :: loop rest
  in
  loop items

let map_p ~max_concurrent f items =
  if max_concurrent < 1 then invalid_arg "max_concurrent must be positive" ;
  let rec run collected = function
    | [] ->
        Lwt.return (List.concat (List.rev collected))
    | batch :: tail ->
        let open Lwt.Syntax in
        let* results = Lwt_list.map_p f batch in
        run (results :: collected) tail
  in
  run [] (batches max_concurrent items)
