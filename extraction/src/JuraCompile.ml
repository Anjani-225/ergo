(*
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *)

open Util
open JComp
open JuraConfig

type result_file = {
    res_file : string;
    res_content : string;
  }

let parse_jura file_content =
  ParseString.parse_jura_from_string file_content
let parse_jurac file_content =
  ParseString.parse_jurac_sexp_from_string file_content

let compile_jura_to_javascript coname clname jura =
  let coname = Util.char_list_of_string coname in
  let clname = Util.char_list_of_string clname in
  let code = JuraCompiler.clause_code_from_jura_package coname clname jura in
  begin match code with
  | None -> None
  | Some code -> Some (Util.string_of_char_list code)
  end

let compile_jura_to_calculus jura =
  let cal = JuraCompiler.jura_calculus_package_from_jura_package jura in
  Some (SExp.sexp_to_string (AstsToSExp.jurac_package_to_sexp cal))

let compile_calculus_to_javascript coname clname jurac =
  let coname = Util.char_list_of_string coname in
  let clname = Util.char_list_of_string clname in
  let code = JuraCompiler.clause_code_from_jurac_package coname clname jurac in
  begin match code with
  | None -> None
  | Some code -> Some (Util.string_of_char_list code)
  end

let compile_package_calculus_to_javascript jurac =
  Some (Util.string_of_char_list
	  (JuraCompiler.javascript_from_jurac_package jurac))

let compile_package_to_javascript jura =
  Some (Util.string_of_char_list
	  (JuraCompiler.javascript_from_jura_package jura))

let force_contract_clause_names coname clname =
  begin match coname, clname with
  | Some coname, Some clname -> (coname, clname)
  | _ -> raise (Jura_Error "JavaScript target currently requires a contract name and a clause name")
  end

let compile source target coname clname file_content =
  begin match source,target with
  | _,Jura -> raise (Jura_Error "Target language cannot be Jura")
  | JavaScript,_ -> raise (Jura_Error "Source language cannot be JavaScript")
  | Calculus,Calculus -> raise (Jura_Error "Source and target language have to be different")
  | Jura,JavaScript ->
      let jura_parsed = parse_jura file_content in
      begin match coname,clname with
      | Some coname, Some clname ->
	  compile_jura_to_javascript coname clname jura_parsed
      | None, Some _ | Some _, None | None, None ->
	  compile_package_to_javascript jura_parsed
      end
  | Jura,Calculus ->
      let jura_parsed = parse_jura file_content in
      compile_jura_to_calculus jura_parsed
  | Calculus,JavaScript ->
      let jurac_parsed = parse_jurac file_content in
      begin match coname,clname with
      | Some coname, Some clname ->
	  compile_calculus_to_javascript coname clname jurac_parsed
      | None, Some _ | Some _, None | None, None ->
	  compile_package_calculus_to_javascript jurac_parsed
      end
  end

let make_result_file target_lang source_file s =
  let fpref = Filename.chop_extension source_file in
  let ext = extension_of_lang target_lang in
  let fout = outname (target_f None fpref) ext in
  { res_file = fout;
    res_content = s; }

let jura_compile gconf file_content =
  let source_lang = JuraConfig.get_source_lang gconf in
  let target_lang = JuraConfig.get_target_lang gconf in
  let contract_name =  JuraConfig.get_contract_name gconf in
  let clause_name =  JuraConfig.get_clause_name gconf in
  begin match compile source_lang target_lang contract_name clause_name file_content with
  | None -> raise (Jura_Error "Error during compilation\n")
  | Some code -> code
  end

let jura_proc gconf (file_name,file_content) =
  let target_lang = JuraConfig.get_target_lang gconf in
  let result = jura_compile gconf file_content in
  make_result_file target_lang file_name result

