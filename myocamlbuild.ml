(* Lightweight thread library for OCaml
 * http://www.ocsigen.org/lwt
 * Module Myocamlbuild
 * Copyright (C) 2010 Jérémie Dimino
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, with linking exceptions;
 * either version 2.1 of the License, or (at your option) any later
 * version. See COPYING file for details.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
 * 02111-1307, USA.
 *)

(* OASIS_START *)
(* DO NOT EDIT (digest: 1caca68e157ace3e99753e64506c3b67) *)
module OASISGettext = struct
(* # 22 "src/oasis/OASISGettext.ml" *)


  let ns_ str =
    str


  let s_ str =
    str


  let f_ (str: ('a, 'b, 'c, 'd) format4) =
    str


  let fn_ fmt1 fmt2 n =
    if n = 1 then
      fmt1^^""
    else
      fmt2^^""


  let init =
    []


end

module OASISExpr = struct
(* # 22 "src/oasis/OASISExpr.ml" *)





  open OASISGettext


  type test = string 


  type flag = string 


  type t =
    | EBool of bool
    | ENot of t
    | EAnd of t * t
    | EOr of t * t
    | EFlag of flag
    | ETest of test * string
    


  type 'a choices = (t * 'a) list 


  let eval var_get t =
    let rec eval' =
      function
        | EBool b ->
            b

        | ENot e ->
            not (eval' e)

        | EAnd (e1, e2) ->
            (eval' e1) && (eval' e2)

        | EOr (e1, e2) ->
            (eval' e1) || (eval' e2)

        | EFlag nm ->
            let v =
              var_get nm
            in
              assert(v = "true" || v = "false");
              (v = "true")

        | ETest (nm, vl) ->
            let v =
              var_get nm
            in
              (v = vl)
    in
      eval' t


  let choose ?printer ?name var_get lst =
    let rec choose_aux =
      function
        | (cond, vl) :: tl ->
            if eval var_get cond then
              vl
            else
              choose_aux tl
        | [] ->
            let str_lst =
              if lst = [] then
                s_ "<empty>"
              else
                String.concat
                  (s_ ", ")
                  (List.map
                     (fun (cond, vl) ->
                        match printer with
                          | Some p -> p vl
                          | None -> s_ "<no printer>")
                     lst)
            in
              match name with
                | Some nm ->
                    failwith
                      (Printf.sprintf
                         (f_ "No result for the choice list '%s': %s")
                         nm str_lst)
                | None ->
                    failwith
                      (Printf.sprintf
                         (f_ "No result for a choice list: %s")
                         str_lst)
    in
      choose_aux (List.rev lst)


end


# 132 "myocamlbuild.ml"
module BaseEnvLight = struct
(* # 22 "src/base/BaseEnvLight.ml" *)


  module MapString = Map.Make(String)


  type t = string MapString.t


  let default_filename =
    Filename.concat
      (Sys.getcwd ())
      "setup.data"


  let load ?(allow_empty=false) ?(filename=default_filename) () =
    if Sys.file_exists filename then
      begin
        let chn =
          open_in_bin filename
        in
        let st =
          Stream.of_channel chn
        in
        let line =
          ref 1
        in
        let st_line =
          Stream.from
            (fun _ ->
               try
                 match Stream.next st with
                   | '\n' -> incr line; Some '\n'
                   | c -> Some c
               with Stream.Failure -> None)
        in
        let lexer =
          Genlex.make_lexer ["="] st_line
        in
        let rec read_file mp =
          match Stream.npeek 3 lexer with
            | [Genlex.Ident nm; Genlex.Kwd "="; Genlex.String value] ->
                Stream.junk lexer;
                Stream.junk lexer;
                Stream.junk lexer;
                read_file (MapString.add nm value mp)
            | [] ->
                mp
            | _ ->
                failwith
                  (Printf.sprintf
                     "Malformed data file '%s' line %d"
                     filename !line)
        in
        let mp =
          read_file MapString.empty
        in
          close_in chn;
          mp
      end
    else if allow_empty then
      begin
        MapString.empty
      end
    else
      begin
        failwith
          (Printf.sprintf
             "Unable to load environment, the file '%s' doesn't exist."
             filename)
      end


  let var_get name env =
    let rec var_expand str =
      let buff =
        Buffer.create ((String.length str) * 2)
      in
        Buffer.add_substitute
          buff
          (fun var ->
             try
               var_expand (MapString.find var env)
             with Not_found ->
               failwith
                 (Printf.sprintf
                    "No variable %s defined when trying to expand %S."
                    var
                    str))
          str;
        Buffer.contents buff
    in
      var_expand (MapString.find name env)


  let var_choose lst env =
    OASISExpr.choose
      (fun nm -> var_get nm env)
      lst
end


# 236 "myocamlbuild.ml"
module MyOCamlbuildFindlib = struct
(* # 22 "src/plugins/ocamlbuild/MyOCamlbuildFindlib.ml" *)


  (** OCamlbuild extension, copied from
    * http://brion.inria.fr/gallium/index.php/Using_ocamlfind_with_ocamlbuild
    * by N. Pouillard and others
    *
    * Updated on 2009/02/28
    *
    * Modified by Sylvain Le Gall
    *)
  open Ocamlbuild_plugin


  (* these functions are not really officially exported *)
  let run_and_read =
    Ocamlbuild_pack.My_unix.run_and_read


  let blank_sep_strings =
    Ocamlbuild_pack.Lexers.blank_sep_strings


  let split s ch =
    let buf = Buffer.create 13 in
    let x = ref [] in
    let flush () =
      x := (Buffer.contents buf) :: !x;
      Buffer.clear buf
    in
      String.iter
        (fun c ->
           if c = ch then
             flush ()
           else
             Buffer.add_char buf c)
        s;
      flush ();
      List.rev !x


  let split_nl s = split s '\n'


  let before_space s =
    try
      String.before s (String.index s ' ')
    with Not_found -> s

  (* ocamlfind command *)
  let ocamlfind x =
    let ocamlfind_prog =
      let env_filename = Pathname.basename BaseEnvLight.default_filename in
      let env = BaseEnvLight.load ~filename:env_filename ~allow_empty:true () in
      try
        BaseEnvLight.var_get "ocamlfind" env
      with Not_found ->
        Printf.eprintf "W: Cannot get variable ocamlfind";
        "ocamlfind"
    in
      S[Sh ocamlfind_prog; x]

  (* This lists all supported packages. *)
  let find_packages () =
    List.map before_space (split_nl & run_and_read "ocamlfind list")


  (* Mock to list available syntaxes. *)
  let find_syntaxes () = ["camlp4o"; "camlp4r"]


  let dispatch =
    function
      | Before_options ->
          (* By using Before_options one let command line options have an higher
           * priority on the contrary using After_options will guarantee to have
           * the higher priority override default commands by ocamlfind ones *)
          Options.ocamlc     := ocamlfind & A"ocamlc";
          Options.ocamlopt   := ocamlfind & A"ocamlopt";
          Options.ocamldep   := ocamlfind & A"ocamldep";
          Options.ocamldoc   := ocamlfind & A"ocamldoc";
          Options.ocamlmktop := ocamlfind & A"ocamlmktop";
          Options.ocamlmklib := ocamlfind & A"ocamlmklib"

      | After_rules ->

          (* When one link an OCaml library/binary/package, one should use
           * -linkpkg *)
          flag ["ocaml"; "link"; "program"] & A"-linkpkg";

          (* For each ocamlfind package one inject the -package option when
           * compiling, computing dependencies, generating documentation and
           * linking. *)
          List.iter
            begin fun pkg ->
              let base_args = [A"-package"; A pkg] in
              let syn_args = [A"-syntax"; A "camlp4o"] in
              let args =
          (* Heuristic to identify syntax extensions: whether they end in
           * ".syntax"; some might not *)
                if Filename.check_suffix pkg "syntax"
                then syn_args @ base_args
                else base_args
              in
              flag ["ocaml"; "compile";  "pkg_"^pkg] & S args;
              flag ["ocaml"; "ocamldep"; "pkg_"^pkg] & S args;
              flag ["ocaml"; "doc";      "pkg_"^pkg] & S args;
              flag ["ocaml"; "link";     "pkg_"^pkg] & S base_args;
              flag ["ocaml"; "infer_interface"; "pkg_"^pkg] & S args;
            end
            (find_packages ());

          (* Like -package but for extensions syntax. Morover -syntax is useless
           * when linking. *)
          List.iter begin fun syntax ->
          flag ["ocaml"; "compile";  "syntax_"^syntax] & S[A"-syntax"; A syntax];
          flag ["ocaml"; "ocamldep"; "syntax_"^syntax] & S[A"-syntax"; A syntax];
          flag ["ocaml"; "doc";      "syntax_"^syntax] & S[A"-syntax"; A syntax];
          flag ["ocaml"; "infer_interface"; "syntax_"^syntax] &
                S[A"-syntax"; A syntax];
          end (find_syntaxes ());

          (* The default "thread" tag is not compatible with ocamlfind.
           * Indeed, the default rules add the "threads.cma" or "threads.cmxa"
           * options when using this tag. When using the "-linkpkg" option with
           * ocamlfind, this module will then be added twice on the command line.
           *
           * To solve this, one approach is to add the "-thread" option when using
           * the "threads" package using the previous plugin.
           *)
          flag ["ocaml"; "pkg_threads"; "compile"] (S[A "-thread"]);
          flag ["ocaml"; "pkg_threads"; "doc"] (S[A "-I"; A "+threads"]);
          flag ["ocaml"; "pkg_threads"; "link"] (S[A "-thread"]);
          flag ["ocaml"; "pkg_threads"; "infer_interface"] (S[A "-thread"]);
          flag ["ocaml"; "package(threads)"; "compile"] (S[A "-thread"]);
          flag ["ocaml"; "package(threads)"; "doc"] (S[A "-I"; A "+threads"]);
          flag ["ocaml"; "package(threads)"; "link"] (S[A "-thread"]);
          flag ["ocaml"; "package(threads)"; "infer_interface"] (S[A "-thread"]);

      | _ ->
          ()
end

module MyOCamlbuildBase = struct
(* # 22 "src/plugins/ocamlbuild/MyOCamlbuildBase.ml" *)


  (** Base functions for writing myocamlbuild.ml
      @author Sylvain Le Gall
    *)





  open Ocamlbuild_plugin
  module OC = Ocamlbuild_pack.Ocaml_compiler


  type dir = string 
  type file = string 
  type name = string 
  type tag = string 


(* # 62 "src/plugins/ocamlbuild/MyOCamlbuildBase.ml" *)


  type t =
      {
        lib_ocaml: (name * dir list * string list) list;
        lib_c:     (name * dir * file list) list;
        flags:     (tag list * (spec OASISExpr.choices)) list;
        (* Replace the 'dir: include' from _tags by a precise interdepends in
         * directory.
         *)
        includes:  (dir * dir list) list;
      } 


  let env_filename =
    Pathname.basename
      BaseEnvLight.default_filename


  let dispatch_combine lst =
    fun e ->
      List.iter
        (fun dispatch -> dispatch e)
        lst


  let tag_libstubs nm =
    "use_lib"^nm^"_stubs"


  let nm_libstubs nm =
    nm^"_stubs"


  let dispatch t e =
    let env =
      BaseEnvLight.load
        ~filename:env_filename
        ~allow_empty:true
        ()
    in
      match e with
        | Before_options ->
            let no_trailing_dot s =
              if String.length s >= 1 && s.[0] = '.' then
                String.sub s 1 ((String.length s) - 1)
              else
                s
            in
              List.iter
                (fun (opt, var) ->
                   try
                     opt := no_trailing_dot (BaseEnvLight.var_get var env)
                   with Not_found ->
                     Printf.eprintf "W: Cannot get variable %s" var)
                [
                  Options.ext_obj, "ext_obj";
                  Options.ext_lib, "ext_lib";
                  Options.ext_dll, "ext_dll";
                ]

        | After_rules ->
            (* Declare OCaml libraries *)
            List.iter
              (function
                 | nm, [], intf_modules ->
                     ocaml_lib nm;
                     let cmis =
                       List.map (fun m -> (String.uncapitalize m) ^ ".cmi")
                                intf_modules in
                     dep ["ocaml"; "link"; "library"; "file:"^nm^".cma"] cmis
                 | nm, dir :: tl, intf_modules ->
                     ocaml_lib ~dir:dir (dir^"/"^nm);
                     List.iter
                       (fun dir ->
                          List.iter
                            (fun str ->
                               flag ["ocaml"; "use_"^nm; str] (S[A"-I"; P dir]))
                            ["compile"; "infer_interface"; "doc"])
                       tl;
                     let cmis =
                       List.map (fun m -> dir^"/"^(String.uncapitalize m)^".cmi")
                                intf_modules in
                     dep ["ocaml"; "link"; "library"; "file:"^dir^"/"^nm^".cma"]
                         cmis)
              t.lib_ocaml;

            (* Declare directories dependencies, replace "include" in _tags. *)
            List.iter
              (fun (dir, include_dirs) ->
                 Pathname.define_context dir include_dirs)
              t.includes;

            (* Declare C libraries *)
            List.iter
              (fun (lib, dir, headers) ->
                   (* Handle C part of library *)
                   flag ["link"; "library"; "ocaml"; "byte"; tag_libstubs lib]
                     (S[A"-dllib"; A("-l"^(nm_libstubs lib)); A"-cclib";
                        A("-l"^(nm_libstubs lib))]);

                   flag ["link"; "library"; "ocaml"; "native"; tag_libstubs lib]
                     (S[A"-cclib"; A("-l"^(nm_libstubs lib))]);

                   flag ["link"; "program"; "ocaml"; "byte"; tag_libstubs lib]
                     (S[A"-dllib"; A("dll"^(nm_libstubs lib))]);

                   (* When ocaml link something that use the C library, then one
                      need that file to be up to date.
                    *)
                   dep ["link"; "ocaml"; "program"; tag_libstubs lib]
                     [dir/"lib"^(nm_libstubs lib)^"."^(!Options.ext_lib)];

                   dep  ["compile"; "ocaml"; "program"; tag_libstubs lib]
                     [dir/"lib"^(nm_libstubs lib)^"."^(!Options.ext_lib)];

                   (* TODO: be more specific about what depends on headers *)
                   (* Depends on .h files *)
                   dep ["compile"; "c"]
                     headers;

                   (* Setup search path for lib *)
                   flag ["link"; "ocaml"; "use_"^lib]
                     (S[A"-I"; P(dir)]);
              )
              t.lib_c;

              (* Add flags *)
              List.iter
              (fun (tags, cond_specs) ->
                 let spec =
                   BaseEnvLight.var_choose cond_specs env
                 in
                   flag tags & spec)
              t.flags
        | _ ->
            ()


  let dispatch_default t =
    dispatch_combine
      [
        dispatch t;
        MyOCamlbuildFindlib.dispatch;
      ]


end


# 554 "myocamlbuild.ml"
open Ocamlbuild_plugin;;
let package_default =
  {
     MyOCamlbuildBase.lib_ocaml =
       [
          ("optcomp", ["syntax"], []);
          ("lwt", ["src/core"], []);
          ("lwt-log", ["src/logger"], []);
          ("lwt-unix", ["src/unix"], []);
          ("lwt-simple-top", ["src/simple_top"], []);
          ("lwt-react", ["src/react"], []);
          ("lwt-preemptive", ["src/preemptive"], []);
          ("lwt-extra", ["src/extra"], []);
          ("lwt-glib", ["src/glib"], []);
          ("lwt-ssl", ["src/ssl"], []);
          ("lwt-text", ["src/text"], []);
          ("lwt-top", ["src/top"], []);
          ("lwt-syntax", ["syntax"], []);
          ("lwt-syntax-options", ["syntax"], []);
          ("lwt-syntax-log", ["syntax"], []);
          ("test", ["tests"], [])
       ];
     lib_c =
       [
          ("lwt-unix",
            "src/unix",
            ["src/unix/lwt_config.h"; "src/unix/lwt_unix.h"]);
          ("lwt-glib", "src/glib", []);
          ("lwt-text", "src/text", [])
       ];
     flags =
       [
          (["oasis_library_lwt_unix_cclib"; "link"],
            [
               (OASISExpr.EBool true, S []);
               (OASISExpr.EAnd
                  (OASISExpr.ENot
                     (OASISExpr.EAnd
                        (OASISExpr.ETest ("os_type", "Win32"),
                          OASISExpr.ETest ("ccomp_type", "msvc"))),
                    OASISExpr.ETest ("os_type", "Win32")),
                 S [A "-cclib"; A "-lws2_32"]);
               (OASISExpr.EAnd
                  (OASISExpr.ETest ("os_type", "Win32"),
                    OASISExpr.ETest ("ccomp_type", "msvc")),
                 S [A "-cclib"; A "ws2_32.lib"]);
               (OASISExpr.EAnd
                  (OASISExpr.EAnd
                     (OASISExpr.ETest ("os_type", "Win32"),
                       OASISExpr.ETest ("ccomp_type", "msvc")),
                    OASISExpr.EAnd
                      (OASISExpr.ENot
                         (OASISExpr.EAnd
                            (OASISExpr.ETest ("os_type", "Win32"),
                              OASISExpr.ETest ("ccomp_type", "msvc"))),
                        OASISExpr.ETest ("os_type", "Win32"))),
                 S [A "-cclib"; A "ws2_32.lib"; A "-cclib"; A "-lws2_32"])
            ]);
          (["oasis_library_lwt_unix_cclib"; "ocamlmklib"; "c"],
            [
               (OASISExpr.EBool true, S []);
               (OASISExpr.EAnd
                  (OASISExpr.ENot
                     (OASISExpr.EAnd
                        (OASISExpr.ETest ("os_type", "Win32"),
                          OASISExpr.ETest ("ccomp_type", "msvc"))),
                    OASISExpr.ETest ("os_type", "Win32")),
                 S [A "-lws2_32"]);
               (OASISExpr.EAnd
                  (OASISExpr.ETest ("os_type", "Win32"),
                    OASISExpr.ETest ("ccomp_type", "msvc")),
                 S [A "ws2_32.lib"]);
               (OASISExpr.EAnd
                  (OASISExpr.EAnd
                     (OASISExpr.ETest ("os_type", "Win32"),
                       OASISExpr.ETest ("ccomp_type", "msvc")),
                    OASISExpr.EAnd
                      (OASISExpr.ENot
                         (OASISExpr.EAnd
                            (OASISExpr.ETest ("os_type", "Win32"),
                              OASISExpr.ETest ("ccomp_type", "msvc"))),
                        OASISExpr.ETest ("os_type", "Win32"))),
                 S [A "ws2_32.lib"; A "-lws2_32"])
            ])
       ];
     includes =
       [
          ("tests/unix", ["src/core"; "src/unix"; "tests"]);
          ("tests/react", ["src/core"; "src/react"; "src/unix"; "tests"]);
          ("tests/preemptive",
            ["src/core"; "src/preemptive"; "src/unix"; "tests"]);
          ("tests/core", ["src/core"; "src/unix"; "tests"]);
          ("tests", ["src/core"; "src/unix"]);
          ("src/unix", ["src/core"; "src/logger"]);
          ("src/top", ["src/core"; "src/react"; "src/text"]);
          ("src/text", ["src/core"; "src/react"; "src/unix"]);
          ("src/ssl", ["src/unix"]);
          ("src/simple_top", ["src/core"; "src/unix"]);
          ("src/react", ["src/core"]);
          ("src/preemptive", ["src/core"; "src/unix"]);
          ("src/logger", ["src/core"]);
          ("src/glib", ["src/core"; "src/unix"]);
          ("src/extra", ["src/core"; "src/preemptive"]);
          ("examples/unix", ["src/unix"; "syntax"])
       ]
  }
  ;;

let dispatch_default = MyOCamlbuildBase.dispatch_default package_default;;

# 666 "myocamlbuild.ml"
(* OASIS_STOP *)

open Ocamlbuild_plugin

let split str =
  let rec skip_spaces i =
    if i = String.length str then
      []
    else
      if str.[i] = ' ' then
        skip_spaces (i + 1)
      else
        extract i (i + 1)
  and extract i j =
    if j = String.length str then
      [String.sub str i (j - i)]
    else
      if str.[j] = ' ' then
        String.sub str i (j - i) :: skip_spaces (j + 1)
      else
        extract i (j + 1)
  in
  skip_spaces 0

let define_c_library name env =
  if BaseEnvLight.var_get name env = "true" then begin
    let tag = Printf.sprintf "use_C_%s" name in

    let opt = List.map (fun x -> A x) (split (BaseEnvLight.var_get (name ^ "_opt") env))
    and lib = List.map (fun x -> A x) (split (BaseEnvLight.var_get (name ^ "_lib") env)) in

    (* Add flags for linking with the C library: *)
    flag ["ocamlmklib"; "c"; tag] & S lib;

    (* C stubs using the C library must be compiled with the library
       specifics flags: *)
    flag ["c"; "compile"; tag] & S (List.map (fun arg -> S[A"-ccopt"; arg]) opt);

    (* OCaml libraries must depends on the C library: *)
    flag ["link"; "ocaml"; tag] & S (List.map (fun arg -> S[A"-cclib"; arg]) lib)
  end

let () =
  dispatch
    (fun hook ->
       dispatch_default hook;
       match hook with
         | Before_options ->
             Options.make_links := false

         | After_rules ->
             dep ["file:src/unix/lwt_unix_stubs.c"] ["src/unix/lwt_unix_unix.c"; "src/unix/lwt_unix_windows.c"];
             dep ["pa_optcomp"] ["src/unix/lwt_config.ml"];

             (* Internal syntax extension *)
             List.iter
               (fun base ->
                  let tag = "pa_" ^ base and file = "syntax/pa_" ^ base ^ ".cmo" in
                  flag ["ocaml"; "compile"; tag] & S[A"-ppopt"; A file];
                  flag ["ocaml"; "ocamldep"; tag] & S[A"-ppopt"; A file];
                  flag ["ocaml"; "doc"; tag] & S[A"-ppopt"; A file];
                  dep ["ocaml"; "ocamldep"; tag] [file])
               ["lwt_options"; "lwt"; "lwt_log"; "optcomp"];

             (* Optcomp for .mli *)
             flag ["ocaml"; "compile"; "pa_optcomp_standalone"] & S[A"-pp"; A "./syntax/optcomp.byte"];
             flag ["ocaml"; "ocamldep"; "pa_optcomp_standalone"] & S[A"-pp"; A "./syntax/optcomp.byte"];
             flag ["ocaml"; "doc"; "pa_optcomp_standalone"] & S[A"-pp"; A "./syntax/optcomp.byte"];
             dep ["ocaml"; "ocamldep"; "pa_optcomp_standalone"] ["syntax/optcomp.byte"];

             (* Use an introduction page with categories *)
             tag_file "lwt-api.docdir/index.html" ["apiref"];
             dep ["apiref"] ["apiref-intro"];
             flag ["apiref"] & S[A "-intro"; P "apiref-intro"; A"-colorize-code"];

             (* Stubs: *)
             let env = BaseEnvLight.load ~allow_empty:true ~filename:MyOCamlbuildBase.env_filename () in

             (* Check for "unix" because other variables are not
                present in the setup.data file if lwt.unix is
                disabled. *)
             if BaseEnvLight.var_get "unix" env = "true" then begin
               define_c_library "glib" env;
               define_c_library "libev" env;
               define_c_library "pthread" env;

               flag ["c"; "compile"; "use_lwt_headers"] & S [A"-ccopt"; A"-Isrc/unix"];

               (* With ocaml >= 4, toploop.cmi is not in the stdlib
                  path *)
               let ocaml_major_version = Scanf.sscanf (BaseEnvLight.var_get "ocaml_version" env) "%d" (fun x -> x) in
               if ocaml_major_version >= 4 then
                 List.iter
                   (fun stage -> flag ["ocaml"; stage; "use_toploop"] & S[A "-package"; A "compiler-libs.toplevel"])
                   ["compile"; "ocamldep"; "doc"];

               (* Toplevel stuff *)

               flag ["ocaml"; "link"; "toplevel"] & A"-linkpkg";

               let stdlib_path = BaseEnvLight.var_get "standard_library" env in

               (* Try to find the path where compiler libraries
                  are. *)
               let compiler_libs =
                 let stdlib = String.chomp stdlib_path in
                 try
                   let path =
                     List.find Pathname.exists [
                       stdlib / "compiler-libs";
                       stdlib / "compiler-lib";
                       stdlib / ".." / "compiler-libs";
                       stdlib / ".." / "compiler-lib";
                     ]
                   in
                   path :: List.filter Pathname.exists [ path / "typing"; path / "utils"; path / "parsing" ]
                 with Not_found ->
                   []
               in

               (* Add directories for compiler-libraries: *)
               let paths = List.map (fun path -> S[A"-I"; A path]) compiler_libs in
               List.iter
                 (fun stage -> flag ["ocaml"; stage; "use_compiler_libs"] & S paths)
                 ["compile"; "ocamldep"; "doc"; "link"];

               dep ["file:src/top/toplevel_temp.top"] ["src/core/lwt.cma";
                                                       "src/logger/lwt-log.cma";
                                                       "src/react/lwt-react.cma";
                                                       "src/unix/lwt-unix.cma";
                                                       "src/text/lwt-text.cma";
                                                       "src/top/lwt-top.cma"];

               flag ["file:src/top/toplevel_temp.top"] & S[A"-I"; A"src/unix";
                                                           A"-I"; A"src/text";
                                                           A"src/core/lwt.cma";
                                                           A"src/logger/lwt-log.cma";
                                                           A"src/react/lwt-react.cma";
                                                           A"src/unix/lwt-unix.cma";
                                                           A"src/text/lwt-text.cma";
                                                           A"src/top/lwt-top.cma"];

               (* Expunge compiler modules *)
               rule "toplevel expunge"
                 ~dep:"src/top/toplevel_temp.top"
                 ~prod:"src/top/lwt_toplevel.byte"
                 (fun _ _ ->
                    let directories =
                      stdlib_path
                      :: "src/core"
                      :: "src/react"
                      :: "src/unix"
                      :: "src/text"
                      :: "src/top"
                      :: (List.map
                            (fun lib ->
                               String.chomp
                                 (run_and_read
                                    ("ocamlfind query " ^ lib)))
                            ["findlib"; "react"; "unix"; "text"])
                    in
                    let modules =
                      List.fold_left
                        (fun set directory ->
                           List.fold_left
                             (fun set fname ->
                                if Pathname.check_extension fname "cmi" then
                                  StringSet.add (module_name_of_pathname fname) set
                                else
                                  set)
                             set
                             (Array.to_list (Pathname.readdir directory)))
                        StringSet.empty directories
                    in
                    Cmd(S[A(stdlib_path / "expunge");
                          A"src/top/toplevel_temp.top";
                          A"src/top/lwt_toplevel.byte";
                          A"outcometree"; A"topdirs"; A"toploop";
                          S(List.map (fun x -> A x) (StringSet.elements modules))]))
             end

         | _ ->
             ())

(* Compile the wiki version of the Ocamldoc.

   Thanks to Till Varoquaux on usenet:
   http://www.digipedia.pl/usenet/thread/14273/231/

*)

let ocamldoc_wiki tags deps docout docdir =
  let tags = tags -- "extension:html" in
  Ocamlbuild_pack.Ocaml_tools.ocamldoc_l_dir tags deps docout docdir

let () =
  try
    let wikidoc_dir =
      let base = Ocamlbuild_pack.My_unix.run_and_read "ocamlfind query wikidoc" in
      String.sub base 0 (String.length base - 1)
    in

    Ocamlbuild_pack.Rule.rule
      "ocamldoc: document ocaml project odocl & *odoc -> wikidocdir"
      ~insert:`top
      ~prod:"%.wikidocdir/index.wiki"
      ~stamp:"%.wikidocdir/wiki.stamp"
      ~dep:"%.odocl"
      (Ocamlbuild_pack.Ocaml_tools.document_ocaml_project
         ~ocamldoc:ocamldoc_wiki
         "%.odocl" "%.wikidocdir/index.wiki" "%.wikidocdir");

    tag_file "lwt-api.wikidocdir/index.wiki" ["apiref";"wikidoc"];
    flag ["wikidoc"] & S[A"-i";A wikidoc_dir;A"-g";A"odoc_wiki.cma"]

  with Failure e -> () (* Silently fail if the package wikidoc isn't available *)
