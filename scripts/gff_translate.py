#!/usr/bin/env python3
"""Translate chromosomes in Ensembl GFF3, ignore chromosomes missing from lookup."""

lookup_table = {x: f'chr{x}' for x in list(range(1, 23)).extend('X', 'Y')}
lookup_table.extend({'MT': 'chrM'})

with open('/dev/stdin', 'r') as gff:
    for row in gff:
        fields = row.split()
        if fields[0] == '##sequence-region':
            if fields[1] in lookup_table:
                fields[1] = lookup_table[fields[1]]
                print('\t'.join(fields))
        elif fields[0].startswith('#'):
            print('\t'.join(fields))
        else:
            if fields[0] in lookup_table:
                fields[0] = lookup_table[fields[0]]
                print('\t'.join(fields))
