#!/usr/bin/env python3
"""
Print sequencing coverage ratios (chrM:chr2) from GRCh38 alignments.
"""

__author__ = "William Rowell"
__version__ = "0.1.0"


import argparse
import pandas as pd
from numpy import nan


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


def main(args):
    mosdepth_df = import_mosdepth_summary(args.mosdepth_summary)
    M2_ratio = coverage_ratio(mosdepth_df, 'chrM', 'chr2')
    print(round(M2_ratio, 4))


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
