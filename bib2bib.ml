

open Printf;;
open Bibtex;;


(* command-line arguments *)

let input_file_names = ref ([] : string list);;

let bib_output_file_name = ref "";;

let cite_output_file_name = ref "";;

let get_input_file_name f =
  input_file_names := f :: !input_file_names;;

let condition = ref Condition.True;;

let add_condition c = 
  try
    let c = Parse_condition.condition c in
    condition := if !condition = Condition.True then c 
    else Condition.And(!condition,c)
  with
      Condition_lexer.Lex_error msg ->
	prerr_endline ("Lexical error in condition: "^msg);
	exit 1
    | Parsing.Parse_error ->
	prerr_endline "Syntax error in condition";
	exit 1
;;

let debug = ref false;;

let expand_abbrevs = ref false;;

let args_spec =
  [
    ("-ob", 
     Arg.String(fun f -> bib_output_file_name := f),"bib output file name");
    ("-oc",
     Arg.String(fun f -> cite_output_file_name := f),"citations output file name");
    ("-c", Arg.String(add_condition),"filter condition");
    ("-d", Arg.Unit(fun () -> debug := true), "debug flag");
    ("--expand", Arg.Unit(fun () -> expand_abbrevs := true), "expand the abbreviations");
    ("--version", Arg.Unit(fun () -> exit 0), "print version and exit");
    ("--warranty", Arg.Unit(fun () -> Copying.copying(); exit 0), "display software warranty")
  ]



let output_cite_file keys = 
  if !cite_output_file_name = "" then
    prerr_endline "No citation file output (no file name specified)" 
  else 
    try
      let ch = open_out !cite_output_file_name in
      KeySet.iter (fun k -> output_string ch (k ^ "\n")) keys;
      close_out ch
    with 
	Sys_error msg ->
	  prerr_endline ("Cannot write output citations file (" ^ msg ^ ")");
	  exit 1
;;


let output_bib_file biblio keys = 
  try 
    let ch = 
      if !bib_output_file_name = "" 
      then stdout 
      else open_out !bib_output_file_name 
    in 
    let cmd = 
      List.fold_right (fun s t -> " "^s^t) (Array.to_list Sys.argv) "" 
    in 
    Biboutput.output_bib false ch 
      ((Comment "This file has been generated by bib2bib") :: 
       (Comment ("Command line:" ^ cmd)) :: biblio ) keys; 
    if !bib_output_file_name <> "" then close_out ch
  with Sys_error msg ->  
    prerr_endline ("Cannot write output bib file (" ^ msg ^ ")"); 
    exit 1 
;;

let usage = "Usage: bib2bib [options] <input file names>\nOptions are:";;

let main () =
  Copying.banner "bib2bib";
  Arg.parse args_spec get_input_file_name usage;
  if !debug then
    begin
      Printf.printf "command line:\n";
      for i=0 to pred (Array.length Sys.argv) do
	Printf.printf "%s\n" Sys.argv.(i)
      done;
    end;
  if !input_file_names = [] then input_file_names := [""];
  if !debug then Condition.print !condition; Printf.printf "\n"; 
  let all_entries =
    List.fold_left
      (fun l file -> l@(Readbib.read_entries_from_file file))
      []
      (List.rev !input_file_names)
  in 
  let expanded = Bibtex.expand_abbrevs all_entries
  in
  let matching_keys =
    Bibfilter.filter expanded 
      (fun k f -> Condition.evaluate_cond k f !condition) 
  in
  if KeySet.cardinal matching_keys = 0 then
    begin
      Printf.printf "No matching reference found. Giving up.\n";
      exit 2;
    end;
  
  let user_expanded = if !expand_abbrevs then expanded else all_entries in
  let needed_keys = Bibfilter.saturate user_expanded matching_keys in
  output_cite_file matching_keys;
  output_bib_file user_expanded (Some needed_keys)
;;




Printexc.catch main ();;


