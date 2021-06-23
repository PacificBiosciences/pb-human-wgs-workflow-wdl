"""
Calculate the "Phrank" phenotype match score for a list of phenotypes for every gene.
"""

from __future__ import division
import collections
import functools
import itertools
import math
import yaml
import argparse
import sys

__version__ = "1.0.0"


HpoTerm = collections.namedtuple("HpoTerm", ["id","name","definition"])
HpoAnnotation = collections.namedtuple("HpoAnnotation", ["term","gene","conditions"])

class Phenotyper:
    @staticmethod
    def term_closure(term_list, term_to_relatives):
        """Take the closure over a list of terms.  The closure is defined as the
        terms in the list and all its ancestors or descendants depending on the dag passed."""
        closure = set()

        def helper(term):
            # avoid retraversing a subtree
            if term not in closure:
                closure.add(term)
                for parent in term_to_relatives.get(term, set()):
                    helper(parent)

        # Traverse starting with each term in the term list
        for term in term_list:
            helper(term)
        return closure

    @staticmethod
    def canonicalize_annotations(term_to_parents, gene_to_annotations, term_to_annotations):
        # Take the "closure" over gene<->term annotations such that
        # if a gene is annotated with term T, it is also annotated with
        # all the ancestors of T up to the root of the DAG.
        for gene_id in gene_to_annotations:
            direct_terms = set([a.term for a in gene_to_annotations[gene_id].values()])
            closure = Phenotyper.term_closure(direct_terms, term_to_parents)

            # Add annotations for terms that are in the closure but not in the
            # directly annotated terms.
            for term_id in closure.difference(direct_terms):
                annotation = HpoAnnotation(term_id, gene_id, [])
                gene_to_annotations[gene_id][term_id] = annotation
                term_to_annotations[term_id][gene_id] = annotation
        return gene_to_annotations, term_to_annotations

    @staticmethod
    def compute_term_info_content(hpoterms, term_to_parents, gene_to_annotations, term_to_annotations):
        # Calculate the information content of each term.
        # We define two concepts of information content:
        #    1. "raw": the standard meaning -log2(<genes with term>/<annotated genes>)
        #    2. "marginal": the information content that a term contributes
        #       beyond the information content of its parent terms
        annotatedGeneCt = len(gene_to_annotations)
        termRawIc = dict()
        for term in hpoterms.values():
            annotations = term_to_annotations.get(term.id,[])
            # If term is not annotated, its raw ic is 0 (or Infinity, but that would mess things up so set to 0)
            termRawIc[term.id] = -math.log(len(annotations)/annotatedGeneCt)/math.log(2) if len(annotations) else 0

        # Define marginal information content as the raw information content of a term
        # minus the raw information content of a meta-term that has a gene list that is
        # the intersection of the gene lists of the parents of the term.  The intersection
        # of the gene lists for the parent terms is guaranteed to be at least as large as
        # the gene list of the term itself because of closure.
        termMarginalIc = dict()
        for term in hpoterms.values():
            if term.id not in term_to_annotations:
                termMarginalIc[term.id] = 0
            else:
                parentTerms = term_to_parents.get(term.id, [])
                if len(parentTerms) == 0:
                    parentIc = 0
                else:
                    parentGeneSets = [set([a.gene for g,a in term_to_annotations[t].items()]) for t in parentTerms]
                    parentIntersection = functools.reduce(lambda a,b: a.intersection(b), parentGeneSets)
                    parentIc = -math.log(len(parentIntersection)/annotatedGeneCt)/math.log(2)
                termMarginalIc[term.id] = termRawIc[term.id] - parentIc

        return termMarginalIc

    def __init__ (self, termsfile, dagfile, annotationsfile):
        """Initialize the phenotyper with HPO terms, DAG, and gene<->term annotations."""

        # terms
        self._hpoTerms = {}
        f = open(termsfile)
        for l in f:
            (term_id, term_name, term_defn) = l.rstrip("\n").split("\t")
            self._hpoTerms[term_id] = HpoTerm(term_id,term_name,term_defn)
        f.close()

        # bottom-up DAG (child to parents) and top-down DAGs (parent to children)
        self._buHpoDag = collections.defaultdict(list)
        self._tdHpoDag = collections.defaultdict(list)
        f = open(dagfile)
        for l in f:
            (child_id, parent_id) = l.rstrip("\n").split("\t")
            self._buHpoDag[child_id].append(parent_id)
            self._tdHpoDag[parent_id].append(child_id)

        # gene<->terms annotations and term<->genes annotations
        self._hpoGeneToAnnotations = collections.defaultdict(dict)
        self._hpoTermToAnnotations = collections.defaultdict(dict)
        f = open(annotationsfile)
        for l in f:
            (gene_id, term_id, conditions) = l.rstrip("\n").split("\t")
            annotation = HpoAnnotation(term_id, gene_id, conditions.split(","))
            self._hpoGeneToAnnotations[gene_id][term_id] = annotation
            self._hpoTermToAnnotations[term_id][gene_id] = annotation
        f.close()
        Phenotyper.canonicalize_annotations(self._buHpoDag, self._hpoGeneToAnnotations,self._hpoTermToAnnotations)

        self._termMarginalIc = Phenotyper.compute_term_info_content(self._hpoTerms, self._buHpoDag,
                                                                    self._hpoGeneToAnnotations, self._hpoTermToAnnotations)


    def term_ancestor_closure(self, term_list):
        """Take the closure over a list of terms.  The closure is defined as the
        terms in the list and all ancestors up to the root of the DAG."""
        return Phenotyper.term_closure(term_list, self._buHpoDag)

    def term_descendant_closure(self, term_list):
        """Identify all of the terms in term list or its descendants down
        to the leaves in the DAG."""
        return Phenotyper.term_closure(term_list, self._tdHpoDag)

    def _phenotype_information(self, term_list):
        """Find the information content of a list of terms, which is the sum
        of the marginal information of the terms in the closure of the term list."""
        return sum([self._termMarginalIc.get(t,0) for t in self.term_ancestor_closure(term_list)])

    def phenotype_score(self, term_list1, term_list2):
        """Find the information content shared by two term lists, which is the
        information content of a term list that is the intersection of the closures of
        the two term lists."""
        return self._phenotype_information(self.term_ancestor_closure(term_list1).intersection(self.term_ancestor_closure(term_list2)))

    def all_gene_scores(self, term_list=None, facet_by_condition=False):
        """Return a map from gene ID to the information content shared by the
        term list and the annotations applied to the gene, for all annotated genes.

        If no term_list is passed, then we return the max score for all the genes
        """
        gene_facet_scores = dict()
        for g,annotations in self._hpoGeneToAnnotations.items():
            gene_facet_terms = dict()
            gene_facet_terms[(g,None)] = set(annotations.keys())

            # define facets
            if facet_by_condition:
                for a in annotations.values():
                    for s in a.conditions:
                        gene_facet_terms.setdefault((g,s), set()).add(a.term)

            # compute scores
            for (facet, facet_terms) in gene_facet_terms.items():
                (g, s) = facet
                gene_facet_scores.setdefault(s, {})[g] = self.phenotype_score(term_list if term_list is not None else facet_terms,
                                                                             facet_terms)

        return gene_facet_scores if facet_by_condition else gene_facet_scores[None]

    def hpoTermDict(self, hpoId):
        """Return a dictionary that lists details about an HPO term."""
        return {
            "hpoId": hpoId,
            "name": self._hpoTerms[hpoId].name,
            "defn": self._hpoTerms[hpoId].definition,
            "genesWithTerm": len(self._hpoTermToAnnotations.get(hpoId,[]))
        }


    def geneAnnotations(self, geneId):
        return [a for a in self._hpoGeneToAnnotations.get(geneId,{}).values()]


    def pruneTerms(self, termList):
        """Prune a list of terms to only include "leaf" terms that do not have
        a descendant on the list.  This provides a minimal representation such
        that closure(pruneTerms(termList))==closure(termList)."""
        prune = set() # set of terms to prune
        def helper(term):
            # Mark a term and its ancestors for pruning,
            # if it has not already been pruned.
            if term not in prune:
                prune.add(term)
                for p in self._buHpoDag.get(term,[]):
                    helper(p)

        closure = self.term_ancestor_closure(termList)
        for term in closure:
            for p in self._buHpoDag.get(term,[]):
                helper(p)

        return closure.difference(prune)


