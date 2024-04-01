(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

module LocMap = Loc_collections.LocMap
module ALocFuzzyMap = Loc_collections.ALocFuzzyMap

let map_of_fixable_missing_local_params cx =
  let all_errors = Context.errors cx in
  let aloc_tables = Context.aloc_tables cx in
  let missing_local_annot_lower_bounds = Context.missing_local_annot_lower_bounds cx in
  let add_fixable_missing_local_annot_loc err acc =
    match Flow_error.msg_of_error err with
    | Error_message.EMissingLocalAnnotation _ ->
      Base.Option.fold
        ~f:(fun acc aloc ->
          let loc = ALoc.to_loc_with_tables aloc_tables aloc in
          match ALocFuzzyMap.find_opt aloc missing_local_annot_lower_bounds with
          | None -> acc
          | Some (t1, ts) ->
            let reason = TypeUtil.reason_of_t t1 in
            let t =
              match ts with
              | [] -> t1
              | t2 :: ts -> Type.UnionT (reason, Type.UnionRep.make t1 t2 ts)
            in
            LocMap.add loc t acc)
        (Flow_error.loc_of_error err)
        ~init:acc
    | _ -> acc
  in
  Flow_error.ErrorSet.fold add_fixable_missing_local_annot_loc all_errors LocMap.empty

let fix_missing_param_annot_at_loc
    ?remote_converter ~cx ~loc_of_aloc ~get_ast ~get_haste_name ~get_type_sig ~file_sig ~typed_ast =
  let open Insert_type in
  insert_type_t
    ~cx
    ~loc_of_aloc
    ~get_ast
    ~get_haste_name
    ~get_type_sig
    ~file_sig
    ~typed_ast
    ?remote_converter
    ~omit_targ_defaults:false
    ~strict:false
    ~ambiguity_strategy:Autofix_options.Generalize

let fix_all_missing_param_annot_errors_in_file
    ?remote_converter ~cx ~loc_of_aloc ~get_ast ~get_haste_name ~get_type_sig ~file_sig ~typed_ast =
  let open Insert_type in
  let fixable_locs = map_of_fixable_missing_local_params cx in
  let fix_one_loc =
    insert_type_t
      ~cx
      ~loc_of_aloc
      ~get_ast
      ~get_haste_name
      ~get_type_sig
      ~file_sig
      ~typed_ast
      ?remote_converter
      ~omit_targ_defaults:false
      ~strict:false
      ~ambiguity_strategy:Autofix_options.Generalize
  in
  LocMap.fold (fun loc t ast -> fix_one_loc ast loc t) fixable_locs
