version 1.0

#import "./sample.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.wdl"
import "https://raw.githubusercontent.com/PacificBiosciences/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow sample_trial {
  input {
    Array[String]             affected_person_sample_names
    Array[Array[IndexedData]] affected_person_sample
    Array[Array[IndexedData]] affected_person_sample_ubam
    Array[Array[File?]]        affected_person_jellyfish_input
    Array[Array[File?]]        affected_person_movie_modimers
    Array[String]             unaffected_person_sample_names
    Array[Array[IndexedData]] unaffected_person_sample
    Array[Array[IndexedData]] unaffected_person_sample_ubam
    Array[Array[File?]]        unaffected_person_jellyfish_input
    Array[Array[File?]]        unaffected_person_movie_modimers
    Array[Array[File?]]        unaffected_person_movie_modimers

    Array[String] regions
    IndexedData reference

    File tr_bed
    File chr_lengths

    File ref_modimers

    String pb_conda_image
    String deepvariant_image

    Boolean run_jellyfish

    File tg_list
    File tg_bed
    File score_matrix
    LastIndexedData last_reference
  }

  scatter (person_num in range(length(affected_person_sample))) {
    call sample.sample as sample_affected_person {
      input:
        sample_name = affected_person_sample_names[person_num],
        sample = affected_person_sample[person_num],
        sample_ubam = affected_person_sample_ubam[person_num],
        jellyfish_input = affected_person_jellyfish_input[person_num],
        movie_modimers = affected_person_movie_modimers[person_num],
        regions = regions,

        reference = reference,

        tr_bed = tr_bed,
        chr_lengths = chr_lengths,

        ref_modimers = ref_modimers,

        pb_conda_image = pb_conda_image,
        deepvariant_image = deepvariant_image,

        run_jellyfish = run_jellyfish,

        tg_list = tg_list,
        tg_bed = tg_bed,
        score_matrix = score_matrix,
        last_reference = last_reference
    }
  }

  scatter (person_num in range(length(unaffected_person_sample))) {
    call sample.sample as sample_unaffected_person {
      input:
        sample_name = unaffected_person_sample_names[person_num],
        sample = unaffected_person_sample[person_num],
        sample_ubam = unaffected_person_sample_ubam[person_num],
        jellyfish_input = unaffected_person_jellyfish_input[person_num],
        movie_modimers = unaffected_person_movie_modimers[person_num],
        regions = regions,

        reference = reference,

        tr_bed = tr_bed,
        chr_lengths = chr_lengths,

        ref_modimers = ref_modimers,

        pb_conda_image = pb_conda_image,
        deepvariant_image = deepvariant_image,

        run_jellyfish = run_jellyfish,

        tg_list = tg_list,
        tg_bed = tg_bed,
        score_matrix = score_matrix,
        last_reference = last_reference
    }
  }

  output {
    Array[IndexedData] affected_person_gvcf                        = if defined(sample_affected_person.gvcf)                        then sample_affected_person.gvcf else []
    Array[Array[Array[File]]] affected_person_svsig_gv             = if defined(sample_affected_person.svsig_gv)                    then sample_affected_person.svsig_gv else []
    Array[IndexedData] affected_person_deepvariant_phased_vcf_gz   = if defined(sample_affected_person.deepvariant_phased_vcf_gz)   then sample_affected_person.deepvariant_phased_vcf_gz else 0
    Array[File?] affected_person_jellyfish_output_files            = if defined(sample_affected_person.jellyfish_output)            then sample_affected_person.jellyfish_output else []
    Array[File?] affected_person_check_kmer_ouput_files            = if defined(sample_affected_person.check_kmer_consistency_output)            then sample_affected_person.check_kmer_consistency_output else []
    Array[File?] affected_person_tandem_genotypes                  = if defined(sample_affected_person.sample_tandem_genotypes)     then sample_affected_person.sample_tandem_genotypes else []
    Array[File?] affected_person_tandem_genotypes_absolute         = if defined(sample_affected_person.sample_tandem_genotypes_absolute)   then sample_affected_person.sample_tandem_genotypes_absolute else []
    Array[File?] affected_person_tandem_genotypes_plot             = if defined(sample_affected_person.sample_tandem_genotypes_plot)       then sample_affected_person.sample_tandem_genotypes_plot else []
    Array[File?] affected_person_tandem_genotypes_dropouts         = if defined(sample_affected_person.sample_tandem_genotypes_dropouts) then sample_affected_person.sample_tandem_genotypes_dropouts else [] 

    Array[IndexedData] unaffected_person_gvcf                      = if defined(sample_unaffected_person.gvcf)                      then sample_unaffected_person.gvcf else []
    Array[Array[Array[File]]] unaffected_person_svsig_gv           = if defined(sample_unaffected_person.svsig_gv)                  then sample_unaffected_person.svsig_gv else []
    Array[IndexedData] unaffected_person_deepvariant_phased_vcf_gz = if defined(sample_unaffected_person.deepvariant_phased_vcf_gz) then sample_unaffected_person.deepvariant_phased_vcf_gz else 0
    Array[File?] unaffected_person_jellyfish_output_files          = if defined(sample_unaffected_person.jellyfish_output)          then sample_unaffected_person.jellyfish_output else []
    Array[File?] unaffected_person_check_kmer_ouput_files          = if defined(sample_unaffected_person.check_kmer_consistency_output)            then sample_unaffected_person.check_kmer_consistency_output else []
    Array[File?] unaffected_person_tandem_genotypes                = if defined(sample_unaffected_person.sample_tandem_genotypes)          then sample_unaffected_person.sample_tandem_genotypes else []
    Array[File?] unaffected_person_tandem_genotypes_absolute       = if defined(sample_unaffected_person.sample_tandem_genotypes_absolute) then sample_unaffected_person.sample_tandem_genotypes_absolute else []
    Array[File?] unaffected_person_tandem_genotypes_plot           = if defined(sample_unaffected_person.sample_tandem_genotypes_plot)     then sample_unaffected_person.sample_tandem_genotypes_plot else []
    Array[File?] unaffected_person_tandem_genotypes_dropouts       = if defined(sample_unaffected_person.sample_tandem_genotypes_dropouts) then sample_unaffected_person.sample_tandem_genotypes_dropouts else []
  }
}
