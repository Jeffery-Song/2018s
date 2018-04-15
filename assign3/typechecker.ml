open Core
open Ast.IR

exception TypeError of string
exception Unimplemented

(* Checks that a type is legal. *)
let rec typecheck_type (tenv : String.Set.t) (tau : Type.t) : Type.t =
  match tau with
   | Type.Var x ->
     if Set.mem tenv x then tau
     else raise (TypeError (Printf.sprintf "Unbound type variable %s" x))
   | Type.Product (t1, t2) -> Type.Product (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.Sum (t1, t2) -> Type.Sum (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.Fn (t1, t2) -> Type.Fn (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.ForAll(s, t1) -> Type.ForAll(s, typecheck_type (String.Set.add tenv s) t1)
   | Type.Exists(s, t1) -> Type.Exists(s, typecheck_type (String.Set.add tenv s) t1)
   | Type.Int -> tau

(* You need to implement the statics for the remaining cases below.
 * We have provided you with implementations of the other cases that you may
 * refer to.
 *
 * Note that you'll have to use OCaml sets to do this assignment. The semantics
 * for sets will be similar to maps. Like Maps, Sets are also immutable, so
 * any result from a set function will be different from the source. You may
 * find the functions Set.add and Set.find to be useful, in addition to others.
 *)
let rec typecheck_term (tenv : String.Set.t) (env : Type.t String.Map.t) (t : Term.t) : Type.t =
  match t with
  | Term.Int _ -> Type.Int

  | Term.Var x -> (
      match (String.Map.find env x) with
      | Some _type -> (typecheck_type tenv _type) 
      | None -> raise (TypeError "Does not typecheck 01")
    )

  | Term.Lam (x, arg_tau, body) -> (
      let arg_tau_type = typecheck_type tenv arg_tau in
      let new_map = String.Map.add env ~key:x ~data:arg_tau_type in
      Type.Fn(arg_tau_type, typecheck_term tenv new_map body)
    )

  | Term.App (fn, arg) -> (
      let tau1 = typecheck_term tenv env fn in
      let tau2 = typecheck_term tenv env arg in
      match (tau1, tau2) with
      | (Type.Fn (type_a, type_b), type_c) -> (
          if Type.aequiv type_a type_c then type_b
          else raise (TypeError "Does not typecheck 03")
        )
      | _ -> raise (TypeError "Does not typecheck 05")
    )

  | Term.Binop (_, t1, t2) -> (
      let tau1 = typecheck_term tenv env t1 in
      let tau2 = typecheck_term tenv env t2 in
      match (tau1, tau2) with
      | (Type.Int, Type.Int) -> Type.Int
      | _ -> raise (TypeError "binop should be used to int type")
    )

  | Term.Tuple (t1, t2) -> (
      let tau1 = typecheck_term tenv env t1 in
      let tau2 = typecheck_term tenv env t2 in
      Type.Product(tau1, tau2)
    )

  | Term.Project (t, dir) -> (
      let tau = typecheck_term tenv env t in
      match tau with
      | Type.Product (type1, type2) -> (
          if dir = Ast.Left then (typecheck_type tenv type1)
          else if dir = Ast.Right then (typecheck_type tenv type2)
          else raise (TypeError "cannot recognize this direction")
        )
      | _ -> raise (TypeError "cannot apply direction to a none-product term")
    )

  | Term.Inject (arg, dir, sum_tau) -> (
      let tau1 = typecheck_term tenv env arg in
      let tau2 = typecheck_type tenv sum_tau in
      match (tau1, tau2) with
      | (type1, Type.Sum (type2, type3)) -> (
          if dir = Ast.Left then (
            if Type.aequiv type1 type2 then tau2
            else raise (TypeError "Inject type error")
          ) else if dir = Ast.Right then (
            if Type.aequiv type1 type3 then tau2
            else raise (TypeError "Inject type error")
          ) else raise (TypeError "cannot recognize direction")
        )
      | _ -> raise (TypeError "cannot apply inject to non-product type")
    )

  | Term.Case (switch, (x1, t1), (x2, t2)) -> (
      let tau = typecheck_term tenv env switch in
      match tau with
      | Type.Sum (type1, type2) -> (
          let tau1 = typecheck_term tenv (String.Map.add env ~key:x1 ~data:type1) t1 in
          let tau2 = typecheck_term tenv (String.Map.add env ~key:x2 ~data:type2) t2 in
          if Type.aequiv tau1 tau2 then tau1
          else raise (TypeError "two cases's result should be the same")
        )
      | _ -> raise (TypeError "case should be applied on sum type")


      (* let tau1 = typecheck_term tenv env x1 in
      let tau2 = typecheck_term tenv env x2 in
      (* let tau2 = String.Map.find env x2 in *)
      let tau3 = typecheck_term tenv env t1 in
      let tau4 = typecheck_term tenv env t2 in
      let tau = typecheck_term tenv env switch in
      match (tau1, tau2, tau3, tau4, tau) with
      | (type1, type2, type3, type4, Type.Sum (type5, type6)) -> (
          if Type.aequiv type3 type4 then (
            if Type.aequiv type5 type1 then type3
            else if Type.aequiv type6 type2 then type3
            else raise (TypeError "neither case matchs")
          ) else (
            raise (TypeError "two cases's result should be the same")
          )
        )
      | _ -> raise (TypeError "case should be applied on sum type") *)
    )

  | Term.TLam (x, t) -> (
      let tau1 = typecheck_term (String.Set.add tenv x) env t in
      Type.ForAll (x, tau1)
    )

  | Term.TApp (t, arg_tau) -> (
      let tau1 = typecheck_term tenv env t in
      let tau2 = typecheck_type tenv arg_tau in
      match tau1 with
      | Type.ForAll (s1, t1) -> (
          Type.substitute s1 tau2 t1
          (* s1 is the name of type var, t1 is the area with s1 inside, now replace s1 with tau2 *)
        )
      | _ -> raise (TypeError "error")
  )

  | Term.TPack (abstracted_tau, t, existential_type) -> (
      (* t is substitute result, abs is tau', exist is tau *)
      let tau_t = typecheck_term tenv env t in
      let tau_abs = typecheck_type tenv abstracted_tau in
      let tau_exist = typecheck_type tenv existential_type in
      match (tau_t, tau_exist, tau_abs) with 
      | (type1, Type.Exists (s, type2), type3) -> (
          if Type.aequiv type1 (Type.substitute s type3 type2) then
            Type.Exists (s, type2)
          else raise (TypeError "error")
        )
      | _ -> raise (TypeError "error")
      (* verify  *)
    )

  | Term.TUnpack (xty, xterm, arg, body) -> (
      let tau1 = typecheck_term tenv env arg in
      match tau1 with
      | Type.Exists (s, type1) -> (
          if s = xty then (
            typecheck_term (String.Set.add tenv xty) (String.Map.add env xterm type1) body
          ) else raise (TypeError "unmatch package name")
        )
      | _ -> raise (TypeError "wrong arg type")
      (* let tau2 = typecheck_term tenv env xterm in *)


    )

let typecheck t =
  try Ok (typecheck_term String.Set.empty String.Map.empty t)
  with TypeError s -> Error s

let inline_tests () =
  (* Typechecks Pack and Unpack*)
  let exist =
    Type.Exists("Y", Type.Int)
  in
  let pack =
    Term.TPack(Type.Int, Term.Int 5, exist)
  in
  let unpack =
    Term.TUnpack("Y", "y", pack, Term.Var "y")
  in
  assert(typecheck unpack = Ok(Type.Int));

  (* Typecheck Inject *)
  let inj =
    Term.Inject(Term.Int 5, Ast.Left, Type.Sum(Type.Int, Type.Int))
  in
  assert (typecheck inj = Ok(Type.Sum(Type.Int, Type.Int)));

  (* Typechecks Tuple *)
  let tuple =
    Term.Tuple(((Int 3), (Int 4)))
  in
  assert (typecheck tuple = Ok(Type.Product(Type.Int, Type.Int)));

  (* Typechecks Case *)
  let inj =
    Term.Inject(Term.Int 5, Ast.Left, Type.Sum(Type.Int, Type.Product(Type.Int, Type.Int)))
  in
  let case1 = ("case1", Term.Int 8)
  in
  let case2 = ("case2", Term.Int 0)
  in
  let switch = Term.Case(inj, case1, case2)
  in
  assert (typecheck switch = Ok(Type.Int));

  (* Inline Tests from Assignment 3 *)
  let t1 = Term.Lam ("x", Type.Int, Term.Var "x") in
  assert (typecheck t1 = Ok(Type.Fn(Type.Int, Type.Int)));

  let t2 = Term.Lam ("x", Type.Int, Term.Var "y") in
  assert (Result.is_error (typecheck t2));

  let t3 = Term.App (t1, Term.Int 3) in
  assert (typecheck t3 = Ok(Type.Int));

  let t4 = Term.App (t3, Term.Int 3) in
  assert (Result.is_error (typecheck t4));

  let t5 = Term.Binop (Ast.Add, Term.Int 0, t1) in
  assert (Result.is_error (typecheck t5))

let () = inline_tests ()
