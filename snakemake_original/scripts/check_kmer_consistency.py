#!/usr/bin/env python3
"""
Measure the consistency of non-reference kmers between
all pairs of provided kmer counts.  Typically each kmer
count file is from a SMRT Cell.  The kmers presents in
different SMRT Cells from the same sample should be consistent
with each other.  It is preferred that kmer counts be filtered
to only report modimers.
"""


__version__ = "0.1.0"


import argparse
import gzip
import io

def readQualityFromBaseQuality(baseQuals):
    # Compute read quality from an array of base qualities; cap at Q60
    readLen = len(baseQuals)
    expectedErrors = sum([math.pow(10, -0.1*x) for x in baseQuals])
    return min(60,math.floor(-10*math.log10(expectedErrors/readLen)))


def main(args):
    # Read the reference kmers/modimers
    refkmers = set()
    f = io.TextIOWrapper(gzip.open(args.ref_kmers_tsv))
    for l in f:
        kmer,count = l.rstrip("\n").split()
        count = int(count)
        refkmers.add(kmer)
    refk = len(kmer)
    f.close()

    # Read the kmers for each sample
    datasetkmers = list()
    for ds in args.dataset_kmers_tsv:
        f = io.TextIOWrapper(gzip.open(ds))
        allkmers = set()
        solidkmers = set() # kmers supported by at least 5 reads
        for l in f:
            kmer,count = l.rstrip("\n").split()
            count = int(count)
            allkmers.add(kmer)
            if count >= 5:
                solidkmers.add(kmer)
        f.close()

        datasetkmers.append((allkmers,solidkmers))


    # For each pair of datasets, count the number of shared and unique
    # reference and non-reference kmers.  Use the count of unique reference
    # kmers to adjust for undersampling (i.e. low coverage) since they are
    # likely shared between any two humans.
    print("movieA\tmovieB\tadjusted_nonref_inconsistency\tconsistent")
    for ds1ix in range(len(args.dataset_kmers_tsv)):
        movie1 = args.dataset_kmers_tsv[ds1ix].split("/")[-1].split(".")[0]
        ds1_allkmers,ds1_solidkmers = datasetkmers[ds1ix]
        for ds2ix in range(ds1ix+1, len(args.dataset_kmers_tsv)):
            movie2 = args.dataset_kmers_tsv[ds2ix].split("/")[-1].split(".")[0]
            ds2_allkmers,ds2_solidkmers = datasetkmers[ds2ix]

            # kmers solid in at least one dataset
            solidkmers = ds1_solidkmers.union(ds2_solidkmers)
            # "shared" kmers solid in at least one dataset and present in both
            sharedsolidkmers = solidkmers.intersection(ds1_allkmers).intersection(ds2_allkmers)
            # "unique" kmers solid in one dataset and absent in the other
            uniquekmers = solidkmers.difference(sharedsolidkmers)
            # all "shared" kmers whether or not they are solid
            sharedkmers = ds1_allkmers.intersection(ds2_allkmers)

            # count separately for reference and non-reference kmers
            ref_shared = len(sharedkmers.intersection(refkmers))
            ref_unique = len(uniquekmers.intersection(refkmers))
            refkmer_inconsistency = 0 if ref_unique == 0 else ref_unique / (ref_shared + ref_unique)
            nonref_shared = len(sharedkmers.difference(refkmers))
            nonref_unique = len(uniquekmers.difference(refkmers))
            nonrefkmer_inconsistency = 0 if nonref_unique == 0 else nonref_unique / (nonref_shared + nonref_unique)

            # output adjusted kmer consistency (nonref - ref)
            adjusted_nonrefkmer_inconsistency = max(0, nonrefkmer_inconsistency - refkmer_inconsistency)
            print("%s\t%s\t%0.5f\t%s" % (movie1, movie2, adjusted_nonrefkmer_inconsistency, "YES" if adjusted_nonrefkmer_inconsistency < 0.03 else "NO"))

if __name__ == "__main__":
    """ This is executed when run from the command line """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ref_kmers_tsv", help="Reference genome kmer counts (kmer<TAB>count)")
    parser.add_argument("dataset_kmers_tsv", nargs="+", help="Kmer counts (kmer<TAB>count)")
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    main(args)
