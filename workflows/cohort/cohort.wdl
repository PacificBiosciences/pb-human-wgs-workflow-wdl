version 1.0

# to simplify Venkat's code by replacing affected/unaffected with unified data structure by Charlie Bi

import "tasks/pbsv.wdl" as pbsv
import "tasks/glnexus.wdl" as glnexus
import "tasks/slivar.wdl" as slivar
import "../common/structs.wdl"


workflow cohort {
  input {
    String cohort_name
    IndexedData reference
    Array[String] regions

    Array[IndexedData] person_deepvariant_phased_vcf_gz

    Array[IndexedData] person_gvcfs

    Array[Array[Array[File]]] person_svsigs

    Array[Array[IndexedData]] person_bams

    String pb_conda_image
    String glnexus_image

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
  }

  Int num_samples = length(person_deepvariant_phased_vcf_gz)
  Boolean singleton = if num_samples == 1 then true else false

  if (singleton) {
      if (length(person_deepvariant_phased_vcf_gz) == 1) {
        IndexedData singleton_slivar_input = person_deepvariant_phased_vcf_gz[0]
      }
  }


  if (!singleton) {
    call pbsv.pbsv {
      input:
        cohort_name = cohort_name,
        reference = reference,
        pb_conda_image = pb_conda_image,
        person_svsigs = person_svsigs
    }

    call glnexus.glnexus {
      input:
        cohort_name = cohort_name,
        regions = regions,
        reference = reference,
        person_gvcfs = person_gvcfs,
        person_bams = person_bams,
        pb_conda_image = pb_conda_image,
        glnexus_image = glnexus_image,
        chr_lengths = chr_lengths
    }

    IndexedData non_singleton_slivar_input = glnexus.deepvariant_glnexus_phased_vcf_gz
  }

  call slivar.slivar {
    input:
      cohort_name = cohort_name,
      reference = reference,
      singleton = singleton,
      slivar_input = if singleton then singleton_slivar_input else non_singleton_slivar_input,
      pb_conda_image = pb_conda_image,
      hpoannotations = hpoannotations,
      hpoterms =  hpoterms,
      hpodag =  hpodag,
      gff = gff,
      ensembl_to_hgnc = ensembl_to_hgnc,
      js =   js,
      lof_lookup =  lof_lookup,
      gnomad_af =  gnomad_af,
      hprc_af =  hprc_af,
      allyaml = allyaml,
      ped =  ped,
      clinvar_lookup =   clinvar_lookup
  }

  output {
    IndexedData? pbsv_vcf    = pbsv.pbsv_vcf
    IndexedData filt_vcf    = slivar.filt_vcf
    IndexedData comphet_vcf = slivar.filt_vcf
    File filt_tsv           = slivar.filt_tsv
    File comphet_tsv        = slivar.comphet_tsv
  }
}
