#!/usr/bin/env python3
"""
Infer chromosomal sex from sequencing coverage ratios from GRCh38 alignments.
"""

__author__ = "William Rowell"
__version__ = "0.1.0"


import argparse
import pandas as pd
from numpy import nan, isnan


def import_mosdepth_summary(mosdepth_summary):
    """Create pandas dataframe from mosdepth summary."""
    return pd.read_csv(mosdepth_summary, sep='\t')


def coverage_ratio(df, chrom1, chrom2):
    """Calculate the coverage ratio of chrom1:chrom2"""
    if len(df[df.chrom == chrom2]) == 0:
        return nan
    elif len(df[df.chrom == chrom1]) == 0:
        return 0.0
    else:
        return float(df[df.chrom == chrom1]['mean']) / float(df[df.chrom == chrom2]['mean'])


def infer_sex(ratio, chrom1, chrom2):
    """Infer sex from ratio.

    Thresholds were determined empirically and may be adjusted in the future.
    thresholds is a 2-tuple.
    MALE ratios are below threshold[0].
    FEMALE ratios are above threshold[1].
    """
    if chrom1 == 'chrX' and chrom2 == 'chrY':
        thresholds = (5.0, 15.0)
    elif chrom1 == 'chrX' and chrom2 == 'chr2':
        thresholds = (0.55, 0.85)
    else:
        raise Exception
    if isnan(ratio):
        return 'UNCERTAIN'
    elif ratio < thresholds[0]:
        return 'MALE'
    elif ratio > thresholds[1]:
        return 'FEMALE'
    else:
        return 'UNCERTAIN'


def main(args):
    mosdepth_df = import_mosdepth_summary(args.mosdepth_summary)
    XY_ratio = coverage_ratio(mosdepth_df, 'chrX', 'chrY')
    XY_infer = infer_sex(XY_ratio, 'chrX', 'chrY')
    X2_ratio = coverage_ratio(mosdepth_df, 'chrX', 'chr2')
    X2_infer = infer_sex(X2_ratio, 'chrX', 'chr2')
    print('X:Y', 'infer_X:Y', 'X:2', 'infer_X:2', sep='\t')
    print(round(XY_ratio, 4), XY_infer, round(X2_ratio, 4), X2_infer, sep='\t')


if __name__ == "__main__":
    """ This is executed when run from the command line """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mosdepth_summary", help="Coverage summary output from mosdepth.")
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    main(args)