def main(args):
    phenotyper = Phenotyper(args.hpo_terms_tsv, args.hpo_dag_tsv, args.ensembl_to_hpo_tsv)

    yamlfile = open(args.cohortyaml, 'r')
    cohort_list = yaml.load("".join(yamlfile))
    yamlfile.close()

    cohort = None
    for c in cohort_list:
        if c['id'] == args.cohortid:
            cohort = c
    if not cohort:
        sys.exit("Cohort %s not found in %s." % (args.cohortid, args.cohortyaml))

    phenotypes = cohort.get("phenotypes", [])
    ensembl_to_hgnc = dict()
    f = open(args.ensembl_to_hgnc)
    for l in f:
        ensg,hgnc = l.rstrip("\n").split("\t")
        ensembl_to_hgnc[ensg] = hgnc
    f.close()

    fout = open(args.phrank_out_tsv, "w")
    genescores = phenotyper.all_gene_scores(phenotypes)
    hgncscores = dict()
    for ensg in sorted(genescores.keys()):
        hgnc = ensembl_to_hgnc.get(ensg, ensg)
        hgncscores[hgnc] = max(genescores[ensg], hgncscores.get(hgnc, 0))
    for hgnc in sorted(hgncscores.keys()):
        fout.write("%s\t%0.3f\n" % (hgnc, hgncscores[hgnc]))
    fout.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter)

    # Required positional argument
    parser.add_argument("hpo_terms_tsv", help="HPO terms and definitions", type=str)
    parser.add_argument("hpo_dag_tsv", help="HPO DAG structure (child to parent)", type=str)
    parser.add_argument("ensembl_to_hpo_tsv", help="Map from Ensembl genes to HPO terms", type=str)
    parser.add_argument("ensembl_to_hgnc", help="Map from Ensembl gene ID to HGNC gene symbol", type=str)
    parser.add_argument("cohortyaml", help="100Humans cohort yaml file", type=str)
    parser.add_argument("cohortid", help="cohort id", type=str)
    parser.add_argument("phrank_out_tsv", help="Phrank scores: <gene_symbol><TAB><phrank_score>", type=str)

    # Specify output of "--version"
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    main(args)
