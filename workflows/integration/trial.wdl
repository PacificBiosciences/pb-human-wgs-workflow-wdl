version 1.0

#import "../smrtcells/smrtcells.trial.wdl"
#import "../sample/sample_trio.trial.wdl"
#import "../sample/sample.trial.wdl"
#import "../cohort/cohort.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/smrtcells/smrtcells.trial.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.trial.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/sample_trio.trial.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/cohort/cohort.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow trial {
  input {
    String cohort_name
    IndexedData reference
    File regions_file
    CohortInfo cohort_info
    Int kmer_length

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

    File ref_modimers
    File movie_modimers

    Boolean run_jellyfish = false                         #default is to NOT run jellyfish

    Boolean trioeval = false                              #default is to NOT run trioeval
    Boolean triobin = false                              #default is to NOT run triobin

    File tg_list
    File score_matrix
  }

  call smrtcells.trial.smrtcells_trial {
    input:
      reference = reference,
      cohort_info = cohort_info,
      kmer_length = kmer_length,

      pb_conda_image = pb_conda_image,
      run_jellyfish = run_jellyfish,
  }

  Array[String] regions = read_lines(regions_file)



  call sample_trio.trial.sample_trio {
    input:
    affected_person_sample_names      = smrtcells_trial.affected_person_sample_names,
    affected_person_sample            = smrtcells_trial.affected_person_bams,
    affected_person_parents_names     = smrtcells_trial.affected_person_parents_names,
    unaffected_person_sample_names    = smrtcells_trial.unaffected_person_sample_names,
    unaffected_person_sample          = smrtcells_trial.unaffected_person_bams,
    unaffected_person_parents_names   = smrtcells_trial.unaffected_person_parents_names,
    pb_conda_image = pb_conda_image,
    reference = reference,
    trioeval = trioeval,
    triobin = triobin,
    cohort_info = cohort_info

  }

  call sample.trial.sample_trial {
    input:
    affected_person_sample_names      = smrtcells_trial.affected_person_sample_names,
    affected_person_sample            = smrtcells_trial.affected_person_bams,
    affected_person_jellyfish_input   = smrtcells_trial.affected_person_jellyfish_count,
    unaffected_person_sample_names    = smrtcells_trial.unaffected_person_sample_names,
    unaffected_person_sample          = smrtcells_trial.unaffected_person_bams,
    unaffected_person_jellyfish_input = smrtcells_trial.unaffected_person_jellyfish_count,

    regions = regions,
    reference = reference,

    ref_modimers = ref_modimers,
    movie_modimers = movie_modimers,

    tr_bed = tr_bed,
    chr_lengths = chr_lengths,

    pb_conda_image = pb_conda_image,
    deepvariant_image = deepvariant_image,

    run_jellyfish = run_jellyfish,

    tg_list = tg_list,
    score_matrix = score_matrix
  }

  call cohort.cohort {
    input:
      cohort_name = cohort_name,
      regions = regions,
      reference = reference,

      affected_person_deepvariant_phased_vcf_gz = sample_trial.affected_person_deepvariant_phased_vcf_gz,
      unaffected_person_deepvariant_phased_vcf_gz = sample_trial.unaffected_person_deepvariant_phased_vcf_gz,

      chr_lengths = chr_lengths,

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

      affected_person_svsigs = sample_trial.affected_person_svsig_gv,
      unaffected_person_svsigs = sample_trial.unaffected_person_svsig_gv,

      affected_person_bams = smrtcells_trial.affected_person_bams,
      unaffected_person_bams = smrtcells_trial.unaffected_person_bams,
      affected_person_gvcfs = sample_trial.affected_person_gvcf,
      unaffected_person_gvcfs = sample_trial.unaffected_person_gvcf,

      pb_conda_image = pb_conda_image,
      glnexus_image = glnexus_image
  }

  output {
    Array[Array[IndexedData]] affected_person_bams        = smrtcells_trial.affected_person_bams
    Array[Array[File?]] affected_person_jellyfish_count    = smrtcells_trial.affected_person_jellyfish_count

    Array[Array[IndexedData]] unaffected_person_bams      = smrtcells_trial.unaffected_person_bams
    Array[Array[File?]] unaffected_person_jellyfish_count  = smrtcells_trial.unaffected_person_jellyfish_count

    Array[IndexedData] affected_person_gvcf                        = sample_trial.affected_person_gvcf
    Array[Array[Array[File]]] affected_person_svsig_gv             = sample_trial.affected_person_svsig_gv
    Array[IndexedData] affected_person_deepvariant_phased_vcf_gz   = sample_trial.affected_person_deepvariant_phased_vcf_gz

    Array[IndexedData] unaffected_person_gvcf                      = sample_trial.unaffected_person_gvcf
    Array[Array[Array[File]]] unaffected_person_svsig_gv           = sample_trial.unaffected_person_svsig_gv
    Array[IndexedData] unaffected_person_deepvariant_phased_vcf_gz = sample_trial.unaffected_person_deepvariant_phased_vcf_gz

    Array[File?] affected_person_tandem_genotypes           = sample_trial.affected_person_tandem_genotypes
    Array[File?] affected_person_tandem_genotypes_absolute  = sample_trial.affected_person_tandem_genotypes_absolute
    Array[File?] affected_person_tandem_genotypes_plot      = sample_trial.affected_person_tandem_genotypes_plot
    Array[File?] affected_person_tandem_genotypes_dropouts  = sample_trial.affected_person_tandem_genotypes_dropouts

    Array[File?] unaffected_person_tandem_genotypes           = sample_trial.unaffected_person_tandem_genotypes
    Array[File?] unaffected_person_tandem_genotypes_absolute  = sample_trial.unaffected_person_tandem_genotypes_absolute
    Array[File?] unaffected_person_tandem_genotypes_plot      = sample_trial.unaffected_person_tandem_genotypes_plot
    Array[File?] unaffected_person_tandem_genotypes_dropouts  = sample_trial.unaffected_person_tandem_genotypes_dropouts

    IndexedData pbsv_vcf    = cohort.pbsv_vcf
    IndexedData filt_vcf    = cohort.filt_vcf
    IndexedData comphet_vcf = cohort.comphet_vcf
    File filt_tsv           = cohort.filt_tsv
    File comphet_tsv        = cohort.comphet_tsv
  }
}
