version 1.0

#import "../sample/sample.family.wdl"
#import "../cohort/cohort.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.trial.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/cohort/cohort.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow sample_cohort {
  input {
    Array[String]             person_sample_names
    Array[Array[IndexedData]] person_sample
    Array[Array[File]]        person_jellyfish_input

    String cohort_name

    Array[String] regions
    IndexedData reference

    File tr_bed
    File chr_lengths

    File hpoannotations
    File hpoterms
    File hpodag
    File gff
    File ensembl_to_hgnc
    File js
    File lof_lookup
    File gnomad_af
    File hprc_af
    File allyaml
    File ped
    File clinvar_lookup

    String pb_conda_image
    String deepvariant_image
    String glnexus_image
  }

  call sample.trial.sample_family {
    input:
      person_sample_names = person_sample_names,
      person_sample = person_sample,
      person_jellyfish_input = person_jellyfish_input,

      regions = regions
      reference = reference,

      tr_bed = tr_bed,
      chr_lengths = chr_lengths,

      pb_conda_image = pb_conda_image,
      deepvariant_image = deepvariant_image,
  }

  call cohort.cohort {
    input:
      cohort_name = cohort_name,
      #regions_file = regions_file,
      regions = regions
      reference = reference,
      chr_lengths = chr_lengths,

      person_deepvariant_phased_vcf_gz = sample_family.person_deepvariant_phased_vcf_gz,

      hpoannotations = hpoannotations,
      hpoterms = hpoterms,
      hpodag = hpodag,
      gff = gff,
      ensembl_to_hgnc = ensembl_to_hgnc,
      js = js,
      lof_lookup = lof_lookup,
      clinvar_lookup = clinvar_lookup,
      gnomad_af = gnomad_af,
      hprc_af = hprc_af,
      allyaml = allyaml,
      ped = ped,

      person_svsigs = sample_family.person_svsig_gv,

      person_bams  = person_sample,
      person_gvcfs = sample_family.person_gvcf,

      pb_conda_image = pb_conda_image,
      glnexus_image = glnexus_image
  }

  output {
    Array[IndexedData] person_gvcf                        = sample_family.person_gvcf
    Array[Array[Array[File]]] person_svsig_gv             = sample_family.person_svsig_gv
    Array[IndexedData] person_deepvariant_phased_vcf_gz   = sample_family.person_deepvariant_phased_vcf_gz

    IndexedData pbsv_vcf    = cohort.pbsv_vcf
    IndexedData filt_vcf    = cohort.filt_vcf
    IndexedData comphet_vcf = cohort.comphet_vcf
    File filt_tsv           = cohort.filt_tsv
    File comphet_tsv        = cohort.comphet_tsv
  }
}
