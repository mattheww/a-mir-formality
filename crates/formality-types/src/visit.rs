use std::sync::Arc;

use crate::{
    collections::Set,
    grammar::{Lt, Parameter, Ty, Universe, Variable},
};

/// Invoked for each variable that we find when Visiting, ignoring variables bound by binders
/// that we traverse. The arguments are as follows:
///
/// * ParameterKind -- the kind of term in which the variable appeared (type vs lifetime, etc)
/// * Variable -- the variable we encountered
pub type SubstitutionFn<'a> = &'a mut dyn FnMut(Variable) -> Option<Parameter>;

pub trait Visit: Sized {
    /// Extract the list of free variables (for the purposes of this function, defined by `Variable::is_free`).
    /// The list may contain duplicates and must be in a determinstic order (though the order itself isn't important).
    fn free_variables(&self) -> Vec<Variable>;

    /// Measures the overall size of the term by counting constructors etc.
    /// Used to determine overflow.
    fn size(&self) -> usize;

    /// True if this term references only placeholder variables.
    /// This means that it contains no inference variables.
    /// If this is a goal, then when we prove it true, we don't expect any substitution.
    /// This is similar, but not *identical*, to the commonly used term "ground term",
    /// which in Prolog refers to a term that contains no variables. The difference here
    /// is that the term may contain variables, but only those instantiated universally (∀).
    fn references_only_placeholder_variables(&self) -> bool {
        self.free_variables().iter().all(|v| match v {
            Variable::PlaceholderVar(_) => true,
            Variable::InferenceVar(_) => false,
            Variable::BoundVar(_) => false,
        })
    }

    /// Maximum universe of of any placeholders appearing in this term
    fn max_universe(&self) -> Universe {
        self.free_variables()
            .iter()
            .map(|v| match v {
                Variable::PlaceholderVar(p) => p.universe,
                Variable::InferenceVar(_) => Universe::ROOT,
                Variable::BoundVar(_) => Universe::ROOT,
            })
            .max()
            .unwrap_or(Universe::ROOT)
    }
}

impl<T: Visit> Visit for Vec<T> {
    fn free_variables(&self) -> Vec<Variable> {
        self.iter().flat_map(|e| e.free_variables()).collect()
    }

    fn size(&self) -> usize {
        self.iter().map(|e| e.size()).sum()
    }
}

impl<T: Visit + Ord> Visit for Set<T> {
    fn free_variables(&self) -> Vec<Variable> {
        self.iter().flat_map(|e| e.free_variables()).collect()
    }

    fn size(&self) -> usize {
        self.iter().map(|e| e.size()).sum()
    }
}

impl<T: Visit> Visit for Option<T> {
    fn free_variables(&self) -> Vec<Variable> {
        self.iter().flat_map(|e| e.free_variables()).collect()
    }

    fn size(&self) -> usize {
        self.as_ref().map(|e| e.size()).unwrap_or(0)
    }
}

impl<T: Visit> Visit for Arc<T> {
    fn free_variables(&self) -> Vec<Variable> {
        T::free_variables(self)
    }

    fn size(&self) -> usize {
        T::size(self)
    }
}

impl Visit for Ty {
    fn free_variables(&self) -> Vec<Variable> {
        self.data().free_variables()
    }

    fn size(&self) -> usize {
        self.data().size()
    }
}

impl Visit for Lt {
    fn free_variables(&self) -> Vec<Variable> {
        self.data().free_variables()
    }

    fn size(&self) -> usize {
        self.data().size()
    }
}

impl Visit for usize {
    fn free_variables(&self) -> Vec<Variable> {
        vec![]
    }

    fn size(&self) -> usize {
        1
    }
}

impl Visit for u32 {
    fn free_variables(&self) -> Vec<Variable> {
        vec![]
    }

    fn size(&self) -> usize {
        1
    }
}

impl<A: Visit, B: Visit> Visit for (A, B) {
    fn free_variables(&self) -> Vec<Variable> {
        let (a, b) = self;
        let mut fv = vec![];
        fv.extend(a.free_variables());
        fv.extend(b.free_variables());
        fv
    }

    fn size(&self) -> usize {
        let (a, b) = self;
        a.size() + b.size()
    }
}

impl<A: Visit, B: Visit, C: Visit> Visit for (A, B, C) {
    fn free_variables(&self) -> Vec<Variable> {
        let (a, b, c) = self;
        let mut fv = vec![];
        fv.extend(a.free_variables());
        fv.extend(b.free_variables());
        fv.extend(c.free_variables());
        fv
    }

    fn size(&self) -> usize {
        let (a, b, c) = self;
        a.size() + b.size() + c.size()
    }
}

impl<A: Visit> Visit for &A {
    fn free_variables(&self) -> Vec<Variable> {
        A::free_variables(self)
    }

    fn size(&self) -> usize {
        A::size(self)
    }
}
