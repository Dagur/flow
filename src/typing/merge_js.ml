(*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

let detect_sketchy_null_checks cx =
  let add_error ~loc ~null_loc kind falsy_loc =
    Error_message.ESketchyNullLint { kind; loc; null_loc; falsy_loc } |> Flow_js.add_output cx
  in
  let detect_function exists_excuses loc exists_check =
    ExistsCheck.(
      let exists_excuse =
        Loc_collections.ALocMap.find_opt loc exists_excuses |> Base.Option.value ~default:empty
      in
      match exists_check.null_loc with
      | None -> ()
      | Some null_loc ->
        let add_error = add_error ~loc ~null_loc in
        if Base.Option.is_none exists_excuse.bool_loc then
          Base.Option.iter exists_check.bool_loc ~f:(add_error Lints.SketchyNullBool);
        if Base.Option.is_none exists_excuse.number_loc then
          Base.Option.iter exists_check.number_loc ~f:(add_error Lints.SketchyNullNumber);
        if Base.Option.is_none exists_excuse.bigint_loc then
          Base.Option.iter exists_check.bigint_loc ~f:(add_error Lints.SketchyNullBigInt);
        if Base.Option.is_none exists_excuse.string_loc then
          Base.Option.iter exists_check.string_loc ~f:(add_error Lints.SketchyNullString);
        if Base.Option.is_none exists_excuse.mixed_loc then
          Base.Option.iter exists_check.mixed_loc ~f:(add_error Lints.SketchyNullMixed);
        if Base.Option.is_none exists_excuse.enum_bool_loc then
          Base.Option.iter exists_check.enum_bool_loc ~f:(add_error Lints.SketchyNullEnumBool);
        if Base.Option.is_none exists_excuse.enum_number_loc then
          Base.Option.iter exists_check.enum_number_loc ~f:(add_error Lints.SketchyNullEnumNumber);
        if Base.Option.is_none exists_excuse.enum_bigint_loc then
          Base.Option.iter exists_check.enum_bigint_loc ~f:(add_error Lints.SketchyNullEnumBigInt);
        if Base.Option.is_none exists_excuse.enum_string_loc then
          Base.Option.iter exists_check.enum_string_loc ~f:(add_error Lints.SketchyNullEnumString);
        ()
    )
  in
  let exists_checks =
    let open Loc_collections in
    let open ExistsCheck in
    let checks = Context.exists_checks cx in
    if not @@ ALocMap.is_empty checks then
      let rec make_checks seen cur_checks loc t =
        let open Type in
        let open TypeUtil in
        let open Reason in
        match t with
        | AnnotT (_, t, _) -> make_checks seen cur_checks loc t
        | OpenT (_, id) when ISet.mem id seen -> cur_checks
        | OpenT (_, id) ->
          Context.find_resolved cx t
          |> Base.Option.value_map
               ~f:(make_checks (ISet.add id seen) cur_checks loc)
               ~default:cur_checks
        (* Ignore AnyTs for sketchy null checks; otherwise they'd always trigger the lint. *)
        | AnyT _ -> cur_checks
        | GenericT { bound = t; _ }
        | OpaqueT (_, { underlying_t = Some t; _ })
        | OpaqueT (_, { underlying_t = None; super_t = Some t; _ }) ->
          make_checks seen cur_checks loc t
        | MaybeT (r, t) ->
          let acc = make_checks seen cur_checks loc t in
          let acc = make_checks seen acc loc (NullT.why r (Trust.bogus_trust ())) in
          make_checks seen acc loc (VoidT.why r (Trust.bogus_trust ()))
        | OptionalT { reason = r; type_ = t; _ } ->
          let acc = make_checks seen cur_checks loc t in
          make_checks seen acc loc (VoidT.why r (Trust.bogus_trust ()))
        | UnionT (_, rep) ->
          UnionRep.members rep
          |> Base.List.fold ~f:(fun acc t -> make_checks seen acc loc t) ~init:cur_checks
        | _ ->
          let t_loc =
            let reason = reason_of_t t in
            match annot_loc_of_reason reason with
            | Some loc -> Some loc
            | None -> Some (def_loc_of_reason reason)
          in
          let exists_check =
            ALocMap.find_opt loc cur_checks |> Base.Option.value ~default:ExistsCheck.empty
          in
          let exists_check =
            match Type_filter.maybe cx t with
            | DefT (_, _, EmptyT) -> exists_check
            | _ -> { exists_check with null_loc = t_loc }
          in
          let exists_check =
            match t |> Type_filter.not_exists cx |> Type_filter.not_maybe cx with
            | DefT (_, _, BoolT _) -> { exists_check with bool_loc = t_loc }
            | DefT (_, _, StrT _) -> { exists_check with string_loc = t_loc }
            | DefT (_, _, NumT _) -> { exists_check with number_loc = t_loc }
            | DefT (_, _, BigIntT _) -> { exists_check with bigint_loc = t_loc }
            | DefT (_, _, MixedT _) -> { exists_check with mixed_loc = t_loc }
            | DefT (_, _, EnumT { representation_t = DefT (_, _, BoolT _); _ }) ->
              { exists_check with enum_bool_loc = t_loc }
            | DefT (_, _, EnumT { representation_t = DefT (_, _, StrT _); _ }) ->
              { exists_check with enum_string_loc = t_loc }
            | DefT (_, _, EnumT { representation_t = DefT (_, _, NumT _); _ }) ->
              { exists_check with enum_number_loc = t_loc }
            | DefT (_, _, EnumT { representation_t = DefT (_, _, BigIntT _); _ }) ->
              { exists_check with enum_bigint_loc = t_loc }
            | _ -> exists_check
          in
          if exists_check = ExistsCheck.empty then
            cur_checks
          else
            ALocMap.add loc exists_check cur_checks
      in

      ALocMap.fold
        (fun loc tset acc ->
          Type.TypeSet.fold (fun t acc -> make_checks ISet.empty acc loc t) tset acc)
        checks
        ALocMap.empty
    else
      ALocMap.empty
  in

  Loc_collections.ALocMap.iter (detect_function (Context.exists_excuses cx)) exists_checks

let detect_test_prop_misses cx =
  let misses = Context.test_prop_get_never_hit cx in
  Base.List.iter
    ~f:(fun (prop_name, (reason_prop, reason_obj), use_op, suggestion) ->
      Flow_js.add_output
        cx
        (Error_message.EPropNotFound { prop_name; reason_prop; reason_obj; use_op; suggestion }))
    misses

let detect_unnecessary_optional_chains cx =
  Base.List.iter
    ~f:(fun (loc, lhs_reason) ->
      Flow_js.add_output cx (Error_message.EUnnecessaryOptionalChain (loc, lhs_reason)))
    (Context.unnecessary_optional_chains cx)

let detect_unnecessary_invariants cx =
  Base.List.iter
    ~f:(fun (loc, reason) ->
      Flow_js.add_output cx (Error_message.EUnnecessaryInvariant (loc, reason)))
    (Context.unnecessary_invariants cx)

let detect_unused_promises cx =
  Base.List.iter
    ~f:(fun (loc, t, async) ->
      let no_lowers r = Type.(AnyT.make Untyped r) in
      let t = Tvar_resolver.resolved_t ~no_lowers cx t in
      Flow_js.flow
        cx
        ( t,
          Type.CheckUnusedPromiseT
            { reason = Reason.mk_reason (Reason.RCustom "unused promise lint") loc; async }
        ))
    (Context.maybe_unused_promises cx)

let detect_es6_import_export_errors = Strict_es6_import_export.detect_errors

let detect_non_voidable_properties cx =
  (* This function approximately checks whether VoidT can flow to the provided
   * type without actually creating the flow so as not to disturb type inference.
   * Even though this is happening post-merge, it is possible to encounter an
   * unresolved tvar, in which case it conservatively returns false.
   *)
  let rec is_voidable seen_ids =
    Type.(
      function
      | OpenT (_, id) ->
        (* tvar is recursive: conservatively assume it is non-voidable *)
        if ISet.mem id seen_ids then
          false
        else (
          match Flow_js_utils.possible_types cx id with
          (* tvar has no lower bounds: we conservatively assume it's non-voidable
           * except in the special case when it also has no upper bounds
           *)
          | [] -> Flow_js_utils.possible_uses cx id = []
          (* tvar is resolved: look at voidability of the resolved type *)
          | [t] -> is_voidable (ISet.add id seen_ids) t
          (* tvar is unresolved: conservatively assume it is non-voidable *)
          | _ -> false
        )
      (* a union is voidable if any of its members are voidable *)
      | UnionT (_, rep) -> UnionRep.members rep |> List.exists (is_voidable seen_ids)
      (* an intersection is voidable if all of its members are voidable *)
      | IntersectionT (_, rep) -> InterRep.members rep |> List.for_all (is_voidable seen_ids)
      (* trivially voidable *)
      | MaybeT _
      | DefT (_, _, (VoidT | MixedT (Mixed_everything | Mixed_non_null)))
      | OptionalT _
      | AnyT _ ->
        true
      (* conservatively assume all other types are non-voidable *)
      | _ -> false
    )
  in
  let check_properties (property_map : Type.Properties.id) :
      ALoc.t Property_assignment.error list SMap.t -> unit =
    let pmap = Context.find_props cx property_map in
    SMap.iter (fun name errors ->
        let should_error =
          match NameUtils.Map.find_opt (Reason.OrdinaryName name) pmap with
          | Some (Type.Field { type_ = t; _ }) -> not @@ is_voidable ISet.empty t
          | _ -> true
        in
        if should_error then
          List.iter
            (fun { Property_assignment.loc; desc } ->
              Flow_js.add_output cx (Error_message.EUninitializedInstanceProperty (loc, desc)))
            errors
    )
  in
  List.iter
    (fun {
           Context.public_property_map;
           private_property_map;
           errors = { Property_assignment.public_property_errors; private_property_errors };
         } ->
      check_properties public_property_map public_property_errors;
      check_properties private_property_map private_property_errors)
    (Context.voidable_checks cx)

let detect_matching_props_violations cx =
  let open Type in
  let peek =
    let open Type in
    let rec loop cx acc seen t =
      match t with
      | OpenT (_, id) ->
        let (root_id, constraints) = Context.find_constraints cx id in
        if ISet.mem root_id seen then
          acc
        else
          let seen = ISet.add root_id seen in
          (match constraints with
          | Constraint.Resolved t
          | Constraint.FullyResolved (lazy t) ->
            loop cx acc seen t
          | Constraint.Unresolved bounds ->
            let ts = TypeMap.keys bounds.Constraint.lower in
            List.fold_left (fun a t -> loop cx a seen t) acc ts)
      | AnnotT (_, t, _) -> loop cx acc seen t
      | _ -> List.rev (t :: acc)
    in
    (fun cx t -> loop cx [] ISet.empty t)
  in
  let is_lit t =
    match drop_generic t with
    | DefT (_, _, (BoolT (Some _) | StrT (Literal _) | NumT (Literal _))) -> true
    | _ -> false
  in
  let matching_props_checks =
    Base.List.filter_map (Context.matching_props cx) ~f:(fun (prop_name, other_loc, obj_loc) ->
        let env = Context.environment cx in
        Type_env.check_readable cx Env_api.ExpressionLoc other_loc;
        let sentinel =
          Base.Option.value_exn (Loc_env.find_write env Env_api.ExpressionLoc other_loc)
        in
        match peek cx sentinel with
        (* Limit the check to promitive literal sentinels *)
        | [t] when is_lit t ->
          let obj_t = Type_env.provider_type_for_def_loc cx env obj_loc in
          Some (TypeUtil.reason_of_t sentinel, prop_name, sentinel, obj_t)
        | _ -> None
    )
  in
  let step (reason, key, sentinel, obj) =
    let use_op =
      Op
        (MatchingProp
           {
             op = reason;
             obj = TypeUtil.reason_of_t obj;
             key;
             sentinel_reason = TypeUtil.reason_of_t sentinel;
           }
        )
    in
    (* If `obj` is a GenericT, we replace it with it's upper bound, since ultimately it will flow into
       `sentinel` rather than the other way around. *)
    Flow_js.flow cx (MatchingPropT (reason, key, sentinel), UseT (use_op, drop_generic obj))
  in
  Base.List.iter ~f:step matching_props_checks

let detect_literal_subtypes =
  let open Type in
  let no_lowers _cx r = Type.Unsoundness.merged_any r in
  let rec unwrap = function
    | GenericT { bound; _ } -> unwrap bound
    | t -> t
  in
  fun cx ->
    let checks = Context.literal_subtypes cx in
    List.iter
      (fun (loc, check) ->
        let env = Context.environment cx in
        let u_def =
          match Type_env.provider_type_for_def_loc cx env loc with
          | OpenT (r, id) -> Flow_js_utils.merge_tvar ~filter_empty:true ~no_lowers cx r id
          | t -> t
        in
        let u_def = unwrap u_def in
        let l =
          match check with
          | Env_api.SingletonNum (lit_loc, sense, num, raw) ->
            let reason = lit_loc |> Reason.(mk_reason (RNumberLit raw)) in
            DefT (reason, bogus_trust (), NumT (Literal (Some sense, (num, raw))))
          | Env_api.SingletonBool (lit_loc, b) ->
            let reason = lit_loc |> Reason.(mk_reason (RBooleanLit b)) in
            DefT (reason, bogus_trust (), BoolT (Some b))
          | Env_api.SingletonStr (lit_loc, sense, str) ->
            let reason = lit_loc |> Reason.(mk_reason (RStringLit (OrdinaryName str))) in
            DefT (reason, bogus_trust (), StrT (Literal (Some sense, Reason.OrdinaryName str)))
        in
        let use_op =
          Op
            (RefinementCheck
               { test = TypeUtil.reason_of_t l; discriminant = TypeUtil.reason_of_t u_def }
            )
        in
        Flow_js.flow cx (l, UseT (use_op, u_def)))
      checks

let check_constrained_writes cx =
  let prepare_checks ~resolve_t checks =
    Base.List.map
      ~f:(fun (t, use_op, u_def) ->
        let open Type in
        let open Constraint in
        let u_def = resolve_t u_def in
        let (mk_use_op, use_op) =
          let rec loop = function
            | Frame ((ConstrainedAssignment _ as frame), op) ->
              (TypeUtil.mod_use_op_of_use_t (fun op -> Frame (frame, op)), op)
            | Op _ as op -> ((fun x -> x), op)
            | Frame (frame, op) ->
              let (f, op) = loop op in
              (f, Frame (frame, op))
          in
          loop use_op
        in
        let u = UseT (use_op, u_def) in
        match t with
        | OpenT (_, id) ->
          let (_, constraints) = Context.find_constraints cx id in
          begin
            match constraints with
            | Unresolved { lower; _ } ->
              TypeMap.bindings lower
              |> Base.List.map ~f:(fun (t, (_, use_op)) ->
                     let t = resolve_t t in
                     (t, mk_use_op (Flow_js.flow_use_op cx use_op u))
                 )
            | Resolved _
            | FullyResolved _ ->
              let t = resolve_t t in
              [(t, mk_use_op (Flow_js.flow_use_op cx unknown_use u))]
          end
        | _ ->
          let t = resolve_t t in
          [(t, mk_use_op u)])
      checks
    |> List.flatten
  in

  let checks = Context.constrained_writes cx in
  if not @@ Base.List.is_empty checks then (
    let (cx, checks) = (cx, prepare_checks ~resolve_t:(fun t -> t) checks) in
    Base.List.iter ~f:(Flow_js.flow cx) checks;
    let new_errors = Context.errors cx in
    Flow_error.ErrorSet.iter (Context.add_error cx) new_errors
  )

let validate_renders_type_arguments cx =
  let open Type in
  let open Reason in
  let rec validate_component_in_element loc renders_variant invalid_type_reason = function
    | DefT (_, _, PolyT { tparams_loc; tparams; t_out; id = _ }) ->
      let subst_map =
        tparams
        |> Nel.to_list
        |> Base.List.fold ~init:Subst_name.Map.empty ~f:(fun acc tparam ->
               Subst_name.Map.add tparam.name (Unsoundness.at Unchecked tparams_loc) acc
           )
      in
      validate_component_in_element
        loc
        renders_variant
        invalid_type_reason
        (Type_subst.subst cx subst_map t_out)
    | DefT (_, _, ReactAbstractComponentT { component_kind = Nominal _; _ }) -> ()
    | _ ->
      Flow_js_utils.add_output
        cx
        Error_message.(
          EInvalidRendersTypeArgument
            {
              loc;
              renders_variant;
              invalid_render_type_kind = InvalidRendersNonNonimalElement;
              invalid_type_reasons = Nel.one invalid_type_reason;
            }
        )
  in
  let validate_element ~allow_generic loc renders_variant = function
    | GenericT { reason; _ } ->
      if allow_generic then
        ()
      else
        Flow_js_utils.add_output
          cx
          Error_message.(
            EInvalidRendersTypeArgument
              {
                loc;
                renders_variant;
                invalid_render_type_kind = InvalidRendersGenericT;
                invalid_type_reasons = Nel.one reason;
              }
          );
      None
    | OpaqueT (r, { opaque_id; opaque_type_args = (_, _, component_t, _) :: _; _ })
      when Flow_js_utils.builtin_react_element_opaque_id cx = Some opaque_id ->
      Flow_js.possible_concrete_types_for_inspection cx r component_t
      |> Base.List.iter ~f:(validate_component_in_element loc renders_variant r);
      None
    | DefT (invalid_type_reason, _, BoolT (Some false))
    | DefT (invalid_type_reason, _, SingletonBoolT false)
    | DefT (invalid_type_reason, _, NullT)
    | DefT (invalid_type_reason, _, VoidT) ->
      Some (invalid_type_reason, `InvalidRendersNullVoidFalse)
    | DefT (invalid_type_reason, _, ArrT _) -> Some (invalid_type_reason, `InvalidRendersIterable)
    | t ->
      let r = TypeUtil.reason_of_t t in
      if
        Flow_js.FlowJs.speculative_subtyping_succeeds
          cx
          t
          (Flow_js.get_builtin_typeapp
             cx
             r
             (OrdinaryName "$Iterable")
             [AnyT.error r; AnyT.error r; AnyT.error r]
          )
      then
        Some (r, `InvalidRendersIterable)
      else (
        Flow_js_utils.add_output
          cx
          Error_message.(
            EInvalidRendersTypeArgument
              {
                loc;
                renders_variant;
                invalid_render_type_kind = UncategorizedInvalidRenders;
                invalid_type_reasons = Nel.one r;
              }
          );
        None
      )
  in
  let validate_arg (loc, renders_variant, allow_generic, t) =
    Tvar_resolver.resolve cx t;
    Flow_js.possible_concrete_types_for_inspection
      cx
      (mk_reason (RCustom "render type argument") loc)
      t
    |> Base.List.fold ~init:None ~f:(fun acc t ->
           match (acc, validate_element ~allow_generic loc renders_variant t) with
           | (None, None) -> None
           | (None, Some (r, k)) -> Some (Nel.one r, k)
           | (Some (rs, k), None) -> Some (rs, k)
           | (Some (rs, k1), Some (r, k2)) ->
             let k =
               match (k1, k2) with
               | (`InvalidRendersNullVoidFalse, `InvalidRendersNullVoidFalse) ->
                 `InvalidRendersNullVoidFalse
               | (`InvalidRendersIterable, `InvalidRendersIterable)
               | (`InvalidRendersIterable, `InvalidRendersNullVoidFalse)
               | (`InvalidRendersNullVoidFalse, `InvalidRendersIterable) ->
                 `InvalidRendersIterable
             in
             Some (Nel.cons r rs, k)
       )
    |> Base.Option.iter ~f:(fun (invalid_type_reasons, kind) ->
           Flow_js_utils.add_output
             cx
             Error_message.(
               EInvalidRendersTypeArgument
                 {
                   loc;
                   renders_variant;
                   invalid_render_type_kind =
                     (match kind with
                     | `InvalidRendersNullVoidFalse -> Error_message.InvalidRendersNullVoidFalse
                     | `InvalidRendersIterable -> Error_message.InvalidRendersIterable);
                   invalid_type_reasons;
                 }
             )
       )
  in
  Context.renders_type_argument_validations cx |> Base.List.iter ~f:validate_arg

let get_lint_severities metadata strict_mode lint_severities =
  if metadata.Context.strict || metadata.Context.strict_local then
    StrictModeSettings.fold
      (fun lint_kind lint_severities ->
        LintSettings.set_value lint_kind (Severity.Err, None) lint_severities)
      strict_mode
      lint_severities
  else
    lint_severities

(* Post-merge errors.
 *
 * At this point, all dependencies have been merged and the component has been
 * linked together. Any constraints should have already been evaluated, which
 * means we can complain about things that either haven't happened yet, or
 * which require complete knowledge of tvar bounds.
 *)
let post_merge_checks cx ast metadata =
  check_constrained_writes cx;
  validate_renders_type_arguments cx;
  detect_sketchy_null_checks cx;
  detect_non_voidable_properties cx;
  detect_test_prop_misses cx;
  detect_unnecessary_optional_chains cx;
  detect_unnecessary_invariants cx;
  detect_es6_import_export_errors cx ast metadata;
  detect_matching_props_violations cx;
  detect_literal_subtypes cx;
  detect_unused_promises cx

let optimize_builtins cx =
  let reducer =
    let no_lowers _ r = Type.AnyT (r, Type.AnyError (Some Type.UnresolvedName)) in
    new Context_optimizer.context_optimizer ~no_lowers
  in
  let builtins = Context.builtins cx in
  Builtins.optimize_entries builtins ~optimize:(reducer#type_ cx Polarity.Neutral);
  Context.set_graph cx reducer#get_reduced_graph;
  Context.set_trust_graph cx reducer#get_reduced_trust_graph;
  Context.set_property_maps cx reducer#get_reduced_property_maps;
  Context.set_call_props cx reducer#get_reduced_call_props;
  Context.set_export_maps cx reducer#get_reduced_export_maps;
  Context.set_evaluated cx reducer#get_reduced_evaluated

let merge_lib_files ~sig_opts ~ccx ~metadata ordered_asts =
  let (_builtin_errors, builtin_locs, builtins) =
    Type_sig_utils.parse_and_pack_builtins sig_opts ordered_asts
  in
  match ordered_asts with
  | [] -> (builtins, None)
  | fst_ast :: _ ->
    let file_key = Base.Option.value_exn (fst_ast |> fst |> Loc.source) in
    let cx =
      Context.make
        ccx
        metadata
        file_key
        (lazy (ALoc.empty_table file_key))
        (fun mref -> Error (Reason.InternalModuleName mref))
        Context.InitLib
    in
    let global_names = Type_sig_merge.merge_builtins cx file_key builtin_locs builtins in
    NameUtils.Map.iter (fun name t -> Flow_js.set_builtin cx name t) global_names;
    (builtins, Some cx)
