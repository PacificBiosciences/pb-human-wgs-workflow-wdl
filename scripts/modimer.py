#!/usr/bin/env python3
"""
Print modimer counts.

For consistency, always prepend with PYTHONHASHSEED=0.
"""

__author__ = "William Rowell"
__version__ = "0.1.0"


import argparse


def main(args):
    """ Main entry point of the app """
    with open(args.counts, 'r') as dumpfile:
        for row in dumpfile:
            kmer, count = row.rstrip("\n").split()
            if not hash(kmer.encode("utf-8")) % args.modN:
                print(f"{kmer}\t{count}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)

    # Required positional argument
    parser.add_argument("counts", help="jellyfish dump in tabular format", type=str)
    parser.add_argument("-N", "--modN", help="dividend for modular division",
                        type=int, default=5003)

    # Specify output of "--version"
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    main(args)
