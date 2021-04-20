# Add a description


class CohomologyPartialFlagVariety:
    def __init__(self, dynkin, parabolic, base=QQ):

        self.root_system = RootSystem(CartanType(dynkin))
        self.root_lattice = self.root_system.root_lattice()
        self.weyl_group = self.root_lattice.weyl_group(prefix="s")

        self.parabolic = tuple(sorted(set(parabolic)))
        assert set(self.parabolic).issubset(self.root_system.index_set()), \
                "parabolic subgroup must be specified by a subset of the index set of the root system"
        self.nonparabolic = tuple([j for j in CartanType(dynkin).index_set() if j not in parabolic])


        # the underlying module of cohomology over the base, freely generated by Schubert classes
        if dynkin in precomputed:
            if parabolic in precomputed[dynkin]:
                self.schubert_basis = [self.weyl_group.from_reduced_word(item) for item in precomputed[dynkin][parabolic]]

        else:
            self.schubert_basis = list(set([w.coset_representative(self.nonparabolic) for w in self.weyl_group]))
            self.schubert_basis = sorted(self.schubert_basis, key=lambda s: s.length())

        self.module = CombinatorialFreeModule(base, self.schubert_basis)

        self.dimension = max(w.length() for w in self.schubert_basis)

        for w in self.schubert_basis:
            if w.length() == self.dimension:
                self.point_class = self.module.monomial(w)



    def __repr__(self):
        """Description of the cohomology ring"""
        return "Cohomology ring for %s / P_%s: \n%s" % \
                (self.root_system.cartan_type(), self.parabolic, self.root_system.dynkin_diagram())


    def cup_product(self, element_one, element_two):

        # check if the algorithm is applicable (cominusculity) !!!
        # check input

        nonparabolic_positive_roots = self.root_lattice.nonparabolic_positive_roots(self.nonparabolic)

        LambdaGP = self.root_lattice.root_poset().subposet(nonparabolic_positive_roots)

        straight_shapes = [w.inversions(inversion_type = 'roots') for w in self.schubert_basis]

        # Straight shapes, as defined above, are subsets of the set of positive roots. We store them as lists.
        # In fact they are subsets of LambdaGP!
        # A skew shape is a set-theoretic difference of straight shapes. We store them as lists as well.
        # A standard filling of a (skew) shape, as in Thomas-Yong, is a bijective labelling of the elements of
        # shape by number 1, 2, 3, ... compatible with the partial order on LambdaGP.
        # These labelled skew shapes are called standard tableaux.
        # To work with such labellings, i.e. with standard tableaux, we proceed as follows:
        # Every standard tableau is stored in a dictionary, whose keys are always LambdaGP.
        # The labelling is extended to the whole LambdaGP by zero values


        # given a dictionary as described above (defining a standard tableau),
        # we want to get back the skew shape, i.e. throw away keys with zero values
        def skew_shape(T):

            # check input (input should be a dictionary with keys in LambdaGP)

            return [alpha for alpha in T.keys() if T.get(alpha) != 0]


        # given a standard tableau T, need to find the boxes that can be used in the Jeu De Taquin
        def list_of_allowed_x(T):

            # check input (input should be a dictionary with keys in LambdaGP)

            output = []

            for alpha in skew_shape(T):
                for beta in LambdaGP.lower_covers(alpha):
                    if LambdaGP.unwrap(beta) not in skew_shape(T):
                        if LambdaGP.unwrap(beta) not in output:
                            output.append(LambdaGP.unwrap(beta))

            return output


        # jeu de taquin slide of T into x
        # this process takes several steps (page 3 in the preprint)
        def jeu_de_taquin(T,x):

            assert x in list_of_allowed_x(T), 'not allowed x in jdt'

            output = T.copy()

            candidates_for_y = [alpha for alpha in skew_shape(T) if alpha in [LambdaGP.unwrap(beta) for beta in LambdaGP.upper_covers(x)]]

            while len(candidates_for_y) > 0:
                # taking as new y the element with the minimal label (as on page 3 of [Thomas-Yong])
                inverted_filling = {value: key for key, value in T.items()}
                y = inverted_filling.get(min([T.get(alpha) for alpha in candidates_for_y]))

                output.update({x : output.get(y)})
                output.update({y : 0})

                x = y

                candidates_for_y = [alpha for alpha in skew_shape(T) if alpha in [LambdaGP.unwrap(beta) for beta in LambdaGP.upper_covers(x)]]

            return output


        # checking if the undelying skew shape is straight
        def is_straight_shape(T):

            for shape in straight_shapes:
                if set(shape) == set(skew_shape(T)):
                    return True

            else: return False


        # if the undelying skew shape is straight, returning this straight shape
        def straight_shape(T):

            assert is_straight_shape(T), 'T is not of straight shape'

            for shape in straight_shapes:
                if set(shape) == set(skew_shape(T)):
                    return shape


        def rectification(T):

            if is_straight_shape(T) == True:
                return T

            else: return rectification(jeu_de_taquin(T,list_of_allowed_x(T)[-1]))


        def standard_tableaux(S):

            output = []

            TT = dict([tuple([alpha,0]) for alpha in nonparabolic_positive_roots])

            for item in LambdaGP.subposet(S).linear_extensions():
                # for i in range(len(S)):
                T = dict([tuple([item.to_poset().unwrap(item[i]), i+1]) for i in range(len(S))])
                TT.update(T)
                output.append(TT.copy())
            return output


        # Computes the Littlewood--Richardson coefficient c_{\lambda, \mu}^{\nu} using
        # the Main Theorem (on page 4) of [Thomas-Yong]. As input we give straight_shapes
        # \lambda, \mu, \nu (denoted by L, M, N respectively).
        def lrcoeff(L,M,N):

            assert L in straight_shapes
            assert M in straight_shapes
            assert N in straight_shapes

            result = 0

            if set(L).issubset(set(N)):

                # fixing the standard tableau T_{\mu} of shape \mu (as in the Theorem)
                Tmu = standard_tableaux(M)[0]
                # print(Tmu)

                # looping over the standard tableaux of shape \nu/\lambda
                for S in standard_tableaux([alpha for alpha in N if alpha not in L]):
                    if rectification(S) == Tmu: result = result + 1

            return result


        # if element_one or element_two is zero we are done
        if element_one.is_zero() or element_two.is_zero():
            return self.module.zero()

        # if element_one is a sum of at least two monomials we recurse
        if len(element_one.monomials()) > 1:
            term_one = element_one.leading_term()
            return self.cup_product(term_one, element_two) + self.cup_product(element_one - term_one, element_two)

        # if element_two is a sum of at least two monomials we recurse
        if len(element_two.monomials()) > 1:
            term_two = element_two.leading_term()
            return self.cup_product(element_one, term_two) + self.cup_product(element_one, element_two - term_two)

        # now we can apply the Littlewood-Richardson rule
        a = element_one.leading_support()
        b = element_two.leading_support()

        output = self.module.zero()

        for c in self.schubert_basis:
            if c.length() == a.length() + b.length():
                output = output + lrcoeff(a.inversions(inversion_type = 'roots'), b.inversions(inversion_type = 'roots'), c.inversions(inversion_type = 'roots'))*self.module(c)

        return element_one.leading_coefficient()*element_two.leading_coefficient()*output

    def poincare_dual(self, element):

        # check input

        # if element is zero we are done
        if element.is_zero():
            return self.module.zero()

        # if element is a sum of at least two monomials we recurse
        if len(element.monomials()) > 1:
            term = element.leading_term()
            return self.poincare_dual(term) + self.poincare_dual(element - term)

        for w in self.schubert_basis:
            if w.length() == self.dimension - element.leading_support().length():
                if self.cup_product(element.leading_monomial(), self.module.monomial(w)) == self.point_class:
                    output = element.leading_coefficient()*self.module.monomial(w)

        return output









