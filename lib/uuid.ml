(** Convert an octet into a hex char *)
let to_hex = function
  | 0 ->
      '0'
  | 1 ->
      '1'
  | 2 ->
      '2'
  | 3 ->
      '3'
  | 4 ->
      '4'
  | 5 ->
      '5'
  | 6 ->
      '6'
  | 7 ->
      '7'
  | 8 ->
      '8'
  | 9 ->
      '9'
  | 10 ->
      'A'
  | 11 ->
      'B'
  | 12 ->
      'C'
  | 13 ->
      'D'
  | 14 ->
      'E'
  | 15 ->
      'F'
  | _ ->
      failwith "Integer outside the hex interval"

(** Turn an int64 into a sequence of octets *)
let octet_seq num =
  Seq.init 16 (fun i ->
      Int64.shift_right_logical num (i * 4)
      |> Int64.logand (Int64.of_int 0xF)
      |> Int64.to_int )

(** Map in the UUID version *)
let version ~v i octet = match i with 12 -> v | _ -> octet

(** Map in the uuid4 variant bits *)
let uuid4_variant i octet =
  match i with 16 -> Int.logand octet 0x3 |> Int.logor 0x8 | _ -> octet

(** Format a stream of octets into a stringly formatted uuid *)
let format_uuid octstream =
  let format uuid_str =
    String.sub uuid_str 0 8 ^ "-" ^ String.sub uuid_str 8 4 ^ "-"
    ^ String.sub uuid_str 12 4 ^ "-" ^ String.sub uuid_str 16 4 ^ "-"
    ^ String.sub uuid_str 20 12
  in
  Seq.map to_hex octstream |> String.of_seq |> format

let uuid4 () =
  Random.self_init () ;
  Seq.append (Random.bits64 () |> octet_seq) (Random.bits64 () |> octet_seq)
  |> Seq.mapi (version ~v:4)
  |> Seq.mapi uuid4_variant |> format_uuid
