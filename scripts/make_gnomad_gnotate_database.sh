#!/bin/bash

gnomad_vcf=$1

slivar make-gnotate \
    --field AF:gnomad_af \
    --field nhomalt:gnomad_nhomalt \
    --field AC:gnomad_ac \
    --prefix resources/slivar/gnomad.hg38.v3 \
    ${gnomad_vcf} 
