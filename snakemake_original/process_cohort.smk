import os
import re
import yaml
from pathlib import Path
from collections import defaultdict


shell.prefix("set -o pipefail; umask 002; ")  # set g+w
configfile: "workflow/reference.yaml"         # reference information
configfile: "workflow/config.yaml"            # general configuration


def get_samples(cohortyaml=config['cohort_yaml'], cohort_id=config['cohort']):
    """Find all samples associated with cohort."""
    with open(cohortyaml, 'r') as yamlfile:
        cohort_list = yaml.load(yamlfile, Loader = yaml.FullLoader)
    for c in cohort_list:
        if c['id'] == cohort_id:
            break
    samples = []
    for affectedstatus in ['affecteds', 'unaffecteds']:
        if affectedstatus in c:
            for individual in range(len(c[affectedstatus])):
                samples.append(c[affectedstatus][individual]['id'])
    return samples


# cohort will be provided at command line with `--config cohort=$COHORT`
cohort = config['cohort']
ref = config['ref']['shortname']
all_chroms = config['ref']['autosomes'] + config['ref']['sex_chrom'] + config['ref']['mit_chrom']
print(f"Processing cohort {cohort} with reference {ref}.")

if not cohort in config:
    print(f"{cohort} not listed in valid cohorts.") and exit

# find all samples in cohort
samples = get_samples()

if len(samples) == 0:
    print(f"No samples in {cohort}.") and exit
elif len(samples) == 1:
    singleton = True
else:
    singleton = False
print(f"Samples in cohort: {samples}.")

# scan samples/*/aligned to generate a dict-of-lists-of-movies for 
pattern = re.compile(r'samples/(?P<sample>[A-Za-z0-9_-]+)/aligned/(?P<movie>m\d{5}[U]?_\d{6}_\d{6})\.(?P<reference>.*).bam')
movie_dict = defaultdict(list)
abam_list = []
for infile in Path(f"samples").glob('**/aligned/*.bam'):
    match = pattern.search(str(infile))
    if match and (match.group('sample') in samples) and (match.group('reference') == ref):
        movie_dict[match.group('sample')].append(match.group('movie'))
        abam_list.append(infile)

# singletons and cohorts provide different input to slivar and svpack
if singleton:
    # use the sample level VCFs
    slivar_input = f"samples/{samples[0]}/whatshap/{samples[0]}.{ref}.deepvariant.phased.vcf.gz"
    svpack_input = f"samples/{samples[0]}/pbsv/{samples[0]}.{ref}.pbsv.vcf.gz"
    gvcf_list = []   # unused
    svsig_dict = []  # unused
else:
    # generate joint-called VCFs
    slivar_input = f"cohorts/{cohort}/whatshap/{cohort}.{ref}.deepvariant.glnexus.phased.vcf.gz"
    svpack_input = f"cohorts/{cohort}/pbsv/{cohort}.{ref}.pbsv.vcf.gz"
    gvcf_list = [f"samples/{sample}/deepvariant/{sample}.{ref}.deepvariant.g.vcf.gz" for sample in samples]
    svsig_dict = {region: [f"samples/{sample}/pbsv/svsig/{movie}.{ref}.{region}.svsig.gz"
                           for sample in samples
                           for movie in movie_dict[sample]]
                  for region in all_chroms}


# build a list of targets
targets = []
include: 'rules/cohort_common.smk'

# generate a cohort level pbsv vcf or use singleton vcf
include: 'rules/cohort_pbsv.smk'
targets.extend([svpack_input, svpack_input + '.tbi'])

# TODO: annotate and filter pbsv vcf with svpack

# generate a cohort level deepvariant vcf or use singleton vcf
include: 'rules/cohort_glnexus.smk'
targets.extend([slivar_input, slivar_input + '.tbi'])

# annotate and filter deepvariant vcf
include: 'rules/cohort_slivar.smk'
targets.extend([f"cohorts/{cohort}/slivar/{cohort}.{ref}.deepvariant.phased.{infix}.{suffix}"
                for infix in ['slivar', 'slivar.compound-hets']
                for suffix in ['vcf.gz', 'vcf.gz.tbi', 'tsv']])


ruleorder: split_glnexus_vcf > whatshap_phase > whatshap_bcftools_concat > bcftools_bcf2vcf > bgzip_vcf
localrules: all, md5sum


rule all:
    input: targets + [f"{x}.md5" for x in targets]


rule md5sum:
    input: "{prefix}"
    output: "{prefix}.md5"
    message: "Creating md5 checksum for {input}."
    shell: "md5sum {input} > {output}"
