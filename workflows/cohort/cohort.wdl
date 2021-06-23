version 1.0

import "./tasks/pbsv.wdl" as pbsv
import "./tasks/glnexus.wdl" as glnexus
import "./tasks/slivar.wdl" as slivar
import "../common/structs.wdl"

workflow cohort {
  input {
    String cohort_name
    IndexedData reference
    Array[String] regions

    Array[IndexedData] affected_person_deepvariant_phased_vcf_gz
    Array[IndexedData] unaffected_person_deepvariant_phased_vcf_gz

    Int num_samples = length(affected_person_deepvariant_phased_vcf_gz) + length(unaffected_person_deepvariant_phased_vcf_gz)
    Boolean singleton = if num_samples == 1 then true else false 

    String pb_conda_image
    String glnexus_image
  }

  call pbsv.pbsv {
    input:
      cohort_name = cohort_name,
      reference = reference,
      regions = regions,
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

      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData pbsv_vcf    = pbsv.pbsv_vcf
    IndexedData filt_vcf    = slivar.filt_vcf
    IndexedData comphet_vcf = slivar.filt_vcf
    File filt_tsv           = slivar.filt_tsv
    File comphet_tsv        = slivar.comphet_tsv
  }
}