#!/usr/bin/env python3
"""
Print read length and predicted read quality for unaligned reads (uBAM or FASTQ)
"""

__version__ = "0.1.0"


import argparse
import pysam
import math


def readQualityFromBaseQuality(baseQuals):
    # Compute read quality from an array of base qualities; cap at Q60
    readLen = len(baseQuals)
    expectedErrors = sum([math.pow(10, -0.1*x) for x in baseQuals])
    return min(60,math.floor(-10*math.log10(expectedErrors/readLen)))


def main(args):
    if args.readsin.endswith(".bam"):
        bamin = pysam.AlignmentFile(args.readsin, check_sq=False)
        for b in bamin:
            if b.has_tag("rq"): # get read qualitiy from "rq" BAM tag if available
                errorrate = 1.0 - b.get_tag("rq")
                readqv = 60 if errorrate == 0 else math.floor(-10*math.log10(errorrate))
            else:
                readqv = readQualityFromBaseQuality(b.query_qualities)

            print("%s\t%d\t%d" % (b.query_name, len(b.query_sequence), readqv))
        bamin.close()
    elif args.readsin.endswith(".fastq") or args.readsin.endswith(".fastq.gz"):
        fastqin = pysam.FastxFile(args.readsin)
        for r in fastqin:
            readqv = readQualityFromBaseQuality(r.get_quality_array())
            print ("%s\t%d\t%d" % (r.name, len(r.sequence), readqv))
        fastqin.close()
    else:
        sys.exit("Input file name must end in .bam or .fastq")


if __name__ == "__main__":
    """ This is executed when run from the command line """
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("readsin", help="Unaligned reads (BAM or FASTQ)")
    parser.add_argument(
        "--version",
        action="version",
        version="%(prog)s (version {version})".format(version=__version__))

    args = parser.parse_args()
    main(args)
