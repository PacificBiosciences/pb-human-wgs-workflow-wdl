version 1.0

# All unffacted/affected lines are removed, and replaced with unified arguments by Charlie Bi
# Whenever affected/unaffected appears, it is removed and rewritten with one line of new code

import "sample.wdl"
import "../common/structs.wdl"


workflow sample_family {
  input {
    Array[String]             person_sample_names
    Array[Array[IndexedData]] person_sample
    Array[Array[File?]]       person_jellyfish_input

    Array[String] regions
    IndexedData reference

    File tr_bed
    File chr_lengths

    File ref_modimers
    Array[Array[File?]] person_movie_modimers

    String pb_conda_image
    String deepvariant_image

    Boolean run_jellyfish

    File tg_list
    File tg_bed
    File score_matrix
    LastIndexedData last_reference
  }

  scatter (person_num in range(length(person_sample))) {
    call sample.sample as sample_person {
      input:
        sample_name = person_sample_names[person_num],
        sample = person_sample[person_num],
        jellyfish_input = person_jellyfish_input[person_num],
        regions = regions,

        reference = reference,

        tr_bed = tr_bed,
        chr_lengths = chr_lengths,

        ref_modimers = ref_modimers,
        movie_modimers = person_movie_modimers[person_num],

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
    Array[IndexedData] person_gvcf                        = if defined(sample_person.gvcf) then sample_person.gvcf else []
    Array[Array[Array[File]]] person_svsig_gv             = if defined(sample_person.svsig_gv) then sample_person.svsig_gv else []
    Array[IndexedData] person_deepvariant_phased_vcf_gz   = if defined(sample_person.deepvariant_phased_vcf_gz) then sample_person.deepvariant_phased_vcf_gz else []
    Array[File?] person_jellyfish_output_files            = if defined(sample_person.jellyfish_output) then sample_person.jellyfish_output else []
    Array[File?] person_tandem_genotypes                  = if defined(sample_person.sample_tandem_genotypes)  then sample_person.sample_tandem_genotypes else []
    Array[File?] person_tandem_genotypes_absolute         = if defined(sample_person.sample_tandem_genotypes_absolute) then sample_person.sample_tandem_genotypes_absolute else []
    Array[File?] person_tandem_genotypes_plot             = if defined(sample_person.sample_tandem_genotypes_plot) then sample_person.sample_tandem_genotypes_plot else []
    Array[File?] person_tandem_genotypes_dropouts         = if defined(sample_person.sample_tandem_genotypes_dropouts) then sample_person.sample_tandem_genotypes_dropouts else []
  }
}
