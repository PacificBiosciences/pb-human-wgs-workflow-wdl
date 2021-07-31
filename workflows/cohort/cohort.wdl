version 1.0

#import "./tasks/pbsv.wdl" as pbsv
#import "./tasks/glnexus.wdl" as glnexus
#import "./tasks/slivar.wdl" as slivar
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/cohort/tasks/pbsv.wdl" as pbsv
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/cohort/tasks/glnexus.wdl" as glnexus
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/cohort/tasks/slivar.wdl" as slivar
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/dev/workflows/common/structs.wdl"

workflow cohort {
  input {
    String cohort_name
    IndexedData reference
    Array[String] regions

    Array[IndexedData] affected_person_deepvariant_phased_vcf_gz
    Array[IndexedData] unaffected_person_deepvariant_phased_vcf_gz

    Int num_samples = length(affected_person_deepvariant_phased_vcf_gz) + length(unaffected_person_deepvariant_phased_vcf_gz)
    Boolean singleton = if num_samples == 1 then true else false 

    #slivar
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

    #pbsv
    Array[Array[Array[File]]] affected_person_svsigs
    Array[Array[Array[File]]] unaffected_person_svsigs

    #glnexus
    File chr_lengths
    Array[Array[IndexedData]] affected_person_bams
    Array[Array[IndexedData]] unaffected_person_bams
    Array[IndexedData] affected_person_gvcfs
    Array[IndexedData] unaffected_person_gvcfs
    
    String pb_conda_image
    String glnexus_image
  }

  call pbsv.pbsv {
    input:
      cohort_name = cohort_name,
      reference = reference,
      regions = regions,
      affected_person_svsigs = affected_person_svsigs,
      unaffected_person_svsigs = unaffected_person_svsigs,
      pb_conda_image = pb_conda_image
  }

  if (singleton) {
      if (length(affected_person_deepvariant_phased_vcf_gz) == 1) {
        IndexedData singleton_affected_person_slivar_input = affected_person_deepvariant_phased_vcf_gz[0]
      }

      if (length(unaffected_person_deepvariant_phased_vcf_gz) == 1) {
        IndexedData singleton_unaffected_person_slivar_input = unaffected_person_deepvariant_phased_vcf_gz[0]
      }

      IndexedData? singleton_slivar_input = if defined(singleton_affected_person_slivar_input) then singleton_affected_person_slivar_input else singleton_unaffected_person_slivar_input
  }

  if (!singleton) {
    call glnexus.glnexus {
      input:
        cohort_name = cohort_name,
        regions = regions,
        reference = reference,

        chr_lengths = chr_lengths,
        affected_person_bams = affected_person_bams,
        unaffected_person_bams = unaffected_person_bams,
        affected_person_gvcfs = affected_person_gvcfs,
        unaffected_person_gvcfs = unaffected_person_gvcfs,

        pb_conda_image = pb_conda_image,
        glnexus_image = glnexus_image
    }

    IndexedData non_singleton_slivar_input = glnexus.deepvariant_glnexus_phased_vcf_gz
  }

  call slivar.slivar {
    input:
      cohort_name = cohort_name,
      reference = reference,

      singleton = singleton,

      slivar_input = if singleton then singleton_slivar_input else non_singleton_slivar_input,

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


      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData pbsv_vcf    = pbsv.pbsv_vcf
    IndexedData filt_vcf    = slivar.filt_vcf
    IndexedData comphet_vcf = slivar.comphet_vcf
    File filt_tsv           = slivar.filt_tsv
    File comphet_tsv        = slivar.comphet_tsv
  }
}