#lang racket
(require redex/reduction-semantics
         "../logic/instantiate.rkt"
         "../decl/env.rkt"
         "grammar.rkt"
         "prove-goal.rkt"
         )
(provide ✅-OverlapRules
         )

(define-judgment-form
  formality-check

  ;; The conditions under which an impl passes the orphan rules.

  #:mode (✅-OverlapRules I I)
  #:contract (✅-OverlapRules DeclProgram TraitImplDecl)

  [(where/error (impl _ (TraitId _) where _ _) TraitImplDecl)
   (where/error [TraitImplDecl_all ...] (all-impls-of-trait DeclProgram TraitId))
   (where #f (impl-appears-more-than-once [TraitImplDecl_all ...] TraitImplDecl))
   (✅-ImplsEqualOrNotOverlap DeclProgram TraitImplDecl TraitImplDecl_all) ...
   -------------------------------
   (✅-OverlapRules DeclProgram TraitImplDecl)]


  )

(define-judgment-form
  formality-check

  ;; The conditions under which an impl passes the orphan rules.

  #:mode (✅-ImplsEqualOrNotOverlap I I I)
  #:contract (✅-ImplsEqualOrNotOverlap DeclProgram TraitImplDecl TraitImplDecl)

  ;; Accept two impls if they are exactly equal:
  ;;
  ;; This is a bit surprising because two distinct, exactly equal impls overlap by definition.
  ;; The reason is that we are checking the 1st impl against every other impl in every crate
  ;; *including itself*. So if we see a comparison of two equal impls, we assume it is the
  ;; same impl being compared against itself for now. There is a separate check that you
  ;; cannot have two exactly equal impls (FIXME).
  [-------------------------------
   (✅-ImplsEqualOrNotOverlap DeclProgram TraitImplDecl TraitImplDecl)]

  [; we want to prove that `TraitImplDecl_1` and `TraitImplDecl_2` do not overlap
   ;
   ; Example: imagine impl 1 is...
   ;
   ; impl<T> Debug for Vec<T> where T: Debug
   ;
   ; * `KindedVarIds_1` will be `[(type T)]`
   ; * `TraitId` will be `Debug`
   ; * `Parameters_1` will be `[Vec<T>]`
   ; * `Biformulas_1` will be `T: Debug`
   (where/error (impl KindedVarIds_1 (TraitId Parameters_1) where Biformulas_1 _) TraitImplDecl_1)
   (where/error (impl KindedVarIds_2 (TraitId Parameters_2) where Biformulas_2 _) TraitImplDecl_2)

   ; get the base environment for the program
   (where/error Env_0 (env-for-decl-program DeclProgram))

   ; instantiate with inference variables
   ;
   ; for our example, we will create a inference variable `?T` in the the environment `Env_1`
   ; and get back...
   ;
   ; * `Parameters_1inf` will be `[Vec<?T>]`
   ; * `Biformulas_1` will be `?T: Debug`
   (where/error (Env_1 ([Parameter_1inf ...] [Biformula_1inf ...]) _)
                (instantiate-quantified Env_0 (∃ KindedVarIds_1 (Parameters_1 Biformulas_1))))

   ; ...same for impl 2.
   (where/error (Env_2 ([Parameter_2inf ...] [Biformula_2inf ...]) _)
                (instantiate-quantified Env_1 (∃ KindedVarIds_2 (Parameters_2 Biformulas_2))))

   ; This goal, if provable, indicates that overlap exists:
   ;
   ; * Parameters can be unified.
   ; * Where clauses from both impls hold.
   (where/error Goal_overlap (&& [(Parameter_1inf == Parameter_2inf) ...
                                  Biformula_1inf ...
                                  Biformula_2inf ...
                                  ]))

   ; We check that goal in *coherence mode*. In coherence mode, anything
   ; that may be possible in some future world (i.e., where other crates apart
   ; from the local crate add impls which they are allowed to add), becomes
   ; ambiguous. If we can prove that `Goal_overlap` is false in that mode,
   ; we know that there does not exist a future world where overlap is possible.
   (cannot-prove-goal-in-env Env_2 (coherence-mode Goal_overlap))
   -------------------------------
   (✅-ImplsEqualOrNotOverlap DeclProgram TraitImplDecl_1 TraitImplDecl_2)
   ]

  ; FIXME: add the negative impl cases etc

  )

(define-metafunction formality-check
  ;; Finds all impls of the given trait in any crate.
  all-impls-of-trait : DeclProgram TraitId -> [TraitImplDecl ...]

  [(all-impls-of-trait DeclProgram TraitId)
   [TraitImplDecl ... ...]

   ; get a list of all the crate items in any crate
   (where/error ([(crate _ [CrateItemDecl ...]) ...] _) DeclProgram)
   (where/error [CrateItemDecl_all ...] [CrateItemDecl ... ...])

   ; filter that down to just the trait impls
   (where/error [[TraitImplDecl ...] ...] [(select-trait-item CrateItemDecl_all TraitId) ...])
   ]
  )

(define-metafunction formality-check
  ;; Given a crate item, if the item is an impl of the given trait, return a 1-element list.
  ;; Else return an empty list.
  ;; Used for filtering.
  select-trait-item : CrateItemDecl TraitId -> [TraitImplDecl ...]

  [(select-trait-item TraitImplDecl TraitId)
   [TraitImplDecl]
   (where (impl _ (TraitId _) where _ _) TraitImplDecl)
   ]

  [(select-trait-item CrateItemDecl TraitId)
   []
   ]
  )

(define-metafunction formality-check
  ;; Given an impl decl and a list of existing impl decls, return true if that impl decl shows up more than once in the list.
  ;; Else return false.
  impl-appears-more-than-once : TraitImplDecls TraitImplDecl -> boolean

  [(impl-appears-more-than-once [_ ... TraitImplDecl _ ... TraitImplDecl _ ...] TraitImplDecl)
   #t
   ]
  [(impl-appears-more-than-once [_ ...] TraitImplDecl)
   #f
   ]
  )