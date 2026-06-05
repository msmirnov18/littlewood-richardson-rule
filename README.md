# Littlewood-Richardson Rule

SageMath implementation of the Littlewood-Richardson rule for partial flag varieties G/P, relying on **jeu de taquin**, based on the papers:

- P.-E. Chaput, N. Perrin, *On the quantum cohomology of adjoint varieties*, Proc. Lond. Math. Soc. (3) **103** (2011), no. 2, 294–330. [doi:10.1112/plms/pdq052](https://doi.org/10.1112/plms/pdq052)
- H. Thomas, A. Yong, *A combinatorial rule for (co)minuscule Schubert calculus*, Adv. Math. **222** (2009), no. 2, 596–620. [doi:10.1016/j.aim.2009.05.008](https://doi.org/10.1016/j.aim.2009.05.008)

Precomputed Schubert bases are included for D6/P6, E6/P1, E6/P2, E7/P1, E7/P7, and E8/P8.

## Usage

```python
# Cohomology of the Grassmannian Gr(2, 5)  (type A4, parabolic node 2)
X = CohomologyPartialFlagVariety("A4", (2,))

s1, s2 = X.schubert_basis[1], X.schubert_basis[2]
X.cup_product(X.module(s1), X.module(s2))
```

## Requirements

[SageMath](https://www.sagemath.org/) 9.0 or later.