(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module AcCompletion : sig
  type insert_replace_edit = {
    newText: string;
    insert: Loc.t;
    replace: Loc.t;
  }

  type completion_item = {
    kind: Lsp.Completion.completionItemKind option;
    name: string;
    labelDetail: string option;  (** LSP's CompletionItemLabelDetails.detail *)
    description: string option;  (** LSP's CompletionItemLabelDetails.description *)
    itemDetail: string option;  (** LSP's CompletionItem.detail *)
    text_edit: insert_replace_edit option;
    additional_text_edits: (Loc.t * string) list;
    sort_text: string option;
    preselect: bool;
    documentation_and_tags: (string option * Lsp.CompletionItemTag.t list option) Lazy.t;
    log_info: string;
    insert_text_format: Lsp.Completion.insertTextFormat;
  }

  type t = {
    items: completion_item list;
    is_incomplete: bool;
  }
end

type ac_options = {
  imports: bool;
  imports_min_characters: int;
  imports_ranked_usage: bool;
  imports_ranked_usage_boost_exact_match_min_length: int option;
  show_ranking_info: bool;
}

type 'r ac_result = {
  result: 'r;
  errors_to_log: string list;
}

type typing

val mk_typing_artifacts :
  layout_options:Js_layout_generator.opts ->
  loc_of_aloc:(ALoc.t -> Loc.t) ->
  get_ast_from_shared_mem:(File_key.t -> (Loc.t, Loc.t) Flow_ast.Program.t option) ->
  module_system_info:Lsp_module_system_info.t ->
  search_exported_values:(ac_options:ac_options -> string -> Export_search_types.search_results) ->
  search_exported_types:(ac_options:ac_options -> string -> Export_search_types.search_results) ->
  cx:Context.t ->
  file_sig:File_sig.t ->
  ast:(Loc.t, Loc.t) Flow_ast.Program.t ->
  available_ast:Typed_ast_utils.available_ast ->
  typing

type 'r autocomplete_service_result_generic =
  | AcResult of 'r ac_result
  | AcEmpty of string
  | AcFatalError of string

type autocomplete_service_result = AcCompletion.t autocomplete_service_result_generic

val autocomplete_get_results :
  typing ->
  ac_options ->
  string option ->
  Loc.t ->
  string option * ALoc.t option * string * autocomplete_service_result
