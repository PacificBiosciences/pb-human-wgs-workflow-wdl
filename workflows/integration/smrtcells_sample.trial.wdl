version 1.0

#import "../smrtcells/smrtcells.trial.wdl"
#import "../sample/sample.trial.wdl"
#import "../common/structs.wdl"

import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/smrtcells/smrtcells.trial.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.trial.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"

workflow smrtcells_sample_trial {
  input {
    IndexedData reference

    File regions_file
    CohortInfo cohort_info
    Int kmer_length

    File tr_bed
    File chr_lengths

    String pb_conda_image
    String deepvariant_image


    File tg_list
    File score_matrix
    LastIndexedData last_reference
  }

  Array[String] regions = read_lines(regions_file)

  call smrtcells.cohort.smrtcells_cohort {
    input:
      reference = reference,
      cohort_info = cohort_info,
      kmer_length = kmer_length,

      pb_conda_image = pb_conda_image
  }

  call sample.trial.sample_family {
    input:
    person_sample_names      = smrtcells_cohort.person_sample_names,
    person_sample            = smrtcells_cohort.person_bams,
    person_jellyfish_input   = smrtcells_cohort.person_jellyfish_count,

    regions = regions
    reference = reference,

    tr_bed = tr_bed,
    chr_lengths = chr_lengths,

    pb_conda_image = pb_conda_image,
    deepvariant_image = deepvariant_image,

    tg_list = tg_list,
    score_matrix = score_matrix
    last_reference = last_reference
  }

  output {
    Array[Array[IndexedData]] person_bams        = smrtcells_cohort.person_bams
    Array[Array[File]] person_jellyfish_count    = smrtcells_cohort.person_jellyfish_count

    Array[IndexedData] person_gvcf                        = sample_family.person_gvcf
    Array[Array[Array[File]]] person_svsig_gv             = sample_family.person_svsig_gv
    Array[IndexedData] person_deepvariant_phased_vcf_gz   = sample_family.person_deepvariant_phased_vcf_gz
    Array[IndexedData] person_tandem_genotypes            = sample_family.person_tandem_genotypes
    Array[IndexedData] person_tandem_genotypes_absolute   = sample_family.person_tandem_genotypes_absolute
    Array[IndexedData] person_tandem_genotypes_plot       = sample_family.person_tandem_genotypes_plot
    Array[IndexedData] person_tandem_genotypes_dropouts   = sample_family.person_tandem_genotypes_dropouts

  }
}