# precomputed Schubert bases for complicated examples
precomputed = dict()

precomputed["E7"] = dict()

precomputed["E7"][(7,)] = [
[],
[7],
[6, 7],
[5, 6, 7],
[4, 5, 6, 7],
[3, 4, 5, 6, 7],
[2, 4, 5, 6, 7],
[1, 3, 4, 5, 6, 7],
[3, 2, 4, 5, 6, 7],
[4, 3, 2, 4, 5, 6, 7],
[1, 3, 2, 4, 5, 6, 7],
[5, 4, 3, 2, 4, 5, 6, 7],
[4, 1, 3, 2, 4, 5, 6, 7],
[3, 4, 1, 3, 2, 4, 5, 6, 7],
[5, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 5, 4, 3, 2, 4, 5, 6, 7],
[5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 5, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 6, 5, 4, 3, 2, 4, 5, 6, 7],
[6, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 6, 5, 4, 1, 3, 2, 4, 5, 6, 7],
[2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 6, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[5, 6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7],
[7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7]
]

precomputed["E8"] = dict()

precomputed["E8"][(8,)] = [
[],
[8],
[7, 8],
[6, 7, 8],
[5, 6, 7, 8],
[4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 7, 8],
[3, 2, 4, 5, 6, 7, 8],
[1, 3, 2, 4, 5, 6, 7, 8],
[4, 3, 2, 4, 5, 6, 7, 8],
[4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 4, 3, 2, 4, 5, 6, 7, 8],
[5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 5, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 6, 5, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 6, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 6, 7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 6, 7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 6, 7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 6, 7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 5, 6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 5, 6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 5, 6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 8, 2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 8, 2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 8, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 8, 3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 7, 8, 2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 8, 3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 8, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 7, 8, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 2, 4, 5, 6, 7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 2, 4, 5, 6, 7, 8, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 2, 4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 2, 4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 3, 2, 4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 1, 3, 2, 4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 1, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 1, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 4, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 4, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 5, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 5, 6, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8],
[8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8, 7, 6, 5, 4, 3, 2, 4, 5, 6, 7, 1, 3, 4, 5, 6, 2, 4, 5, 3, 4, 1, 3, 2, 4, 5, 6, 7, 8]
]
